part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// Grok (xAI) — OpenAI-compatible
// ─────────────────────────────────────────────────────────────
class GrokProvider extends LlmProvider {
  const GrokProvider();

  static const _xaiTtsId = 'xai-tts';

  Future<Uint8List> synthesizeTts({
    required String apiKey,
    required String baseUrl,
    required String text,
    required String voiceId,
    required String languageCode,
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/tts'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'text': text,
              'voice_id': voiceId,
              'language': languageCode,
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        final body = response.body;
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
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

  /// Grok's sole text-to-video model. Rosters from xAI docs (Nov 2025).
  static const _grokVideoOptions = OptionsVideo(
    resolutions: [
      VideoResolution(id: '480p', label: '480p'),
      VideoResolution(id: '720p', label: '720p'),
    ],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
      VideoAspectRatio(id: '1:1', label: '1:1 (Square)'),
      VideoAspectRatio(id: '4:3', label: '4:3'),
      VideoAspectRatio(id: '3:4', label: '3:4'),
    ],
    durations: [
      // Debug-only 1s entry so integration tests pick the shortest possible
      // video via list[0] without changing the production picker. Tree-shaken
      // out of release builds.
      if (kDebugMode) VideoDuration(seconds: 1, label: '1 second (debug)'),
      VideoDuration(seconds: 4, label: '4 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
      VideoDuration(seconds: 12, label: '12 seconds'),
      VideoDuration(seconds: 15, label: '15 seconds'),
    ],
  );

  @override
  OptionsVideo? videoOptionsFor(String modelId) {
    if (modelId == 'grok-imagine-video') return _grokVideoOptions;
    return null;
  }

  /// Grok's `grok-imagine-image` accepts a native `aspect_ratio` string on
  /// `/v1/images/generations`; ratio ids pass through unchanged, so the
  /// shared [_commonImageAspectRoster] is used verbatim.
  @override
  OptionsImage? imageOptionsFor(String modelId) {
    return modelId == 'grok-imagine-image' ? _commonImageAspectRoster : null;
  }

  @override
  Map<String, dynamic> imageRequestExtras({
    required String modelId,
    required ConfigImage config,
  }) {
    if (modelId != 'grok-imagine-image') return const {};
    return {'aspect_ratio': config.aspectRatioId};
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
            Uri.parse('$baseUrl/videos/generations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': modelId,
              'prompt': prompt,
              'aspect_ratio': aspectRatioId,
              'resolution': resolutionId,
              'duration': durationSeconds,
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final id = json['request_id'] as String?;
      if (id == null || id.isEmpty) {
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
          providerLabel: label,
          statusCode: 200,
          message: 'Grok video submit returned no request_id.',
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
      // xAI returns HTTP 202 (Accepted) while the job is still generating
      // and HTTP 200 once the MP4 URL is ready. Both bodies share the same
      // `{status, progress, video?}` JSON shape, so we parse either.
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (json['status'] as String?) ?? 'pending';
      final progress = (json['progress'] as num?)?.toInt();
      if (status == 'done') {
        final video = json['video'] as Map<String, dynamic>?;
        final url = video?['url'] as String?;
        return VideoJobStatus(
          state: VideoJobStateEnum.done,
          progressPct: 100,
          resultUrl: url,
        );
      }
      if (status == 'failed' || status == 'expired') {
        final err = json['error'] as Map<String, dynamic>?;
        return VideoJobStatus(
          state: VideoJobStateEnum.failed,
          errorMessage:
              err?['message'] as String? ??
              (status == 'expired' ? 'Video request expired.' : null),
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
    // Grok's download URL is a temporary, xAI-hosted public URL
    // (`vidgen.x.ai/...`). Per xAI docs this URL serves the MP4 directly —
    // sending Authorization here can cause the bucket host to 403 the
    // request, so we send no credentials.
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
          providerLabel: label,
          statusCode: response.statusCode,
          message: 'Grok video download failed.',
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  /// Grok has no `/languages` endpoint — list is sourced from xAI docs
  /// (BCP-47). `auto` lets the model detect the language from the text.
  @override
  List<TtsLanguage> get ttsLanguages => const [
    TtsLanguage(code: 'auto', label: 'Auto-detect'),
    TtsLanguage(code: 'en', label: 'English'),
    TtsLanguage(code: 'ar-EG', label: 'Arabic (Egypt)'),
    TtsLanguage(code: 'ar-SA', label: 'Arabic (Saudi Arabia)'),
    TtsLanguage(code: 'ar-AE', label: 'Arabic (UAE)'),
    TtsLanguage(code: 'bn', label: 'Bengali'),
    TtsLanguage(code: 'zh', label: 'Chinese (Simplified)'),
    TtsLanguage(code: 'fr', label: 'French'),
    TtsLanguage(code: 'de', label: 'German'),
    TtsLanguage(code: 'hi', label: 'Hindi'),
    TtsLanguage(code: 'id', label: 'Indonesian'),
    TtsLanguage(code: 'it', label: 'Italian'),
    TtsLanguage(code: 'ja', label: 'Japanese'),
    TtsLanguage(code: 'ko', label: 'Korean'),
    TtsLanguage(code: 'pt-BR', label: 'Portuguese (Brazil)'),
    TtsLanguage(code: 'pt-PT', label: 'Portuguese (Portugal)'),
    TtsLanguage(code: 'ru', label: 'Russian'),
    TtsLanguage(code: 'es-MX', label: 'Spanish (Mexico)'),
    TtsLanguage(code: 'es-ES', label: 'Spanish (Spain)'),
    TtsLanguage(code: 'tr', label: 'Turkish'),
    TtsLanguage(code: 'vi', label: 'Vietnamese'),
  ];

  @override
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async {
    // Grok's /tts/voices roster is provider-global (same list for every TTS
    // model id), so [modelId] is unused here.
    final client = http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/tts/voices'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.grok,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = (json['voices'] as List?) ?? const [];
      return [
        for (final entry in raw)
          if (entry is Map<String, dynamic>)
            TtsVoice(
              id: entry['voice_id'] as String,
              label: (entry['name'] as String?) ?? entry['voice_id'] as String,
              tone: entry['tone'] as String?,
            ),
      ];
    } finally {
      client.close();
    }
  }

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.grok;
  @override
  String get label => 'Grok (xAI)';
  @override
  String get defaultBaseUrl => 'https://api.x.ai/v1';

  // xAI exposes three rich model-list endpoints; /v1/models is minimal
  // and lacks modalities + pricing. Hit all three and merge.
  @override
  Future<List<dynamic>> fetchRawModels({
    required http.Client client,
    required String apiKey,
    required String baseUrl,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    Future<List<dynamic>> fetch(String path, String kind) async {
      try {
        final raw = await _loggedFetchRawModels(
          client: client,
          url: '$baseUrl/$path',
          headers: headers,
          parse: (body) => (body['models'] as List?) ?? const [],
        );
        return raw
            .whereType<Map<String, dynamic>>()
            .map((m) => {...m, '_kind': kind})
            .toList();
      } on Exception {
        // One endpoint failing shouldn't sink the whole list.
        return const [];
      }
    }

    final results = await Future.wait([
      fetch('language-models', 'language'),
      fetch('image-generation-models', 'image'),
      fetch('video-generation-models', 'video'),
    ]);
    final syntheticTts = <String, dynamic>{
      '_kind': 'tts',
      'id': _xaiTtsId,
      'owned_by': 'xai',
      'input_modalities': ['text'],
      'output_modalities': ['audio'],
      'aliases': ['xAI TTS'],
    };
    return [syntheticTts, ...results.expand((e) => e)];
  }

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    final id = json['id'] as String;
    final kind = json['_kind'] as String?;
    final inputList = (json['input_modalities'] as List?)?.cast<String>();
    final outputList = (json['output_modalities'] as List?)?.cast<String>();

    final inputModalities = LlmCapabilities.parseModalities(inputList);
    final outputModalities = outputList != null && outputList.isNotEmpty
        ? LlmCapabilities.parseModalities(outputList)
        : <LlmModelCapabilitiesEnum>{LlmModelCapabilitiesEnum.text};

    // image-generation-models sometimes omits output_modalities in the
    // response; force image-out in that case.
    if (kind == 'image') outputModalities.add(LlmModelCapabilitiesEnum.image);
    if (kind == 'video') outputModalities.add(LlmModelCapabilitiesEnum.video);

    final lowerId = id.toLowerCase();
    final hasReasoningWord = RegExp(
      r'(^|[-_])reasoning([-_]|$)',
    ).hasMatch(lowerId);
    final hasNonReasoningWord = RegExp(
      r'(^|[-_])non[-_]?reasoning([-_]|$)',
    ).hasMatch(lowerId);
    final isReasoning = hasReasoningWord && !hasNonReasoningWord;
    // Every modern xAI Grok language model accepts response_format
    // json_schema via the OpenAI-compatible /chat/completions endpoint.
    // Gating purely on `kind == 'language'` is forward-compat for grok-5+
    // and avoids excluding hyphenated dotted ids like `grok-4.3` on a
    // future prefix change. Image / video / TTS kinds never apply.
    final supportsStructured = kind == 'language';

    // xAI prices are integers in USD cents per 100M tokens.
    // To get USD per 1M tokens: cents / 100 / 100 = cents / 10000.
    double? toUsdPerMtok(Object? v) {
      if (v is! num) return null;
      return v.toDouble() / 10000.0;
    }

    final promptPrice = toUsdPerMtok(json['prompt_text_token_price']);
    final completionPrice = toUsdPerMtok(json['completion_text_token_price']);
    final modelPricing = (promptPrice != null || completionPrice != null)
        ? LlmPricing(prompt: promptPrice ?? 0, completion: completionPrice ?? 0)
        : null;

    final aliases = (json['aliases'] as List?)?.cast<String>() ?? const [];
    final displayName = aliases.isNotEmpty ? aliases.first : id;

    return LlmModel(
      id: id,
      name: displayName,
      created: json['created'] as int?,
      ownedBy: json['owned_by'] as String?,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        reasoning: isReasoning,
        toolCalling: kind == 'language',
        structuredOutput: supportsStructured,
      ),
      supportedParameters: const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.topP,
        LlmParameterDefinitionIdEnum.maxResponseLength,
        LlmParameterDefinitionIdEnum.presencePenalty,
        LlmParameterDefinitionIdEnum.frequencyPenalty,
      ],
      pricing: modelPricing,
    );
  }

  @override
  LlmRunner buildRunner(BuildRunnerInputs inputs) {
    final BuildRunnerInputs(:apiKey, :modelId, :model, :paramValues) = inputs;
    final r = LlmParameterResolver(model: model, userValues: paramValues);
    final url = inputs.baseUrl ?? defaultBaseUrl;
    final genkitModel = _modelFor(
      providerEnum: enumValue,
      apiKey: apiKey,
      baseUrl: url,
      modelId: modelId,
      buildPlugin: (name) => openAI(name: name, apiKey: apiKey, baseUrl: url),
    );
    final opts = OpenAIOptions(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      maxTokens: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }
}
