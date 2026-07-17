part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// NanoGPT (aggregator, uses OpenRouter cross-reference)
// ─────────────────────────────────────────────────────────────
class NanoGptProvider extends LlmProvider {
  const NanoGptProvider();

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.nanogpt;
  @override
  String get label => 'NanoGPT';
  @override
  String get defaultBaseUrl => 'https://nano-gpt.com/api/v1';

  /// Voice rosters for NanoGpt's OpenAI-family TTS models. NanoGpt proxies
  /// OpenAI under the hood — same voice set applies. Non-OpenAI models on
  /// NanoGpt (Kokoro, ElevenLabs, MiniMax, Qwen-TTS) aren't covered here —
  /// see MEMORY.md "TTS add-ons deferred".
  @override
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async => openAiVoicesFor(modelId);

  /// NanoGpt TTS runs through OpenAI which auto-detects input language.
  @override
  List<TtsLanguage> get ttsLanguages => const [];

  /// Video model ids we wire up in v1 — mirrors the TTS decision to limit
  /// NanoGpt to the subset whose schema fits our `(resolution, aspect,
  /// duration)` contract. See MEMORY.md "TTS add-ons deferred".
  static const _videoModelIds = {
    'sora-2',
    'veo2-video',
    'bytedance-seedance-v1.5-pro',
  };

  static const _nanoVideoOptions = OptionsVideo(
    resolutions: [
      VideoResolution(id: '480p', label: '480p'),
      VideoResolution(id: '720p', label: '720p'),
      VideoResolution(id: '1080p', label: '1080p'),
    ],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
      VideoAspectRatio(id: '1:1', label: '1:1 (Square)'),
    ],
    durations: [
      VideoDuration(seconds: 5, label: '5 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
    ],
  );

  @override
  OptionsVideo? videoOptionsFor(String modelId) {
    if (_videoModelIds.contains(modelId)) return _nanoVideoOptions;
    return null;
  }

  /// NanoGpt proxies the OpenAI image API shape verbatim for a subset of
  /// models, so the aspect roster and `size` mapping are shared with
  /// [OpenAiProvider] via module-level helpers. Other NanoGpt image
  /// models get a null roster and the drawer tile hides.
  @override
  OptionsImage? imageOptionsFor(String modelId) {
    return _openAiStyleAspectModelIds.contains(modelId)
        ? _commonImageAspectRoster
        : null;
  }

  @override
  Map<String, dynamic> imageRequestExtras({
    required String modelId,
    required ConfigImage config,
  }) {
    final size = _openAiStyleSizeFor(modelId, config.aspectRatioId);
    return size == null ? const {} : {'size': size};
  }

  /// NanoGpt video endpoints sit at `/api/generate-video` and
  /// `/api/video/status`, NOT under `/api/v1`. Strip the `/v1` suffix the
  /// base URL carries for chat/TTS.
  String _nanoApiRoot(String baseUrl) {
    return baseUrl.endsWith('/v1')
        ? baseUrl.substring(0, baseUrl.length - '/v1'.length)
        : baseUrl;
  }

