/// Selects which `video_gen_*.txt` template the prompt compactor uses, and
/// what contextual slices (chat history, free-prompt subject) get injected
/// before compaction. Each mode maps to one template file in
/// `assets/prompts/`; `free` additionally collects a user-supplied subject
/// via the free-prompt dialog before the compactor runs.
enum VideoGenerationModeEnum {
  character,
  face,
  scenario,
  lastMessage,
  background,
  free,
  selfie,
}

extension VideoGenerationModeEnumX on VideoGenerationModeEnum {
  String get label {
    switch (this) {
      case VideoGenerationModeEnum.character:
        return 'Character';
      case VideoGenerationModeEnum.face:
        return 'Face';
      case VideoGenerationModeEnum.scenario:
        return 'Scenario';
      case VideoGenerationModeEnum.lastMessage:
        return 'Last message';
      case VideoGenerationModeEnum.background:
        return 'Background';
      case VideoGenerationModeEnum.free:
        return 'Free prompt';
      case VideoGenerationModeEnum.selfie:
        return 'Selfie';
    }
  }

  /// `selfie` packs its schema fields into the same `{{subject}}` slot the
  /// `free` template uses, so both modes need the caller to supply a
  /// synthesised intent string in `LlmVideoPromptRequest.freePrompt`.
  bool get requiresFreePrompt =>
      this == VideoGenerationModeEnum.free ||
      this == VideoGenerationModeEnum.selfie;

  /// Whether the prompt builder folds recent chat history into the
  /// compactor input for this mode. Only `free` skips it — its subject
  /// comes from the user's typed input, not from conversational context.
  bool get usesChatHistory => this != VideoGenerationModeEnum.free;

  /// Whether this mode appears in the user-facing wand menu. `selfie` is
  /// excluded — it's only ever invoked by the `send_video` tool from a
  /// chat model, never picked manually.
  bool get isUserPickable => this != VideoGenerationModeEnum.selfie;
}
