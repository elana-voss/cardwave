import 'package:cardwave_llm/src/observability/llm_log_event.dart';
import 'package:cardwave_llm/src/observability/llm_loggers.dart';
import 'package:cardwave_llm/src/pure/llm_pure_helpers.dart';
import 'package:cardwave_llm/src/repositories/prompt_repository.dart';
import 'package:cardwave_llm/src/utils/utils_prompt.dart';
import 'package:cardwave_llm/src/video/llm_video_prompt_request.dart';
import 'package:cardwave_llm/src/video/video_generation_mode_enum.dart';

class VideoPromptBuilderException implements Exception {
  const VideoPromptBuilderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Two-step video prompt assembly: compose a full instruction (character
/// description + recent chat history + per-mode template + optional NSFW
/// filter), send it to the user's **system** LLM, and treat the short
/// prose response as the final T2V prompt. The provider round-trip
/// (submit → poll → download) lives in `VideoGenerationService` —
/// splitting here keeps the compose-and-compact phase independent of the
/// async polling loop.
class VideoPromptBuilder {
  const VideoPromptBuilder({
    required this.pureHelpers,
    required this.promptRepository,
  });

  final LlmPureHelpers pureHelpers;
  final PromptRepository promptRepository;

  /// Returns the final prompt ready to hand to the video provider:
  /// (optional) character `videoPromptPrefix`, then the compactor's output.
  /// Throws [VideoPromptBuilderException] when the compactor returns an
  /// empty string. Caller resolves [systemPreset] (the compactor) before
  /// invoking.
  Future<String> buildPrompt({
    required ResolvedPreset systemPreset,
    required LlmVideoPromptRequest request,
  }) async {
    final runner = pureHelpers.createRunner(
      provider: systemPreset.provider,
      model: systemPreset.model,
      preset: systemPreset.preset,
    );

    final compactorInput = _composePromptInput(request);
    videoLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.video,
        title: 'TAGS OUTGOING',
        body:
            '\nMode: ${request.mode.name}'
            '\nDuration: ${request.durationSeconds}s'
            '\nLen: ${compactorInput.length}'
            '\n---\n$compactorInput',
      ),
    );

    final raw = (await runner.complete(compactorInput)).trim();
    videoLogger.info(
      LlmStructuredEvent(
        category: LlmEventCategoryEnum.video,
        title: 'TAGS INCOMING',
        body:
            '\nMode: ${request.mode.name}'
            '\nDuration: ${request.durationSeconds}s'
            '\nLen: ${raw.length}'
            '\nPrompt: $raw',
      ),
    );

    if (raw.isEmpty) {
      throw const VideoPromptBuilderException(
        'The system model returned an empty video description. '
        'Check that Settings → AI → System is set to a working model.',
      );
    }

    final prefix = request.videoPromptPrefix.trim();
    return prefix.isNotEmpty ? '$prefix, $raw' : raw;
  }

  String _composePromptInput(LlmVideoPromptRequest request) {
    String resolve(String text, String trackingId) =>
        UtilsPrompt.replacePlaceholders(
          text,
          charName: request.charName,
          userName: request.userName,
          localVariables: request.localVariables,
          globalVariables: request.globalVariables,
          trackingId: trackingId,
        );

    // Template substitutions outside the generic placeholder engine:
    // `{{subject}}` (free / selfie modes) and `{{duration_seconds}}`
    // (every mode — video models need the intended clip length).
    final rawTemplate = _templateForMode(request.mode);
    var templateWithSubject = rawTemplate.replaceAll(
      '{{duration_seconds}}',
      request.durationSeconds.toString(),
    );
    if (request.mode.requiresFreePrompt) {
      templateWithSubject = templateWithSubject.replaceAll(
        '{{subject}}',
        request.freePrompt,
      );
    }
    final resolvedTemplate = resolve(
      templateWithSubject,
      'videoGen_${request.mode.name}',
    );

    final fullPrompt = StringBuffer();

    if (request.characterDescription.trim().isNotEmpty) {
      fullPrompt
        ..writeln('Character description:')
        ..writeln(resolve(request.characterDescription, 'videoGen_desc'))
        ..writeln();
    }

    if (request.mode.usesChatHistory && request.recentHistory.isNotEmpty) {
      fullPrompt.writeln('Recent chat history:');
      for (final m in request.recentHistory) {
        fullPrompt.writeln('${m.label}: ${m.content}');
      }
      fullPrompt.writeln();
    }

    fullPrompt.writeln(resolvedTemplate);

    if (!request.nsfwAllowed) {
      fullPrompt
        ..writeln()
        ..writeln(promptRepository.videoGenNsfwFilter);
    }

    return fullPrompt.toString();
  }

  String _templateForMode(VideoGenerationModeEnum mode) {
    switch (mode) {
      case VideoGenerationModeEnum.character:
        return promptRepository.videoGenCharacter;
      case VideoGenerationModeEnum.face:
        return promptRepository.videoGenFace;
      case VideoGenerationModeEnum.scenario:
        return promptRepository.videoGenScenario;
      case VideoGenerationModeEnum.lastMessage:
        return promptRepository.videoGenLastMessage;
      case VideoGenerationModeEnum.background:
        return promptRepository.videoGenBackground;
      case VideoGenerationModeEnum.free:
        return promptRepository.videoGenFree;
      case VideoGenerationModeEnum.selfie:
        return promptRepository.videoGenSelfie;
    }
  }
}

/// Maximum chat-history snippets the caller should pass for modes that
/// use history. Mirrors `kImageGenMaxHistoryMessages`.
const int kVideoGenMaxHistoryMessages = 6;
