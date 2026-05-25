// avoid_unused_parameters: this is the base `LlmProvider`. Most methods
// here are overridable no-op defaults (`=> null`, `async => const []`,
// empty `async {}`) whose parameters define the contract that concrete
// subclasses honor — the real implementations read them. They are
// "unused" only in the base, which the per-method lint can't see.
// (Plugin lints need the `qcheck/` prefix in ignore comments.)
// ignore_for_file: qcheck/avoid_unused_parameters

import 'dart:convert';

import 'package:cardwave_llm/src/image/image_options.dart';
import 'package:cardwave_llm/src/models/build_runner_inputs.dart';
import 'package:cardwave_llm/src/models/llm_model.dart';
import 'package:cardwave_llm/src/models/llm_model_capabilities_enum.dart';
import 'package:cardwave_llm/src/models/llm_parameter_definition_id_enum.dart';
import 'package:cardwave_llm/src/models/llm_parameter_resolver.dart';
import 'package:cardwave_llm/src/models/llm_preset_config_reasoning_effort_enum.dart';
import 'package:cardwave_llm/src/models/llm_provider_domain_enum.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:cardwave_llm/src/models/llm_runner.dart';
import 'package:cardwave_llm/src/models/tts_option.dart';
import 'package:cardwave_llm/src/models/video_option.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/utils/llm_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart' show GenkitPlugin;
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart' as gg;
import 'package:genkit_llamadart/genkit_llamadart.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart' show FlashAttention;
import 'package:path/path.dart' as p;

part 'llm_provider/llm_fetch_exception.dart';
part 'llm_provider/open_ai_provider.dart';
part 'llm_provider/grok_provider.dart';
part 'llm_provider/open_router_provider.dart';
part 'llm_provider/nano_gpt_provider.dart';
part 'llm_provider/anthropic_provider.dart';
part 'llm_provider/google_provider.dart';
part 'llm_provider/local_open_ai_provider.dart';
part 'llm_provider/local_gguf_provider.dart';

/// Per-provider knowledge: how to hit the API, how to parse one model entry
/// into an [LlmModel], how to build a genkit-backed [LlmRunner], and which
/// models to use as defaults during onboarding.
///
/// Registry is static — one instance per subclass, accessed via
/// [LlmProvider.of].
sealed class LlmProvider {
  const LlmProvider();

  LLMProviderEnum get enumValue;
  String get label;
  String get defaultBaseUrl;
  Map<LlmProviderDomainEnum, String> get defaultModelIds;

