import 'package:cardwave_llm/src/image/llm_image_prompt_request.dart'
    show LlmHistorySnippet;
import 'package:cardwave_llm/src/video/video_generation_mode_enum.dart';

/// Primitive payload the package's video prompt builder consumes.
/// Mirrors `LlmImagePromptRequest` but adds [durationSeconds] — the
/// video templates reference `{{duration_seconds}}`, so the compactor
/// LLM needs the intended clip length to scope its output (one sustained
/// moment for 4s vs a multi-beat scene for 15s).
class LlmVideoPromptRequest {
  const LlmVideoPromptRequest({
    required this.mode,
    required this.charName,
    required this.userName,
    required this.characterDescription,
    required this.localVariables,
    required this.globalVariables,
    required this.recentHistory,
    required this.nsfwAllowed,
    required this.videoPromptPrefix,
    required this.durationSeconds,
    this.freePrompt = '',
  });

  final VideoGenerationModeEnum mode;
  final String charName;
  final String userName;
  final String characterDescription;
  final Map<String, String> localVariables;
  final Map<String, String> globalVariables;
  final List<LlmHistorySnippet> recentHistory;
  final bool nsfwAllowed;
  final String videoPromptPrefix;
  final int durationSeconds;

  /// Used when [mode] is [VideoGenerationModeEnum.free] (user-typed subject)
  /// or [VideoGenerationModeEnum.selfie] (intent string from `send_video`'s
  /// schema fields). Both modes substitute this into the template's
  /// `{{subject}}` slot. Empty string skips substitution.
  final String freePrompt;
}
