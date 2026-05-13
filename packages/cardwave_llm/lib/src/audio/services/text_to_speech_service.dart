import 'dart:typed_data';

import 'package:cardwave_llm/src/models/llm_provider.dart';
import 'package:cardwave_llm/src/models/llm_provider_config.dart';
import 'package:cardwave_llm/src/models/llm_provider_enum.dart';
import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/utils/utils_text.dart';

/// Synthesizes speech bytes for an arbitrary provider/model/voice/language.
/// Stateless and notifier-free — caller (the chat-side
/// `TextToSpeechController`) owns playback, caching, and per-message UI
/// state.
class TextToSpeechService {
  const TextToSpeechService();

  /// Cleans the input text via [UtilsText.cleanForTts] (strips roleplay
  /// asterisks / emojis / fancy chars), then dispatches to the matching
  /// provider's synthesizer. Throws on provider error — caller decides
  /// whether to surface a snackbar or log only.
  Future<Uint8List> synthesize({
    required LlmProviderConfig provider,
    required String modelId,
    required String text,
    required String voiceId,
    required String languageCode,
  }) async {
    final cleaned = UtilsText.cleanForTts(text);
    ttsLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.tts,
        title: 'OUTGOING',
        body:
            '\nProvider: ${provider.providerEnum.name}'
            '\nModel: $modelId'
            '\nVoice: $voiceId'
            '\nLanguage: $languageCode'
            '\nTextLen: ${cleaned.length}'
            '\nText: $cleaned',
        providerEnumName: provider.providerEnum.name,
        modelId: modelId,
      ),
    );
    final stopwatch = Stopwatch()..start();
    final Uint8List bytes;
    try {
      bytes = await _dispatch(
        provider: provider,
        modelId: modelId,
        text: cleaned,
        voiceId: voiceId,
        languageCode: languageCode,
      );
    } catch (e) {
      stopwatch.stop();
      final detail = e is LlmFetchException
          ? 'status=${e.statusCode ?? '?'} body=${e.message}'
          : e.toString();
      ttsLogger.severe(
        LlmStructuredEvent(
          category: LlmEventCategoryEnum.tts,
          title: 'ERROR',
          body:
              '\nProvider: ${provider.providerEnum.name}'
              '\nModel: $modelId'
              '\nLatencyMs: ${stopwatch.elapsedMilliseconds}'
              '\n$detail',
          providerEnumName: provider.providerEnum.name,
          modelId: modelId,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
      rethrow;
    }
    stopwatch.stop();
    ttsLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.tts,
        title: 'INCOMING',
        body:
            '\nProvider: ${provider.providerEnum.name}'
            '\nBytes: ${bytes.length}'
            '\nLatencyMs: ${stopwatch.elapsedMilliseconds}',
        providerEnumName: provider.providerEnum.name,
        modelId: modelId,
        latencyMs: stopwatch.elapsedMilliseconds,
      ),
    );
    return bytes;
  }

  Future<Uint8List> _dispatch({
    required LlmProviderConfig provider,
    required String modelId,
    required String text,
    required String voiceId,
    required String languageCode,
  }) async {
    switch (provider.providerEnum) {
      case LLMProviderEnum.grok:
        final grok = LlmProvider.of(LLMProviderEnum.grok) as GrokProvider;
        return grok.synthesizeTts(
          apiKey: provider.apiKey,
          baseUrl: provider.baseUrl ?? grok.defaultBaseUrl,
          text: text,
          voiceId: voiceId,
          languageCode: languageCode,
        );
      case LLMProviderEnum.openai:
        final openai = LlmProvider.of(LLMProviderEnum.openai) as OpenAiProvider;
        return openai.synthesizeTts(
          apiKey: provider.apiKey,
          baseUrl: provider.baseUrl ?? openai.defaultBaseUrl,
          text: text,
          voiceId: voiceId,
          modelId: modelId,
        );
      case LLMProviderEnum.google:
        final google = LlmProvider.of(LLMProviderEnum.google) as GoogleProvider;
        return google.synthesizeTts(
          apiKey: provider.apiKey,
          baseUrl: provider.baseUrl ?? google.defaultBaseUrl,
          text: text,
          voiceId: voiceId,
          languageCode: languageCode,
          modelId: modelId,
        );
      case LLMProviderEnum.openrouter:
        final or =
            LlmProvider.of(LLMProviderEnum.openrouter) as OpenRouterProvider;
        return or.synthesizeTts(
          apiKey: provider.apiKey,
          baseUrl: provider.baseUrl ?? or.defaultBaseUrl,
          text: text,
          voiceId: voiceId,
          modelId: modelId,
        );
      case LLMProviderEnum.nanogpt:
        final nano = LlmProvider.of(LLMProviderEnum.nanogpt) as NanoGptProvider;
        return nano.synthesizeTts(
          apiKey: provider.apiKey,
          baseUrl: provider.baseUrl ?? nano.defaultBaseUrl,
          text: text,
          voiceId: voiceId,
          modelId: modelId,
        );
      default:
        throw UnsupportedError(
          '${provider.providerEnum} TTS not implemented yet',
        );
    }
  }
}
