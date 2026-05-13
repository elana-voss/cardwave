part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// Anthropic
// ─────────────────────────────────────────────────────────────
class AnthropicProvider extends LlmProvider {
  const AnthropicProvider();

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.anthropic;
  @override
  String get label => 'Anthropic Claude';
  @override
  String get defaultBaseUrl => 'https://api.anthropic.com/v1';

  @override
  // Partial by design — this provider doesn't serve every domain; a missing key means "unsupported".
  // ignore: qcheck/avoid_missing_enum_constant_in_map
  Map<LlmProviderDomainEnum, String> get defaultModelIds => const {
    LlmProviderDomainEnum.chat: 'claude-3-5-haiku-20241022',
    LlmProviderDomainEnum.system: 'claude-3-5-haiku-20241022',
    LlmProviderDomainEnum.assistant: 'claude-3-7-sonnet-20250219',
  };

  @override
  Future<List<dynamic>> fetchRawModels({
    required http.Client client,
    required String apiKey,
    required String baseUrl,
  }) async {
    return _loggedFetchRawModels(
      client: client,
      url: '$baseUrl/models',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      parse: (body) =>
          (body['data'] as List?) ?? (body['models'] as List?) ?? const [],
    );
  }

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    final id = json['id'] as String;
    final displayName = json['display_name'] as String?;
    final capabilities = json['capabilities'] as Map<String, dynamic>?;

    final inputModalities = <LlmModelCapabilitiesEnum>{
      LlmModelCapabilitiesEnum.text,
    };
    if ((capabilities?['image_input'] as Map<String, dynamic>?)?['supported'] ==
        true) {
      inputModalities.add(LlmModelCapabilitiesEnum.image);
    }
    if ((capabilities?['pdf_input'] as Map<String, dynamic>?)?['supported'] ==
        true) {
      inputModalities.add(LlmModelCapabilitiesEnum.file);
    }
    final isReasoning =
        (capabilities?['thinking'] as Map<String, dynamic>?)?['supported'] ==
        true;

    final createdAtRaw = json['created_at'] as String?;
    final created = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)?.millisecondsSinceEpoch != null
              ? DateTime.parse(createdAtRaw).millisecondsSinceEpoch ~/ 1000
              : null
        : null;

    final rawMaxIn = json['max_input_tokens'] as int?;
    final rawMaxOut = json['max_tokens'] as int?;
    return LlmModel(
      id: id,
      name: displayName ?? id,
      created: created,
      contextLength: (rawMaxIn == null || rawMaxIn == 0)
          ? LlmConstants.fallbackContextLength
          : rawMaxIn,
      maxOutputTokens: (rawMaxOut == null || rawMaxOut == 0)
          ? LlmConstants.fallbackMaxResponseTokens
          : rawMaxOut,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        reasoning: isReasoning,
        toolCalling: true,
        structuredOutput:
            (capabilities?['structured_outputs']
                as Map<String, dynamic>?)?['supported'] ==
            true,
      ),
      supportedParameters: const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.topP,
        LlmParameterDefinitionIdEnum.topK,
        LlmParameterDefinitionIdEnum.maxResponseLength,
      ],
    );
  }

  @override
  LlmRunner buildRunner({
    required String apiKey,
    required String modelId,
    required LlmModel model,
    required Map<LlmParameterDefinitionIdEnum, double> paramValues,
    LlmPresetConfigReasoningEffortEnum reasoningEffort =
        LlmPresetConfigReasoningEffortEnum.off,
    String? baseUrl,
  }) {
    final r = LlmParameterResolver(model: model, userValues: paramValues);
    final genkitModel = _modelFor(
      providerEnum: enumValue,
      apiKey: apiKey,
      baseUrl: null,
      modelId: modelId,
      buildPlugin: (_) => anthropic(apiKey: apiKey),
    );
    final thinking = reasoningEffort.isOn
        ? ThinkingConfig(
            type: 'enabled',
            budgetTokens: reasoningEffort.budgetTokens,
          )
        : null;
    final maxTokens = _expandedMaxTokens(
      base: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
      reasoningEffort: reasoningEffort,
      modelCeiling: model.maxOutputTokens,
    );
    final opts = AnthropicOptions(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      maxTokens: maxTokens,
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
      topK: r.resolveInt(LlmParameterDefinitionIdEnum.topK),
      thinking: thinking,
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }
}