  @override
  Future<String> submitVideoJob({
    required String apiKey,
    required String baseUrl,
    required String modelId,
    required String prompt,
    required String resolutionId,
    required String aspectRatioId,
    required int durationSeconds,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('${_nanoApiRoot(baseUrl)}/generate-video'),
            headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
            body: jsonEncode({
              'model': modelId,
              'prompt': prompt,
              'aspect_ratio': aspectRatioId,
              'resolution': resolutionId,
              'duration': '${durationSeconds}s',
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw LlmFetchException(
          provider: LLMProviderEnum.nanogpt,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final id = (json['runId'] ?? json['id']) as String?;
      if (id == null || id.isEmpty) {
        throw LlmFetchException(
          provider: LLMProviderEnum.nanogpt,
          providerLabel: label,
          statusCode: 200,
          message: 'NanoGpt video submit returned no runId.',
        );
      }
      return id;
    } finally {
      client.close();
    }
  }

  @override
  Future<VideoJobStatus> pollVideoJob({
    required String apiKey,
    required String baseUrl,
    required String jobId,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('${_nanoApiRoot(baseUrl)}/video/status?requestId=$jobId'),
            headers: {'x-api-key': apiKey},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.nanogpt,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = ((json['status'] as String?) ?? '').toUpperCase();
      if (status == 'COMPLETED' || status == 'SUCCESS') {
        // NanoGpt's status response shape varies across models — probe
        // the common field names for the final MP4 url.
        final url =
            (json['videoUrl'] ?? json['video_url'] ?? json['url']) as String?;
        return VideoJobStatus(
          state: VideoJobStateEnum.done,
          progressPct: 100,
          resultUrl: url,
        );
      }
      if (status == 'FAILED' || status == 'ERROR') {
        final err = json['error'];
        final msg = err is Map<String, dynamic>
            ? err['message'] as String?
            : err?.toString();
        return VideoJobStatus(
          state: VideoJobStateEnum.failed,
          errorMessage: msg,
        );
      }
      return const VideoJobStatus(state: VideoJobStateEnum.polling);
    } finally {
      client.close();
    }
  }

  @override
  Future<Uint8List> downloadVideoBytes({
    required String apiKey,
    required String url,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.nanogpt,
          providerLabel: label,
          statusCode: response.statusCode,
          message: 'NanoGpt video download failed.',
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  /// Synthesize via NanoGpt's OpenAI-compatible `/v1/audio/speech`. Auth is
  /// `x-api-key` (not Bearer). Response is raw MP3 bytes.
  Future<Uint8List> synthesizeTts({
    required String apiKey,
    required String baseUrl,
    required String text,
    required String voiceId,
    required String modelId,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/audio/speech'),
            headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
            body: jsonEncode({
              'model': modelId,
              'input': text,
              'voice': voiceId,
              'response_format': 'mp3',
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        final body = response.body;
        throw LlmFetchException(
          provider: LLMProviderEnum.nanogpt,
          providerLabel: label,
          statusCode: response.statusCode,
          message: body.length > 200 ? body.substring(0, 200) : body,
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    // Media-catalog entries (image/video/audio) come from dedicated
    // endpoints and carry a `_kind` tag injected by fetchRawModels. They
    // use a different, simpler schema than the text `/v1/models` list.
    final kind = json['_kind'] as String?;
    if (kind != null) return _parseMediaModel(json, kind);

    final id = json['id'] as String;
    final name = (json['name'] as String?) ?? id;
    final capabilities = json['capabilities'] as Map<String, dynamic>?;
    final pricing = json['pricing'] as Map<String, dynamic>?;
    final subscription = json['subscription'] as Map<String, dynamic>?;

    final searchId = id.toLowerCase();
    final searchIdNoPrefix = searchId.contains('/')
        ? searchId.substring(searchId.indexOf('/') + 1)
        : searchId;
    final orMatch =
        openRouterLookup?[searchId] ?? openRouterLookup?[searchIdNoPrefix];

    final orArchitecture = orMatch?['architecture'] as Map<String, dynamic>?;
    final orSupportedRaw = orMatch?['supported_parameters'] as List<dynamic>?;
    final orDefaultRaw =
        orMatch?['default_parameters'] as Map<String, dynamic>?;

    final inputModalities = LlmCapabilities.parseModalities(
      orArchitecture?['input_modalities'] as List<dynamic>?,
    );
    final outputModalities = LlmCapabilities.parseModalities(
      orArchitecture?['output_modalities'] as List<dynamic>?,
    );

    if (capabilities?['vision'] == true) {
      inputModalities.add(LlmModelCapabilitiesEnum.image);
    }
    if (capabilities?['pdf_upload'] == true) {
      inputModalities.add(LlmModelCapabilitiesEnum.file);
    }

    final orParams = (orSupportedRaw ?? []).map((e) => e.toString()).toList();
    final reasoning =
        (capabilities?['reasoning'] as bool?) ??
        (orParams.contains('reasoning') ||
            orParams.contains('include_reasoning'));
    final toolCalling =
        (capabilities?['tool_calling'] as bool?) ??
        (orParams.contains('tools') || orParams.contains('tool_choice'));

    // NanoGpt's `prompt` / `completion` fields are per-token (often string-
    // encoded). The per-million values live in `prompt_per_million` /
    // `completion_per_million` (number) — use those so the display matches
    // OpenRouter's per-Mtok convention.
    final modelPricing = pricing != null
        ? LlmPricing(
            prompt: (pricing['prompt_per_million'] as num?)?.toDouble() ?? 0.0,
            completion:
                (pricing['completion_per_million'] as num?)?.toDouble() ?? 0.0,
            currency: pricing['currency'] as String? ?? 'USD',
          )
        : null;

    final modelSubscription = subscription != null
        ? LlmSubscription(
            included: subscription['included'] as bool? ?? false,
            note: subscription['note'] as String? ?? '',
          )
        : null;

    return LlmModel(
      id: id,
      name: name,
      description: json['description'] as String?,
      created: json['created'] as int?,
      ownedBy: json['owned_by'] as String?,
      contextLength:
          (json['context_length'] as int?) ??
          (orMatch?['context_length'] as int?) ??
          LlmConstants.fallbackContextLength,
      maxOutputTokens:
          (json['max_output_tokens'] as int?) ??
          ((orMatch?['top_provider']
                  as Map<String, dynamic>?)?['max_completion_tokens']
              as int?) ??
          LlmConstants.fallbackMaxResponseTokens,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        reasoning: reasoning,
        toolCalling: toolCalling,
        parallelToolCalls:
            (capabilities?['parallel_tool_calls'] as bool?) ?? false,
        structuredOutput:
            (capabilities?['structured_output'] as bool?) ?? false,
      ),
      supportedParameters: _mapSupportedParams(orSupportedRaw),
      defaultParameters: _mapDefaultParams(orDefaultRaw),
      pricing: modelPricing,
      costEstimate: double.tryParse(json['cost_estimate']?.toString() ?? ''),
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String?,
      subscription: modelSubscription,
    );
  }

  @override
  Future<List<dynamic>> fetchRawModels({
    required http.Client client,
    required String apiKey,
    required String baseUrl,
  }) async {
    // No auth: authenticated fetch server-filters to subscription models
    // and marks every entry `included:true`, defeating the client-side
    // "subscription only" filter. Anonymous fetch returns the full catalog.
    const headers = {'Content-Type': 'application/json'};

    Future<List<dynamic>> fetch(String path, {String? kind}) async {
      try {
        final raw = await _loggedFetchRawModels(
          client: client,
          url: '$baseUrl/$path',
          headers: headers,
          parse: (body) => (body['data'] as List?) ?? const [],
        );
        if (kind == null) return raw;
        return raw
            .whereType<Map<String, dynamic>>()
            .map((m) => {...m, '_kind': kind})
            .toList();
      } catch (_) {
        // Plain catch — a non-list `data` value is a TypeError (an
        // Error): one endpoint failing shouldn't sink the whole catalog.
        return const [];
      }
    }

    final results = await Future.wait([
      fetch('models?detailed=true'),
      fetch('image-models?detailed=true', kind: 'image'),
      fetch('video-models?detailed=true', kind: 'video'),
      fetch('audio-models?detailed=true', kind: 'audio'),
    ]);
    return results.expand((e) => e).toList();
  }

  /// Parses one entry from the `/v1/{image,video,audio}-models` catalogs.
  /// These endpoints share a clean OpenRouter-like shape with
  /// `architecture.input_modalities` / `output_modalities` — pricing is
  /// heterogeneous (per_image, per_second, per_thousand_chars, etc.) and
  /// doesn't fit our `{prompt, completion}` per-million-token model, so we
  /// leave it null for now.
  LlmModel _parseMediaModel(Map<String, dynamic> json, String kind) {
    final id = json['id'] as String;
    final name = (json['name'] as String?) ?? id;
    final architecture = json['architecture'] as Map<String, dynamic>?;
    final capabilities = json['capabilities'] as Map<String, dynamic>?;

    final inputModalities = LlmCapabilities.parseModalities(
      architecture?['input_modalities'] as List<dynamic>?,
    );
    final outputModalities = LlmCapabilities.parseModalities(
      architecture?['output_modalities'] as List<dynamic>?,
    );
    // Belt-and-braces: force the bucket's modality in case the catalog
    // entry omits or mis-tags it.
    switch (kind) {
      case 'image':
        outputModalities.add(LlmModelCapabilitiesEnum.image);
      case 'video':
        outputModalities.add(LlmModelCapabilitiesEnum.video);
      case 'audio':
        final category = (json['category'] as String?)?.toLowerCase() ?? '';
        final idLower = id.toLowerCase();
        final isMusic =
            category.contains('music') ||
            idLower.contains('music') ||
            idLower.contains('suno') ||
            idLower.contains('musicgen') ||
            idLower.contains('lyria') ||
            idLower.contains('chirp');
        outputModalities.add(
          isMusic
              ? LlmModelCapabilitiesEnum.audioMusic
              : LlmModelCapabilitiesEnum.audioTts,
        );
    }

    return LlmModel(
      id: id,
      name: name,
      description: json['description'] as String?,
      created: json['created'] as int?,
      ownedBy: json['owned_by'] as String?,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        toolCalling: (capabilities?['tool_calling'] as bool?) ?? false,
      ),
      supportedParameters: const [],
      iconUrl: json['icon_url'] as String?,
      category: json['category'] as String?,
    );
  }

  @override
  LlmRunner buildRunner(BuildRunnerInputs inputs) {
    return _openAiCompatibleAggregatorRunner(
      providerEnum: enumValue,
      apiKey: inputs.apiKey,
      modelId: inputs.modelId,
      model: inputs.model,
      paramValues: inputs.paramValues,
      baseUrl: inputs.baseUrl ?? defaultBaseUrl,
    );
  }
}

// Anthropic/Gemini maxTokens has to cover visible reply AND reasoning budget,
// so we add the effort's budgetTokens on top and clamp to the model ceiling.
int? _expandedMaxTokens({
  required int? base,
  required LlmPresetConfigReasoningEffortEnum reasoningEffort,
  required int modelCeiling,
}) {
  if (base == null || !reasoningEffort.isOn) return base;
  final expanded = base + reasoningEffort.budgetTokens;
  return expanded > modelCeiling ? modelCeiling : expanded;
}

// Shared by OpenRouter + NanoGpt — both expose OpenAI-compatible APIs with
// the fuller parameter set.
//
// TODO(genkit): `OpenAIOptions` currently has no reasoning/effort field, so
// any [ReasoningEffort] passed through this path is a no-op on the wire.
// Users who want reasoning on OpenRouter/NanoGpt must pick a model id whose
// reasoning is on by default (e.g. `deepseek/deepseek-r1`). Revisit when
// genkit_openai gains a reasoning surface.
LlmRunner _openAiCompatibleAggregatorRunner({
  required LLMProviderEnum providerEnum,
  required String apiKey,
  required String modelId,
  required LlmModel model,
  required Map<LlmParameterDefinitionIdEnum, double> paramValues,
  required String baseUrl,
}) {
  final r = LlmParameterResolver(model: model, userValues: paramValues);
  final genkitModel = _modelFor(
    providerEnum: providerEnum,
    apiKey: apiKey,
    baseUrl: baseUrl,
    modelId: modelId,
    buildPlugin: (name) => openAI(name: name, apiKey: apiKey, baseUrl: baseUrl),
  );
  final maxTokens =
      r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength) ??
      model.maxOutputTokens;
  final opts = OpenAIOptions(
    temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
    maxTokens: maxTokens,
    topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
    frequencyPenalty: r.resolve(LlmParameterDefinitionIdEnum.frequencyPenalty),
    presencePenalty: r.resolve(LlmParameterDefinitionIdEnum.presencePenalty),
    seed: r.resolveInt(LlmParameterDefinitionIdEnum.seed),
  );
  return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
}