  Future<List<dynamic>> fetchRawModels({
    required http.Client client,
    required String apiKey,
    required String baseUrl,
  }) {
    return _loggedFetchRawModels(
      client: client,
      url: '$baseUrl/models',
      headers: {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      parse: (body) =>
          (body['data'] as List?) ?? (body['models'] as List?) ?? const [],
    );
  }

  // Token redaction is handled by LoggingService._sanitize on the bridge
  // side, so we can log raw header maps. Throws LlmFetchException on any
  // non-200 or transport error so callers can surface a user-facing message.
  Future<List<dynamic>> _loggedFetchRawModels({
    required http.Client client,
    required String url,
    required Map<String, String> headers,
    required List<dynamic> Function(Map<String, dynamic> body) parse,
  }) async {
    final headerJson = jsonEncode(headers);
    modelsLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.models,
        title: 'OUTGOING',
        body: '\nProvider: ${enumValue.name}\nGET $url\nHeaders: $headerJson',
        providerEnumName: enumValue.name,
      ),
    );
    final http.Response response;
    try {
      response = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      modelsLogger.severe(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.models,
          title: 'INCOMING',
          body: '\nProvider: ${enumValue.name}\nException: $e',
          providerEnumName: enumValue.name,
        ),
      );
      Error.throwWithStackTrace(
        LlmFetchException(
          provider: enumValue,
          providerLabel: label,
          message: 'Transport error: $e',
          cause: e,
        ),
        st,
      );
    }
    final status = response.statusCode;
    final body = response.body;
    if (status == 200) {
      modelsLogger.info(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.models,
          title: 'INCOMING',
          body:
              '\nProvider: ${enumValue.name}\nStatus: 200\nBodyLen: ${body.length}\n\n$body',
          providerEnumName: enumValue.name,
        ),
      );
      return parse(jsonDecode(body) as Map<String, dynamic>);
    }
    modelsLogger.severe(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.models,
        title: 'INCOMING',
        body:
            '\nProvider: ${enumValue.name}\nStatus: $status\nBodyLen: ${body.length}\n\n$body',
        providerEnumName: enumValue.name,
      ),
    );
    throw LlmFetchException(
      provider: enumValue,
      providerLabel: label,
      statusCode: status,
      message: body.isEmpty ? '<empty body>' : body,
    );
  }

  /// Parses one raw model JSON entry into an [LlmModel]. [openRouterLookup]
  /// is only populated for [NanoGptProvider] (cross-references OpenRouter
  /// metadata for richer capability info).
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  });

  LlmRunner buildRunner(BuildRunnerInputs inputs);

  /// Static list of BCP-47 language codes the provider's TTS supports, for
  /// providers that don't expose a runtime endpoint. Override per provider.
  List<TtsLanguage> get ttsLanguages => const [];

  /// Returns the voices a given TTS [modelId] supports. Base impl returns
  /// empty — providers without TTS, or with no voices for [modelId], keep it.
  /// Some providers (e.g. OpenAI) have different rosters per TTS model id;
  /// others (e.g. Grok, Google) share one roster across all TTS models and
  /// ignore the id.
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async => const [];

  /// Static per-model video-generation option rosters (resolution / aspect
  /// ratio / duration). Base returns null — providers without video
  /// generation, or models that aren't video, keep it.
  OptionsVideo? videoOptionsFor(String modelId) => null;

  /// Static per-model image-generation aspect-ratio roster. Base returns
  /// null — providers without image generation, or image models where
  /// aspect control is not exposed (legacy endpoints, unknown OR models),
  /// keep it. The drawer tile hides itself when this is null so users
  /// don't see a non-functional picker.
  OptionsImage? imageOptionsFor(String modelId) => null;

  /// JSON body keys this provider needs for the chosen [config] on the
  /// `/images/generations` POST. Merged into the request body by
  /// `OpenAiCompatibleImageClient` / `OpenRouterImageClient`. Base
  /// returns `const {}` so providers that don't support aspect control
  /// simply ship no extras and get the provider default size.
  Map<String, dynamic> imageRequestExtras({
    required String modelId,
    required ConfigImage config,
  }) => const {};

  /// Submits a text-to-video job; returns an opaque provider job id the
  /// caller uses to poll. Base throws — providers must override to support
  /// video generation.
  Future<String> submitVideoJob({
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String prompt,
    required String resolutionId,
    required String aspectRatioId,
    required int durationSeconds,
  }) async {
    throw UnsupportedError('$label does not support video generation.');
  }

  /// Polls the provider for job status. `resultUrl` is populated once the
  /// state flips to `done`. Base throws.
  Future<VideoJobStatus> pollVideoJob({
    required String apiKey,
    required String baseUrl,
    required String jobId,
  }) async {
    throw UnsupportedError('$label does not support video generation.');
  }

  /// Fetches the mp4 bytes from [url] returned by a completed job. Some
  /// providers embed auth on this hop (Google), so the call goes through
  /// the provider rather than a raw GET. Base throws.
  Future<Uint8List> downloadVideoBytes({
    required String apiKey,
    required String url,
  }) async {
    throw UnsupportedError('$label does not support video generation.');
  }

  static final Map<LLMProviderEnum, LlmProvider> _all = {
    LLMProviderEnum.openai: const OpenAiProvider(),
    LLMProviderEnum.grok: const GrokProvider(),
    LLMProviderEnum.openrouter: const OpenRouterProvider(),
    LLMProviderEnum.nanogpt: const NanoGptProvider(),
    LLMProviderEnum.anthropic: const AnthropicProvider(),
    LLMProviderEnum.google: const GoogleProvider(),
    LLMProviderEnum.localOpenAi: const LocalOpenAiProvider(),
    LLMProviderEnum.localGguf: const LocalGgufProvider(),
  };

  static LlmProvider of(LLMProviderEnum e) => _all[e]!;
  static Iterable<LlmProvider> all() => _all.values;

  /// Disposes any in-process plugins (and frees their VRAM) whose cache key
  /// references `modelPath`. Called by `ProvidersController` BEFORE saving a
  /// `localGguf` profile edit that changes context / KV quant, so the old
  /// plugin frees its slot before the new one loads. No-op for non-local
  /// providers because their cache keys never contain a filesystem path.
  static Future<void> disposeRuntimeFor(String modelPath) async {
    final prefix = '${LLMProviderEnum.localGguf.name}:';
    final stale = _pluginByConfig.keys
        .where((k) => k.startsWith(prefix) && k.contains(modelPath))
        .toList();
    for (final key in stale) {
      final plugin = _pluginByConfig.remove(key);
      if (plugin is LlamaDartPlugin) {
        await plugin.dispose();
      }
    }
  }

  /// Deterministic provider detection from an API key alone. All six
  /// supported providers have distinctive signatures — see
  /// `reference_llm_api_key_signatures.md` memory for the full table.
  /// Returns null if the key format is unrecognized.
  static LLMProviderEnum? detectFromApiKey(String key) {
    if (key.isEmpty) return null;
    if (key.startsWith('sk-ant-')) return LLMProviderEnum.anthropic;
    if (key.startsWith('sk-or-')) return LLMProviderEnum.openrouter;
    if (key.startsWith('sk-nano-')) return LLMProviderEnum.nanogpt;
    if (key.contains('T3BlbkFJ')) return LLMProviderEnum.openai;
    if (key.startsWith('xai-')) return LLMProviderEnum.grok;
    if (key.startsWith('AIza')) return LLMProviderEnum.google;
    return null;
  }
}

