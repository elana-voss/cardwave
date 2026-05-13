import 'package:cardwave_llm/src/image/image_generation_mode_enum.dart';

/// History snippet a prompt builder folds into its compactor input.
/// Pre-extracted by the caller from the chat session — the package never
/// sees `ChatMessage` / `ChatSession`.
typedef LlmHistorySnippet = ({String label, String content});

/// Primitive payload the package's image-prompt builders consume.
///
/// All fields are values, not app-domain types. The caller (the chat
/// controller) extracts them from `ChatSession` / `CharacterFile` /
/// `AppSettings` before invoking the service. `localVariables` and
/// `globalVariables` are mutable maps because the placeholder engine's
/// `setvar`/`pick` operators write back into them.
class LlmImagePromptRequest {
  const LlmImagePromptRequest({
    required this.mode,
    required this.charName,
    required this.userName,
    required this.characterDescription,
    required this.localVariables,
    required this.globalVariables,
    required this.recentHistory,
    required this.nsfwAllowed,
    required this.imagePromptPrefix,
    this.freePrompt = '',
    this.caption = '',
  });

  final ImageGenerationModeEnum mode;
  final String charName;
  final String userName;
  final String characterDescription;
  final Map<String, String> localVariables;
  final Map<String, String> globalVariables;
  final List<LlmHistorySnippet> recentHistory;

  /// Resolved per-session-or-character flag; controls whether the package
  /// appends the NSFW filter prompt block to the compactor's input.
  final bool nsfwAllowed;

  /// Prefix prepended to the compactor's tag-list output (e.g. a stylistic
  /// tag the character ships with). Empty string skips it.
  final String imagePromptPrefix;

  /// Used when [mode] is [ImageGenerationModeEnum.free] (user-typed subject)
  /// or [ImageGenerationModeEnum.selfie] (intent string from `send_selfie`'s
  /// schema fields). Both modes substitute this into the template's
  /// `{{subject}}` slot. Empty string skips substitution.
  final String freePrompt;

  /// Verbatim text to render on the image (Instagram-overlay style). The
  /// service appends `, with the text "<caption>" rendered on the image`
  /// to the system-model output so the system model can never paraphrase
  /// the user-visible caption text. Empty string skips the suffix.
  final String caption;
}
