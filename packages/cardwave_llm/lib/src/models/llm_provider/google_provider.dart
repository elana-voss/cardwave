part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// Google Gemini
// ─────────────────────────────────────────────────────────────
class GoogleProvider extends LlmProvider {
  const GoogleProvider();

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.google;
  @override
  String get label => 'Google Gemini';
  @override
  String get defaultBaseUrl =>
      'https://generativelanguage.googleapis.com/v1beta';

  @override
  // Partial by design — this provider doesn't serve every domain; a missing key means "unsupported".
  // ignore: qcheck/avoid_missing_enum_constant_in_map
  Map<LlmProviderDomainEnum, String> get defaultModelIds => const {
    LlmProviderDomainEnum.chat: 'gemini-2.5-flash',
    LlmProviderDomainEnum.system: 'gemini-2.5-flash-lite',
    LlmProviderDomainEnum.assistant: 'gemini-2.5-pro',
    LlmProviderDomainEnum.image: 'gemini-3.1-flash-image-preview',
    LlmProviderDomainEnum.audioTts: 'gemini-2.5-flash-preview-tts',
    LlmProviderDomainEnum.video: 'veo-3.1-lite-generate-preview',
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
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      parse: (body) =>
          (body['data'] as List?) ?? (body['models'] as List?) ?? const [],
    );
  }

  @override
  LlmModel parseModel(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? openRouterLookup,
  }) {
    final rawName = json['name'] as String;
    final bareId = rawName.replaceFirst('models/', '');
    final displayName = json['displayName'] as String?;
    final modelName = displayName ?? bareId;
    final searchName = bareId.toLowerCase();

    final inputModalities = <LlmModelCapabilitiesEnum>{
      LlmModelCapabilitiesEnum.text,
    };
    final outputModalities = <LlmModelCapabilitiesEnum>{
      LlmModelCapabilitiesEnum.text,
    };

    if (searchName.contains('image') || searchName.contains('banana')) {
      inputModalities.add(LlmModelCapabilitiesEnum.image);
      outputModalities.add(LlmModelCapabilitiesEnum.image);
    } else if (searchName.contains('tts') || searchName.contains('audio')) {
      outputModalities.add(LlmModelCapabilitiesEnum.audioTts);
    } else if (searchName.contains('veo')) {
      outputModalities.add(LlmModelCapabilitiesEnum.video);
    } else if (!searchName.contains('embedding')) {
      inputModalities.addAll({
        LlmModelCapabilitiesEnum.image,
        LlmModelCapabilitiesEnum.video,
        LlmModelCapabilitiesEnum.audioTts,
        LlmModelCapabilitiesEnum.file,
      });
    }

    final temperature = (json['temperature'] as num?)?.toDouble();
    final topP = (json['topP'] as num?)?.toDouble();
    final topK = (json['topK'] as num?)?.toDouble();

    final defaultParams = <LlmParameterDefinitionIdEnum, double>{};
    if (temperature != null) {
      defaultParams[LlmParameterDefinitionIdEnum.temperature] = temperature;
    }
    if (topP != null) defaultParams[LlmParameterDefinitionIdEnum.topP] = topP;
    if (topK != null) defaultParams[LlmParameterDefinitionIdEnum.topK] = topK;

    final isReasoning = (json['thinking'] as bool?) ?? false;
    final methods =
        (json['supportedGenerationMethods'] as List?)?.cast<String>() ??
        const [];
    final canCallTools = methods.contains('generateContent');
    // Gemini 1.5+ and 2.x support responseSchema; the catalog endpoint
    // doesn't expose this so we infer from the model id, mirroring the
    // modality inference above.
    final supportsStructured =
        searchName.startsWith('gemini-1.5') ||
        searchName.startsWith('gemini-2');

    return LlmModel(
      id: rawName,
      name: modelName,
      description: json['description'] as String?,
      contextLength:
          (json['inputTokenLimit'] as int?) ??
          LlmConstants.fallbackContextLength,
      maxOutputTokens:
          (json['outputTokenLimit'] as int?) ??
          LlmConstants.fallbackMaxResponseTokens,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        reasoning: isReasoning,
        toolCalling: canCallTools,
        structuredOutput: supportsStructured,
      ),
      supportedParameters: const [
        LlmParameterDefinitionIdEnum.temperature,
        LlmParameterDefinitionIdEnum.topP,
        LlmParameterDefinitionIdEnum.topK,
        LlmParameterDefinitionIdEnum.maxResponseLength,
      ],
      defaultParameters: defaultParams,
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
      buildPlugin: (_) => gg.googleAI(apiKey: apiKey),
    );
    final thinkingConfig = reasoningEffort.isOn
        ? gg.ThinkingConfig(
            includeThoughts: true,
            thinkingBudget: reasoningEffort.budgetTokens,
          )
        : null;
    final maxOutputTokens = _expandedMaxTokens(
      base: r.resolveInt(LlmParameterDefinitionIdEnum.maxResponseLength),
      reasoningEffort: reasoningEffort,
      modelCeiling: model.maxOutputTokens,
    );
    final opts = gg.GeminiOptions(
      temperature: r.resolve(LlmParameterDefinitionIdEnum.temperature),
      maxOutputTokens: maxOutputTokens,
      topP: r.resolve(LlmParameterDefinitionIdEnum.topP),
      topK: r.resolveInt(LlmParameterDefinitionIdEnum.topK),
      frequencyPenalty: r.resolve(
        LlmParameterDefinitionIdEnum.frequencyPenalty,
      ),
      presencePenalty: r.resolve(LlmParameterDefinitionIdEnum.presencePenalty),
      thinkingConfig: thinkingConfig,
    );
    return LlmRunner(model: genkitModel, genkit: _genkit, config: opts);
  }

  /// Gemini's 30 prebuilt voices (docs: generativelanguage.googleapis.com
  /// speech-generation > voices). Tones taken from the public reference.
  static const _ttsVoices = [
    TtsVoice(id: 'Zephyr', label: 'Zephyr', tone: 'Bright'),
    TtsVoice(id: 'Puck', label: 'Puck', tone: 'Upbeat'),
    TtsVoice(id: 'Charon', label: 'Charon', tone: 'Informative'),
    TtsVoice(id: 'Kore', label: 'Kore', tone: 'Firm'),
    TtsVoice(id: 'Fenrir', label: 'Fenrir', tone: 'Excitable'),
    TtsVoice(id: 'Leda', label: 'Leda', tone: 'Youthful'),
    TtsVoice(id: 'Orus', label: 'Orus', tone: 'Firm'),
    TtsVoice(id: 'Aoede', label: 'Aoede', tone: 'Breezy'),
    TtsVoice(id: 'Callirrhoe', label: 'Callirrhoe', tone: 'Easy-going'),
    TtsVoice(id: 'Autonoe', label: 'Autonoe', tone: 'Bright'),
    TtsVoice(id: 'Enceladus', label: 'Enceladus', tone: 'Breathy'),
    TtsVoice(id: 'Iapetus', label: 'Iapetus', tone: 'Clear'),
    TtsVoice(id: 'Umbriel', label: 'Umbriel', tone: 'Easy-going'),
    TtsVoice(id: 'Algieba', label: 'Algieba', tone: 'Smooth'),
    TtsVoice(id: 'Despina', label: 'Despina', tone: 'Smooth'),
    TtsVoice(id: 'Erinome', label: 'Erinome', tone: 'Clear'),
    TtsVoice(id: 'Algenib', label: 'Algenib', tone: 'Gravelly'),
    TtsVoice(id: 'Rasalgethi', label: 'Rasalgethi', tone: 'Informative'),
    TtsVoice(id: 'Laomedeia', label: 'Laomedeia', tone: 'Upbeat'),
    TtsVoice(id: 'Achernar', label: 'Achernar', tone: 'Soft'),
    TtsVoice(id: 'Alnilam', label: 'Alnilam', tone: 'Firm'),
    TtsVoice(id: 'Schedar', label: 'Schedar', tone: 'Even'),
    TtsVoice(id: 'Gacrux', label: 'Gacrux', tone: 'Mature'),
    TtsVoice(id: 'Pulcherrima', label: 'Pulcherrima', tone: 'Forward'),
    TtsVoice(id: 'Achird', label: 'Achird', tone: 'Friendly'),
    TtsVoice(id: 'Zubenelgenubi', label: 'Zubenelgenubi', tone: 'Casual'),
    TtsVoice(id: 'Vindemiatrix', label: 'Vindemiatrix', tone: 'Gentle'),
    TtsVoice(id: 'Sadachbia', label: 'Sadachbia', tone: 'Lively'),
    TtsVoice(id: 'Sadaltager', label: 'Sadaltager', tone: 'Knowledgeable'),
    TtsVoice(id: 'Sulafat', label: 'Sulafat', tone: 'Warm'),
  ];

  /// 24 BCP-47 codes officially supported by Gemini TTS (docs: Gemini API >
  /// speech-generation). `auto` is the app-level "let the model detect"
  /// sentinel; Gemini accepts it via `languageCode` omission at request time.
  static const _ttsLanguages = [
    TtsLanguage(code: TtsLanguage.autoCode, label: 'Auto-detect'),
    TtsLanguage(code: 'en-US', label: 'English (US)'),
    TtsLanguage(code: 'en-IN', label: 'English (India)'),
    TtsLanguage(code: 'ar-EG', label: 'Arabic (Egypt)'),
    TtsLanguage(code: 'de-DE', label: 'German (Germany)'),
    TtsLanguage(code: 'es-US', label: 'Spanish (US)'),
    TtsLanguage(code: 'fr-FR', label: 'French (France)'),
    TtsLanguage(code: 'hi-IN', label: 'Hindi (India)'),
    TtsLanguage(code: 'id-ID', label: 'Indonesian'),
    TtsLanguage(code: 'it-IT', label: 'Italian'),
    TtsLanguage(code: 'ja-JP', label: 'Japanese'),
    TtsLanguage(code: 'ko-KR', label: 'Korean'),
    TtsLanguage(code: 'pt-BR', label: 'Portuguese (Brazil)'),
    TtsLanguage(code: 'ru-RU', label: 'Russian'),
    TtsLanguage(code: 'nl-NL', label: 'Dutch'),
    TtsLanguage(code: 'pl-PL', label: 'Polish'),
    TtsLanguage(code: 'th-TH', label: 'Thai'),
    TtsLanguage(code: 'tr-TR', label: 'Turkish'),
    TtsLanguage(code: 'vi-VN', label: 'Vietnamese'),
    TtsLanguage(code: 'ro-RO', label: 'Romanian'),
    TtsLanguage(code: 'uk-UA', label: 'Ukrainian'),
    TtsLanguage(code: 'bn-BD', label: 'Bengali'),
    TtsLanguage(code: 'mr-IN', label: 'Marathi'),
    TtsLanguage(code: 'ta-IN', label: 'Tamil'),
    TtsLanguage(code: 'te-IN', label: 'Telugu'),
  ];

  @override
  List<TtsLanguage> get ttsLanguages => _ttsLanguages;

  @override
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async => _ttsVoices;

  /// Veo 3.1 rosters. Per-variant constraints (duration must be 8 for 1080p
  /// / 4k, lite only supports 720p) are enforced provider-side; we ship the
  /// broad roster and let the API surface bad combinations as job failures.
  static const _veoLiteOptions = OptionsVideo(
    resolutions: [VideoResolution(id: '720p', label: '720p')],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
    ],
    durations: [
      VideoDuration(seconds: 5, label: '5 seconds'),
      VideoDuration(seconds: 6, label: '6 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
    ],
  );

  static const _veoFullOptions = OptionsVideo(
    resolutions: [
      VideoResolution(id: '720p', label: '720p'),
      VideoResolution(id: '1080p', label: '1080p'),
    ],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
    ],
    durations: [
      VideoDuration(seconds: 4, label: '4 seconds'),
      VideoDuration(seconds: 6, label: '6 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
    ],
  );

  @override
  OptionsVideo? videoOptionsFor(String modelId) {
    // Model ids arrive with the `models/` prefix after `parseModel`.
    final bare = modelId.startsWith('models/')
        ? modelId.substring('models/'.length)
        : modelId;
    if (!bare.contains('veo')) return null;
    if (bare.contains('lite')) return _veoLiteOptions;
    return _veoFullOptions;
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
            Uri.parse('$baseUrl/$modelId:predictLongRunning'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'instances': [
                {'prompt': prompt},
              ],
              'parameters': {
                'aspectRatio': aspectRatioId,
                'resolution': resolutionId,
                'durationSeconds': durationSeconds.toString(),
              },
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.google,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final name = json['name'] as String?;
      if (name == null || name.isEmpty) {
        throw LlmFetchException(
          provider: LLMProviderEnum.google,
          providerLabel: label,
          statusCode: 200,
          message: 'Google video submit returned no operation name.',
        );
      }
      return name;
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
            Uri.parse('$baseUrl/$jobId'),
            headers: {'x-goog-api-key': apiKey},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.google,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final done = json['done'] == true;
      if (!done) return const VideoJobStatus(state: VideoJobStateEnum.polling);
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        return VideoJobStatus(
          state: VideoJobStateEnum.failed,
          errorMessage: error['message'] as String?,
        );
      }
      final responseField = json['response'] as Map<String, dynamic>?;
      final genVideo =
          responseField?['generateVideoResponse'] as Map<String, dynamic>?;
      final samples = genVideo?['generatedSamples'] as List?;
      final firstSample = samples?.firstOrNull as Map<String, dynamic>?;
      final video = firstSample?['video'] as Map<String, dynamic>?;
      final uri = video?['uri'] as String?;
      return VideoJobStatus(
        state: VideoJobStateEnum.done,
        progressPct: 100,
        resultUrl: uri,
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
            headers: {'x-goog-api-key': apiKey},
          )
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw LlmFetchException(
          provider: LLMProviderEnum.google,
          providerLabel: label,
          statusCode: response.statusCode,
          message: 'Google video download failed.',
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  Future<Uint8List> synthesizeTts({
    required String apiKey,
    required String baseUrl,
    required String text,
    required String voiceId,
    required String languageCode,
    required String modelId,
  }) async {
    // Model ids arrive from LlmModel.id carrying the `models/` prefix; the
    // REST path wants `{baseUrl}/{models/id}:generateContent`.
    final url = '$baseUrl/$modelId:generateContent';
    final speechConfig = <String, dynamic>{
      'voiceConfig': {
        'prebuiltVoiceConfig': {'voiceName': voiceId},
      },
    };
    if (languageCode != TtsLanguage.autoCode) {
      speechConfig['languageCode'] = languageCode;
    }
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': text},
                  ],
                },
              ],
              'generationConfig': {
                'responseModalities': ['AUDIO'],
                'speechConfig': speechConfig,
              },
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200) {
        final body = response.body;
        throw LlmFetchException(
          provider: LLMProviderEnum.google,
          providerLabel: label,
          statusCode: response.statusCode,
          message: body.length > 200 ? body.substring(0, 200) : body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Gemini omits / empties `candidates` when the request is blocked; an
      // empty list here must fall through to the "no audio" exception below,
      // not throw a bare "No element".
      final candidates = json['candidates'] as List?;
      final parts = candidates == null || candidates.isEmpty
          ? null
          : (candidates.first as Map<String, dynamic>?)?['content']
                as Map<String, dynamic>?;
      final partList = (parts?['parts'] as List?) ?? const [];
      for (final p in partList) {
        final inline =
            (p as Map<String, dynamic>?)?['inlineData']
                as Map<String, dynamic>?;
        final b64 = inline?['data'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          // Gemini returns raw L16 PCM at 24 kHz / 16-bit / mono. audioplayers
          // won't play raw PCM, so we wrap it in a minimal WAV header.
          final pcm = base64Decode(b64);
          return _wrapPcmAsWav(pcm);
        }
      }
      throw LlmFetchException(
        provider: LLMProviderEnum.google,
        providerLabel: label,
        statusCode: 200,
        message: 'Gemini TTS response contained no audio payload.',
      );
    } finally {
      client.close();
    }
  }

  /// Wraps a raw 16-bit little-endian mono PCM buffer at 24 kHz in a minimal
  /// RIFF/WAVE container. Gemini's TTS endpoint is documented to return PCM
  /// with these exact parameters.
  static Uint8List _wrapPcmAsWav(Uint8List pcm) {
    const sampleRate = 24000;
    const bitsPerSample = 16;
    const channels = 1;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final dataLen = pcm.lengthInBytes;
    final totalLen = 36 + dataLen;
    final header = ByteData(44);
    // RIFF chunk descriptor
    header.setUint32(0, 0x52494646); // 'RIFF'
    header.setUint32(4, totalLen, Endian.little);
    header.setUint32(8, 0x57415645); // 'WAVE'
    // fmt sub-chunk
    header.setUint32(12, 0x666d7420); // 'fmt '
    header.setUint32(16, 16, Endian.little); // PCM chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    header.setUint32(36, 0x64617461); // 'data'
    header.setUint32(40, dataLen, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }
}