/// Shared [Genkit] for the session. Plugins are cached per config; the
/// resolved [Model] is re-registered every call so credential edits
/// overwrite the prior namespace entry, and the registry hit skips
/// `OpenAIPlugin.init()`'s `/v1/models` fetch on the default OpenAI host.
final Genkit _genkit = Genkit();
final Map<String, GenkitPlugin> _pluginByConfig = {};

Model<Object?> _modelFor({
  required LLMProviderEnum providerEnum,
  required String apiKey,
  required String? baseUrl,
  required String modelId,
  required GenkitPlugin Function(String pluginName) buildPlugin,
  String? cacheKeyOverride,
}) {
  // Default key composes from the URL + auth shape every cloud provider uses.
  // `cacheKeyOverride` exists for providers (currently `localGguf`) whose
  // plugin identity isn't a URL — they pass a synthetic key here and leave
  // `baseUrl` to mean only "the URL field".
  final cacheKey = cacheKeyOverride != null
      ? '${providerEnum.name}:$cacheKeyOverride'
      : '${providerEnum.name}:$apiKey:${baseUrl ?? ''}';
  final plugin = _pluginByConfig.putIfAbsent(cacheKey, () {
    final p = buildPlugin(providerEnum.name);
    _genkit.registry.registerPlugin(p);
    return p;
  });
  final model = plugin.resolve('model', modelId)! as Model;
  _genkit.registry.register(model);
  return model;
}

// ─────────────────────────────────────────────────────────────
// Shared param mapping used by OpenRouter + NanoGpt
// ─────────────────────────────────────────────────────────────
const Map<String, LlmParameterDefinitionIdEnum> _openRouterParamMap = {
  'temperature': LlmParameterDefinitionIdEnum.temperature,
  'top_p': LlmParameterDefinitionIdEnum.topP,
  'top_k': LlmParameterDefinitionIdEnum.topK,
  'top_a': LlmParameterDefinitionIdEnum.topA,
  'min_p': LlmParameterDefinitionIdEnum.minP,
  'repetition_penalty': LlmParameterDefinitionIdEnum.repetitionPenalty,
  'frequency_penalty': LlmParameterDefinitionIdEnum.frequencyPenalty,
  'presence_penalty': LlmParameterDefinitionIdEnum.presencePenalty,
  'max_tokens': LlmParameterDefinitionIdEnum.maxResponseLength,
  'seed': LlmParameterDefinitionIdEnum.seed,
};

List<LlmParameterDefinitionIdEnum> _mapSupportedParams(List<dynamic>? raw) {
  final list = (raw ?? [])
      .map((p) => _openRouterParamMap[p.toString()])
      .whereType<LlmParameterDefinitionIdEnum>()
      .toSet()
      .toList();
  if (list.isEmpty) {
    list.addAll([
      LlmParameterDefinitionIdEnum.temperature,
      LlmParameterDefinitionIdEnum.maxResponseLength,
    ]);
  }
  return list;
}

Map<LlmParameterDefinitionIdEnum, double> _mapDefaultParams(
  Map<String, dynamic>? raw,
) {
  final result = <LlmParameterDefinitionIdEnum, double>{};
  if (raw == null) return result;
  for (final e in raw.entries) {
    final id = _openRouterParamMap[e.key];
    if (id == null || e.value == null) continue;
    final v = num.tryParse(e.value.toString());
    if (v != null) result[id] = v.toDouble();
  }
  return result;
}
