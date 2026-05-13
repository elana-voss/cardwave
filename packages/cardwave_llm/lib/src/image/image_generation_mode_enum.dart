enum ImageGenerationModeEnum {
  character,
  face,
  scenario,
  lastMessage,
  background,
  free,
  selfie,
}

extension ImageGenerationModeEnumX on ImageGenerationModeEnum {
  String get label {
    switch (this) {
      case ImageGenerationModeEnum.character:
        return 'Character';
      case ImageGenerationModeEnum.face:
        return 'Face';
      case ImageGenerationModeEnum.scenario:
        return 'Scenario';
      case ImageGenerationModeEnum.lastMessage:
        return 'Last message';
      case ImageGenerationModeEnum.background:
        return 'Background';
      case ImageGenerationModeEnum.free:
        return 'Free prompt';
      case ImageGenerationModeEnum.selfie:
        return 'Selfie';
    }
  }

  /// `selfie` packs its schema fields into the same `{{subject}}` slot the
  /// `free` template uses, so both modes need the caller to supply a synthesised
  /// intent string in `LlmImagePromptRequest.freePrompt`.
  bool get requiresFreePrompt =>
      this == ImageGenerationModeEnum.free ||
      this == ImageGenerationModeEnum.selfie;

  /// Whether the prompt builder folds recent chat history into the
  /// compactor input for this mode. Only `free` skips it — its subject
  /// comes from the user's typed input, not from conversational context.
  bool get usesChatHistory => this != ImageGenerationModeEnum.free;

  /// Whether this mode appears in the user-facing wand menu. `selfie` is
  /// excluded — it's only ever invoked by the `send_selfie` tool from a chat
  /// model, never picked manually.
  bool get isUserPickable => this != ImageGenerationModeEnum.selfie;
}
