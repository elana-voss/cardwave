import 'dart:convert';

import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/tools/builtin/builtin_tool_app_data.dart';
import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_definition.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;

/// Second builtin tool. Lets the chat model fetch a static HTML page
/// and feeds the body back as Markdown so the model can read it on the
/// next round of the manual tool loop.
///
/// Side-effect-free; the returned [ToolResult.data] is what carries the
/// page contents back to the model. The chat execution service folds
/// the data into a `LlmRunnerMessage.toolResult(...)` and re-invokes
/// the runner. Live HTML only — no JS execution, no auth, no headless
/// rendering.
class FetchWebsiteTool extends ToolDefinition {
  FetchWebsiteTool({
    required this.promptRepository,
    required this.maxCallsPerTurn,
    required this.requestTimeout,
    required this.maxBodyBytes,
    required this.maxResponseChars,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Stable wire-format name referenced from outside the tools layer
  /// (drawer toggle, allowed-tools list).
  static const String toolName = 'fetch_website';

  /// Markers wrapped around the fetched body in the tool result.
  /// Load-bearing on two sides: they tell the LLM that whatever sits
  /// between them is third-party page content (modest prompt-injection
  /// hardening — instructions inside the page are data, not commands),
  /// and integration tests assert on them to confirm the tool emitted
  /// a properly wrapped payload. Renaming requires updating both call
  /// sites at once, which is what these constants force.
  static const String resultDelimiterBegin = 'BEGIN_FETCHED_CONTENT';
  static const String resultDelimiterEnd = 'END_FETCHED_CONTENT';

  final PromptRepository promptRepository;
  @override
  final int maxCallsPerTurn;
  final Duration requestTimeout;
  final int maxBodyBytes;
  final int maxResponseChars;
  final http.Client _httpClient;

  @override
  void dispose() {
    _httpClient.close();
  }

  @override
  String get name => toolName;

  @override
  String get description =>
      'Fetch a public HTTP/HTTPS URL and return the page body as plain '
      'Markdown so you can read it. Use when the user shares a link, asks '
      'about an article, or you need to verify a fact.';

  @override
  String get systemPromptText => promptRepository.toolFetchWebsiteAdvertisement;

  @override
  String get progressLabel => 'Browsing…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) {
    return const {
      'type': 'object',
      'required': ['url'],
      'properties': {
        'url': {
          'type': 'string',
          'description':
              'Absolute http or https URL to fetch. Must not be a local '
              'file or data URL.',
        },
        'purpose': {
          'type': 'string',
          'description':
              'One short sentence on why you want this page. Shown to '
              'the user if they review URLs before fetch.',
        },
      },
    };
  }

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final urlRaw = args['url'];
    if (urlRaw is! String || urlRaw.trim().isEmpty) {
      return const ToolResult.failure('fetch_website missing url.');
    }
    final url = urlRaw.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return ToolResult.failure(
        'fetch_website rejects non-http(s) URL: $url.',
      );
    }

    final purposeRaw = args['purpose'];
    final purpose = purposeRaw is String ? purposeRaw : null;
    final data = ctx.appData as BuiltinToolAppData;
    final allowed = await data.confirmFetch(url, purpose: purpose);
    if (ctx.isCancelled) {
      return const ToolResult.failure('Cancelled by user.');
    }
    if (!allowed) {
      return const ToolResult.failure('User declined fetch.');
    }

    final http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(requestTimeout);
    } on Exception catch (e, st) {
      toolsLogger.warning(
        LlmDiagnosticEvent(
          level: LlmDiagnosticLevel.warning,
          message: 'fetch_website GET failed for $url',
          error: e,
          stackTrace: st,
        ),
      );
      return ToolResult.failure('Network error fetching $url: $e');
    }
    if (ctx.isCancelled) {
      return const ToolResult.failure('Cancelled by user.');
    }

    if (response.statusCode != 200) {
      return ToolResult.failure(
        'HTTP ${response.statusCode} fetching $url.',
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('text/html')) {
      return ToolResult.failure(
        'Non-HTML content at $url (content-type: $contentType).',
      );
    }

    final bytes = response.bodyBytes.length > maxBodyBytes
        ? response.bodyBytes.sublist(0, maxBodyBytes)
        : response.bodyBytes;
    final bodyText = utf8.decode(bytes, allowMalformed: true);

    final document = html_parser.parse(bodyText);
    final root = _pickConversionRoot(document);
    _stripChromeTags(root);

    final markdown = html2md.convert(root.outerHtml);
    final trimmed = markdown.trim();
    final capped = trimmed.length > maxResponseChars
        ? '${trimmed.substring(0, maxResponseChars)}\n\n…(truncated)'
        : trimmed;

    final body =
        '$resultDelimiterBegin [url=$url]\n\n$capped\n\n$resultDelimiterEnd';
    return ToolResult.ok(data: body);
  }

  /// Picks the most content-rich subtree to convert. Preference order:
  /// `<article>` → `<main>` → `<div role="main">` → `<body>`. Falls
  /// back to the document element when the page has no body.
  static dom.Element _pickConversionRoot(dom.Document document) {
    final article = document.querySelector('article');
    if (article != null) return article;
    final main = document.querySelector('main');
    if (main != null) return main;
    final divMain = document.querySelector('div[role="main"]');
    if (divMain != null) return divMain;
    return document.body ?? document.documentElement!;
  }

  /// Drops chrome tags whose content is noise (scripts, styles, nav).
  /// Mutates [root] in place. `.toList()` materialises a snapshot
  /// before removal so we don't mutate the live result list mid-walk.
  static void _stripChromeTags(dom.Element root) {
    final matches = root
        .querySelectorAll(
          'script, style, nav, aside, footer, form, noscript, iframe',
        )
        .toList();
    for (final el in matches) {
      el.remove();
    }
  }
}
