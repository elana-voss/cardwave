part of '../llm_provider.dart';

/// Generic OpenAI-compatible HTTP backend. Default URL points at KoboldCpp's
/// `:5001`, but the user edits it per-profile to reach Ollama (`:11434`),
/// LM Studio (`:1234`), or any local or remote endpoint that speaks the
/// OpenAI chat-completions shape.
///
/// Chat domain only — local backends don't expose OpenAI's image, TTS, or
/// video endpoints. No default model ids ship for this provider (the defaults
/// asset has no entry) because we don't know what model the user has loaded;
/// the seeder skips empty entries and the user creates presets manually after
/// the first model fetch.
class LocalOpenAiProvider extends LlmProvider {
  const LocalOpenAiProvider();

  /// genkit_openai's `openAI()` factory may reject an empty apiKey string.
  /// KoboldCpp/Ollama/etc. ignore the Authorization header anyway, so we
  /// substitute a harmless placeholder when the user leaves the field blank.
  static const _emptyKeyPlaceholder = 'sk-no-key';

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.localOpenAi;

  @override
  String get label => 'Custom (OpenAI-compatible)';

  @override
  String get defaultBaseUrl => 'http://localhost:5001/v1';

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    // Local servers (especially experimental forks of KoboldCpp / Ollama)
    // sometimes return entries with a missing, null, or non-string `id`.
    // Validate before casting — `as String` would throw a TypeError
    // (subtype of Error, not Exception), bypassing the repository-level
    // parse-loop catch and killing the whole fetch over one bad entry.
    // Throwing FormatException keeps the failure inside `on Exception`
    // so the loop logs the bad entry and parses the rest.
    final rawId = json['id'];
    if (rawId is! String || rawId.isEmpty) {
      throw FormatException(
        'Local provider model entry missing or invalid id: $json',
      );
    }
    // The fetch is only a source of model ids — we can't know a local
    // model's real context size or which sampling parameters its server
    // accepts. So a fetched entry is a blank template (id + name, plus
    // LlmModel's default context/response fallbacks and its default
    // temperature+response-length set). The user fills in the real values
    // via the per-model editor in the custom-provider dialog.
    return LlmModel(
      id: rawId,
      name: rawId,
      created: json['created'] as int?,
      ownedBy: json['owned_by'] as String?,
    );
  }

  @override
  LlmRunner buildRunner(BuildRunnerInputs inputs) {
    final BuildRunnerInputs(:apiKey, :modelId, :model, :paramValues) = inputs;
    final r = LlmParameterResolver(model: model, userValues: paramValues);
    final url = inputs.baseUrl ?? defaultBaseUrl;
    final effectiveKey = apiKey.isEmpty ? _emptyKeyPlaceholder : apiKey;
    final genkitModel = _modelFor(
      providerEnum: enumValue,
      apiKey: effectiveKey,
      baseUrl: url,
      modelId: modelId,
      buildPlugin: (name) =>
          openAI(name: name, apiKey: effectiveKey, baseUrl: url),
    );
    final opts = OpenAIOptions(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      maxTokens: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
      frequencyPenalty: r.resolve(
        LlmParameterDefinitionIdEnum.frequencyPenalty,
      ),
      presencePenalty: r.resolve(LlmParameterDefinitionIdEnum.presencePenalty),
      seed: r.resolveInt(LlmParameterDefinitionIdEnum.seed),
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }
}
