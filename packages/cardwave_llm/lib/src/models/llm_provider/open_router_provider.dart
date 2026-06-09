part of '../llm_provider.dart';

// ─────────────────────────────────────────────────────────────
// OpenRouter (aggregator)
// ─────────────────────────────────────────────────────────────
class OpenRouterProvider extends LlmProvider {
  const OpenRouterProvider();

  @override
  LLMProviderEnum get enumValue => LLMProviderEnum.openrouter;
  @override
  String get label => 'OpenRouter';
  @override
  String get defaultBaseUrl => 'https://openrouter.ai/api/v1';

  /// Voice rosters for OpenRouter's OpenAI-family audio models. OR does not
  /// expose a `/voices` endpoint; it routes to OpenAI under the hood so the
  /// same voice set applies. Non-OpenAI vendors on OR (e.g. `elevenlabs/*`)
  /// aren't covered here — see MEMORY.md "TTS add-ons deferred".
  @override
  Future<List<TtsVoice>> fetchTtsVoices({
    required String apiKey,
    required String baseUrl,
    required String modelId,
  }) async => openAiVoicesFor(modelId);

  /// OR TTS runs through OpenAI which auto-detects input language — no
  /// user-selectable list. Hides the Language tile in the chat drawer.
  @override
  List<TtsLanguage> get ttsLanguages => const [];

  /// Generic OR video roster. OR proxies multiple video providers (Veo,
  /// Runway, Pixverse); this roster covers the common subset. Individual
  /// models may reject some combinations — error surfaces as a job failure.
  static const _orVideoOptions = OptionsVideo(
    resolutions: [
      VideoResolution(id: '720p', label: '720p'),
      VideoResolution(id: '1080p', label: '1080p'),
    ],
    aspectRatios: [
      VideoAspectRatio(id: '16:9', label: '16:9 (Landscape)'),
      VideoAspectRatio(id: '9:16', label: '9:16 (Portrait)'),
      VideoAspectRatio(id: '1:1', label: '1:1 (Square)'),
    ],
    durations: [
      VideoDuration(seconds: 4, label: '4 seconds'),
      VideoDuration(seconds: 6, label: '6 seconds'),
      VideoDuration(seconds: 8, label: '8 seconds'),
    ],
  );

  @override
  OptionsVideo? videoOptionsFor(String modelId) => _orVideoOptions;

