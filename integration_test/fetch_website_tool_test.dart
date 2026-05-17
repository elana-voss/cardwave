import 'package:cardwave/chat/chat.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// fetch_website round-trip. Seeds Grok, opens the Cass chat, enables
/// "Allow Web Fetch" in the chat drawer, sends a prompt that names the
/// tool and a stable URL (example.com — IANA reserves it for examples
/// and the body is tiny). Asserts:
///
/// 1. The session's `webToolFetchAllowed` flips on after the drawer toggle.
/// 2. The assistant's last swipe carries a `fetch_website` ChatToolCallRecord
///    with `success: true`, `resultData` containing both the
///    `BEGIN_FETCHED_CONTENT` delimiter and the page's "Example Domain"
///    title — proves the manual loop ran one tool round, the HTTP GET
///    succeeded, and HTML→Markdown conversion fired.
/// 3. The final reply text references the fetched page (via "example",
///    "domain", or "illustrative") — proves the tool result reached the
///    model on iteration 2 and was incorporated into the user-visible
///    reply, not just attached as silent metadata.
///
/// Cost: 2 chat turns on Grok (iter 1 emits the tool call, iter 2
/// summarises the fetched page). No image / video generation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fetch_website tool — model fetches URL, page content reaches reply',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await bootCassChat(tester);
      await enableToolViaDrawer(tester, toggleLabel: 'Allow Web Fetch');

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final session = controller.chatSession;
      expect(session, isNotNull);
      expect(
        session!.configMedia?.webToolFetchAllowed,
        isTrue,
        reason: 'drawer toggle should set webToolFetchAllowed on session',
      );

      // Naming the tool explicitly + a trivial URL drives Grok to
      // emit one fetch_website call on iter 1. The "two sentences"
      // bound keeps iter 2 short.
      const userPrompt =
          'Please use the fetch_website tool to fetch https://example.com '
          'and then tell me in two sentences what that page is for.';
      await sendChatPrompt(tester, userPrompt);

      // Manual tool loop: iter 1 LLM call + HTTP fetch + iter 2 LLM
      // call. 90s covers both round-trips plus the fetch with
      // headroom for slow Grok variants.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 90));

      final fetch = assertToolFiredOnLastMessage(
        controller,
        toolName: FetchWebsiteTool.toolName,
      );
      expect(
        fetch.success,
        isTrue,
        reason:
            'fetch_website call should have succeeded; '
            'errorMessage=${fetch.errorMessage}',
      );
      expect(
        fetch.resultData,
        isNotNull,
        reason: 'successful fetch should carry resultData',
      );
      expect(
        fetch.resultData,
        contains(FetchWebsiteTool.resultDelimiterBegin),
        reason: 'fetched payload should be wrapped in delimiters',
      );
      expect(
        fetch.resultData,
        contains('Example Domain'),
        reason:
            'example.com body should include the page title — '
            'proves HTML→Markdown conversion preserved page text',
      );

      // Reply text references the fetched page. Model may phrase it
      // many ways — we accept any of "example" / "domain" /
      // "illustrative" since they all appear in example.com's prose
      // ("for use in illustrative examples in documents").
      final lastMessage = controller.messages.last;
      expect(
        lastMessage.content.isNotEmpty,
        isTrue,
        reason: 'reply text must be non-empty',
      );
      expect(
        lastMessage.content.toLowerCase(),
        anyOf(
          contains('example'),
          contains('domain'),
          contains('illustrative'),
        ),
        reason:
            'reply should reference fetched content '
            '(got: "${lastMessage.content}")',
      );

      // Hold the final UI state for a few seconds of real wall time
      // so a watching operator can visually confirm the rendered
      // bubble before the test framework tears down the app.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
    },
  );
}