/// Shared image aspect-ratio roster. All current providers that expose
/// aspect control (Grok, OpenAI, NanoGpt) offer the same three portable
/// ids with identical labels, so keep one source of truth — divergence
/// here would appear as inconsistent labels across provider pickers.
const OptionsImage _commonImageAspectRoster = OptionsImage(
  aspectRatios: [
    ImageAspectRatio(id: '1:1', label: '1:1 (Square)'),
    ImageAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
    ImageAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
  ],
);

/// Model ids that accept OpenAI's `size: "WxH"` JSON param on
/// `/images/generations`. Shared by [OpenAiProvider] (direct endpoint)
/// and [NanoGptProvider] (proxies the same OpenAI API shape). Leave as a
/// single set so "which models support aspect control" has one answer.
const Set<String> _openAiStyleAspectModelIds = {
  'dall-e-3',
  'gpt-image-1',
};

/// Resolves a portable aspect id into the pixel `WxH` string the specific
/// OpenAI-shape image model accepts. DALL-E 3 and gpt-image-1 use
/// different pixel pairs for the same ratios (`1792x1024` vs
/// `1536x1024`). Returns null for unknown (model, ratio) pairs — callers
/// then ship no `size` param and the provider picks its default.
String? _openAiStyleSizeFor(String modelId, String ratioId) {
  if (modelId == 'dall-e-3') {
    switch (ratioId) {
      case '1:1':
        return '1024x1024';
      case '16:9':
        return '1792x1024';
      case '9:16':
        return '1024x1792';
    }
  } else if (modelId == 'gpt-image-1') {
    switch (ratioId) {
      case '1:1':
        return '1024x1024';
      case '16:9':
        return '1536x1024';
      case '9:16':
        return '1024x1536';
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// Local OpenAI-compatible (KoboldCpp / Ollama / LM Studio / llama.cpp)
// ─────────────────────────────────────────────────────────────
