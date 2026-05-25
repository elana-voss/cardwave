part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// OpenAI
// ─────────────────────────────────────────────────────────────
class OpenAiProvider extends LlmProvider {
  const OpenAiProvider();

  /// TTS model ids officially supported by `POST /v1/audio/speech` per OpenAI
  /// docs (Nov 2025). Anything else carrying `audio` / `tts` in its id (e.g.
  /// `gpt-4o-audio-preview`, `gpt-4o-transcribe`) is a realtime chat or STT
  /// model, not a TTS endpoint consumer — [parseModel] uses this set to
  /// avoid over-tagging.
  static const _ttsModelIds = {'tts-1', 'tts-1-hd', 'gpt-4o-mini-tts'};

  /// Sora 2 video model ids officially supported by `POST /v1/videos` (Nov
  /// 2025). Parallels `_ttsModelIds` — used to scope which `/models` entries
  /// get the `video` capability flag. sora-2-pro deferred to v2 per plan.
  static const _videoModelIds = {'sora-2'};

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.openai;
  @override
  String get label => 'OpenAI';
  @override
  String get defaultBaseUrl => 'https://api.openai.com/v1';

  @override
  // Partial by design — this provider doesn't serve every domain; a missing key means "unsupported".
  // ignore: qcheck/avoid_missing_enum_constant_in_map
  Map<LlmProviderDomainEnum, String> get defaultModelIds => const {
    LlmProviderDomainEnum.chat: 'gpt-4o-mini',
    LlmProviderDomainEnum.system: 'gpt-4o-mini',
    LlmProviderDomainEnum.assistant: 'gpt-4o',
    LlmProviderDomainEnum.image: 'dall-e-3',
    LlmProviderDomainEnum.audioTts: 'gpt-4o-mini-tts',
    LlmProviderDomainEnum.video: 'sora-2',
  };

  /// Sora 2 exposes `size` as a single packed value (e.g. `1280x720` or
  /// `720x1280`). Our data model splits resolution + aspect into separate
  /// rosters; the submit path recombines them.
  static const _soraVideoOptions = OptionsVideo(
    resolutions: [VideoResolution(id: '720p', label: '720p')],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
    ],
    durations: [
      VideoDuration(seconds: 4, label: '4 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
      VideoDuration(seconds: 12, label: '12 seconds'),
    ],
  );

  @override
  OptionsVideo? videoOptionsFor(String modelId) {
    if (_videoModelIds.contains(modelId)) return _soraVideoOptions;
    return null;
  }

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
    // sora-2 only supports 720p. 1280x720 for landscape, 720x1280 for portrait.
    final size = aspectRatioId == '9:16' ? '720x1280' : '1280x720';
    final client = http.Client();
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/videos'))
            ..headers['Authorization'] = 'Bearer $apiKey'
            ..fields['model'] = modelId
            ..fields['prompt'] = prompt
            ..fields['size'] = size
            ..fields['seconds'] = durationSeconds.toString();
      final streamed = await client.send(request);
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openai,
          providerLabel: label,
          statusCode: streamed.statusCode,
          message: body.length > 500 ? body.substring(0, 500) : body,
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null || id.isEmpty) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openai,
          providerLabel: label,
          statusCode: 200,
          message: 'OpenAI video submit returned no id.',
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
            Uri.parse('$baseUrl/videos/$jobId'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openai,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (json['status'] as String?) ?? 'queued';
      final progress = (json['progress'] as num?)?.toInt();
      if (status == 'completed') {
        return VideoJobStatus(
          state: VideoJobStateEnum.done,
          progressPct: 100,
          resultUrl: '$baseUrl/videos/$jobId/content',
        );
      }
      if (status == 'failed') {
        final err = json['error'];
        final msg = err is Map<String, dynamic>
            ? err['message'] as String?
            : err?.toString();
        return VideoJobStatus(
          state: VideoJobStateEnum.failed,
          errorMessage: msg,
        );
      }
      return VideoJobStatus(
        state: VideoJobStateEnum.polling,
        progressPct: progress,
      );
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
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openai,
          providerLabel: label,
          statusCode: response.statusCode,
          message: 'OpenAI video download failed.',
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  @override
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async => openAiVoicesFor(modelId);

  /// OpenAI TTS auto-detects the input text's language — no user-selectable
  /// list. Returning empty hides the Language tile in the chat drawer.
  @override
  List<TtsLanguage> get ttsLanguages => const [];

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
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
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
          provider: LLMProviderEnum.openai,
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
    final id = json['id'] as String;
    final searchName = id.toLowerCase();

    final inputModalities = <LlmModelCapabilitiesEnum>{
      LlmModelCapabilitiesEnum.text,
    };
    final outputModalities = <LlmModelCapabilitiesEnum>{
      LlmModelCapabilitiesEnum.text,
    };
    if (searchName.contains('vision') || searchName.contains('gpt-4o')) {
      inputModalities.add(LlmModelCapabilitiesEnum.image);
    }
    if (searchName.contains('dall-e') || searchName.contains('image')) {
      outputModalities.add(LlmModelCapabilitiesEnum.image);
    }
    if (_ttsModelIds.contains(id)) {
      outputModalities.add(LlmModelCapabilitiesEnum.audioTts);
    }
    if (_videoModelIds.contains(id)) {
      outputModalities.add(LlmModelCapabilitiesEnum.video);
    }
    if (searchName.contains('whisper') ||
        searchName.contains('transcribe') ||
        searchName.contains('audio') ||
        searchName.contains('realtime')) {
      inputModalities.add(LlmModelCapabilitiesEnum.audioTts);
    }

    final isReasoning =
        searchName.startsWith('o1') ||
        searchName.startsWith('o3') ||
        searchName.startsWith('o4') ||
        searchName.startsWith('gpt-5');
    // OpenAI's /v1/models is minimal — no capability metadata. Inferred
    // from id: GPT-4o family, GPT-4 Turbo, the o-series reasoning models,
    // and GPT-5 all support response_format json_schema. GPT-3.5 doesn't.
    final supportsStructured =
        searchName.startsWith('gpt-4o') ||
        searchName.startsWith('gpt-4-turbo') ||
        searchName.startsWith('gpt-5') ||
        searchName.startsWith('o1') ||
        searchName.startsWith('o3') ||
        searchName.startsWith('o4');

    return LlmModel(
      id: id,
      name: id,
      created: json['created'] as int?,
      ownedBy: json['owned_by'] as String?,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        reasoning: isReasoning,
        toolCalling: true,
        structuredOutput: supportsStructured,
      ),
      supportedParameters: const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.topP,
        LlmParameterDefinitionIdEnum.maxResponseLength,
        LlmParameterDefinitionIdEnum.presencePenalty,
        LlmParameterDefinitionIdEnum.frequencyPenalty,
      ],
    );
  }

  @override
  LlmRunner buildRunner(BuildRunnerInputs inputs) {
    final BuildRunnerInputs(:apiKey, :modelId, :model, :paramValues) = inputs;
    final r = LlmParameterResolver(model: model, userValues: paramValues);
    final genkitModel = _modelFor(
      providerEnum: enumValue,
      apiKey: apiKey,
      baseUrl: null,
      modelId: modelId,
      buildPlugin: (name) => openAI(name: name, apiKey: apiKey),
    );
    final opts = OpenAIOptions(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      maxTokens: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
      frequencyPenalty: r.resolve(
        LlmParameterDefinitionIdEnum.frequencyPenalty,
      ),
      presencePenalty: r.resolve(LlmParameterDefinitionIdEnum.presencePenalty),
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }
}