  // OpenRouter image output goes through `/chat/completions` with
  // `modalities: ["image","text"]` — not `/images/generations` — and
  // that schema doesn't reliably accept `aspect_ratio` / `size` across
  // the OR image model catalog (Gemini Nano Banana, GPT-5 image, etc.).
  // Tile hides for OR, request ships no size params. If OR ever exposes
  // aspect control through its chat-completions path, flip this to
  // populate a roster for the specific model families that accept it.
  @override
  OptionsImage? imageOptionsFor(String modelId) => null;

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
            Uri.parse('$baseUrl/videos'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': modelId,
              'prompt': prompt,
              'aspectRatio': aspectRatioId,
              'resolution': resolutionId,
              'duration': durationSeconds,
            }),
          )
          .timeout(const Duration(minutes: 1));
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openrouter,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final id = (json['id'] ?? json['jobId']) as String?;
      if (id == null || id.isEmpty) {
        throw LlmFetchException(
          provider: LLMProviderEnum.openrouter,
          providerLabel: label,
          statusCode: 200,
          message: 'OpenRouter video submit returned no job id.',
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
          provider: LLMProviderEnum.openrouter,
          providerLabel: label,
          statusCode: response.statusCode,
          message: response.body,
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = ((json['status'] as String?) ?? '').toLowerCase();
      final progress = (json['progress'] as num?)?.toInt();
      final isDone =
          status == 'completed' || status == 'done' || status == 'succeeded';
      final isFailed = status == 'failed' || status == 'error';
      if (isDone) {
        return VideoJobStatus(
          state: VideoJobStateEnum.done,
          progressPct: 100,
          resultUrl: '$baseUrl/videos/$jobId/content',
        );
      }
      if (isFailed) {
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
          provider: LLMProviderEnum.openrouter,
          providerLabel: label,
          statusCode: response.statusCode,
          message: 'OpenRouter video download failed.',
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }

  /// Synthesize audio via OR's `/chat/completions` with `modalities:['text',
  /// 'audio']`. OR REQUIRES SSE streaming for audio output — accumulate
  /// `delta.audio.data` chunks (base64), concat, decode, return raw WAV
  /// bytes. `audioplayers` plays WAV cross-platform.
  Future<Uint8List> synthesizeTts({
    required String apiKey,
    required String baseUrl,
    required String text,
    required String voiceId,
    required String modelId,
  }) async {
    final client = http.Client();
    try {
      final request =
          http.Request('POST', Uri.parse('$baseUrl/chat/completions'))
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode({
              'model': modelId,
              'messages': [
                {'role': 'user', 'content': text},
              ],
              'modalities': ['text', 'audio'],
              'audio': {'voice': voiceId, 'format': 'wav'},
              'stream': true,
            });
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        throw LlmFetchException(
          provider: LLMProviderEnum.openrouter,
          providerLabel: label,
          statusCode: streamed.statusCode,
          message: body.length > 200 ? body.substring(0, 200) : body,
        );
      }
      final chunks = StringBuffer();
      var buffer = '';
      await for (final raw in streamed.stream.transform(utf8.decoder)) {
        // SSE parser needs random-access slicing (indexOf/substring) — a
        // StringBuffer would force a toString() round-trip on every chunk.
        buffer += raw;
        // SSE events are delimited by blank lines; process whole lines only.
        int newline;
        while ((newline = buffer.indexOf('\n')) != -1) {
          final line = buffer.substring(0, newline).trimRight();
          buffer = buffer.substring(newline + 1);
          if (!line.startsWith('data:')) continue;
          final payload = line.substring('data:'.length).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          final chunk = jsonDecode(payload) as Map<String, dynamic>;
          final choices = chunk['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta =
              (choices.first as Map<String, dynamic>)['delta']
                  as Map<String, dynamic>?;
          final audio = delta?['audio'] as Map<String, dynamic>?;
          final data = audio?['data'] as String?;
          if (data != null) chunks.write(data);
        }
      }
      return base64Decode(chunks.toString());
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
    final name = (json['name'] as String?) ?? id;
    final architecture = json['architecture'] as Map<String, dynamic>?;
    final pricing = json['pricing'] as Map<String, dynamic>?;
    final topProvider = json['top_provider'] as Map<String, dynamic>?;
    final supportedRaw = json['supported_parameters'] as List<dynamic>?;
    final defaultRaw = json['default_parameters'] as Map<String, dynamic>?;

    final inputModalities = LlmCapabilities.parseModalities(
      architecture?['input_modalities'] as List<dynamic>?,
    );
    final outputModalities = LlmCapabilities.parseModalities(
      architecture?['output_modalities'] as List<dynamic>?,
    );
    if (outputModalities.remove(LlmModelCapabilitiesEnum.audioTts)) {
      final lowerId = id.toLowerCase();
      final isMusic =
          lowerId.contains('music') ||
          lowerId.contains('suno') ||
          lowerId.contains('musicgen') ||
          lowerId.contains('lyria') ||
          lowerId.contains('chirp');
      outputModalities.add(
        isMusic
            ? LlmModelCapabilitiesEnum.audioMusic
            : LlmModelCapabilitiesEnum.audioTts,
      );
    }

    final orParams = (supportedRaw ?? []).map((e) => e.toString()).toList();
    final reasoning =
        orParams.contains('reasoning') ||
        orParams.contains('include_reasoning');
    final toolCalling =
        orParams.contains('tools') || orParams.contains('tool_choice');
    // OR's supported_parameters lists 'structured_outputs' for models with
    // hard schema-constrained decoding, and 'response_format' for the
    // weaker JSON-mode-only path. Either is enough for our auto-tag use.
    final structuredOutput =
        orParams.contains('structured_outputs') ||
        orParams.contains('response_format');

    // OpenRouter pricing is USD per token as strings. Normalize to per-million.
    final modelPricing = pricing != null
        ? LlmPricing(
            prompt:
                (double.tryParse(pricing['prompt']?.toString() ?? '') ?? 0.0) *
                1000000,
            completion:
                (double.tryParse(pricing['completion']?.toString() ?? '') ??
                    0.0) *
                1000000,
          )
        : null;

    return LlmModel(
      id: id,
      name: name,
      description: json['description'] as String?,
      created: json['created'] as int?,
      contextLength:
          (json['context_length'] as int?) ??
          LlmConstants.fallbackContextLength,
      maxOutputTokens:
          (topProvider?['max_completion_tokens'] as int?) ??
          LlmConstants.fallbackMaxResponseTokens,
      capabilities: LlmCapabilities(
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        reasoning: reasoning,
        toolCalling: toolCalling,
        structuredOutput: structuredOutput,
      ),
      supportedParameters: _mapSupportedParams(supportedRaw),
      defaultParameters: _mapDefaultParams(defaultRaw),
      pricing: modelPricing,
    );
  }

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
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      parse: (body) => (body['data'] as List?) ?? const [],
    );
  }

  /// Public, unauth'd OR endpoint listing ZDR-compliant model+provider pairs.
  Future<List<dynamic>> fetchRawZdrEntries({
    required http.Client client,
    required String baseUrl,
  }) {
    return _loggedFetchRawModels(
      client: client,
      url: '$baseUrl/endpoints/zdr',
      headers: const {'Content-Type': 'application/json'},
      parse: (body) => (body['data'] as List?) ?? const [],
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
