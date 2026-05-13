enum LlmProviderDomainEnum {
  chat,
  system,
  assistant,
  image,
  audioTts,
  audioMusic,
  video,
}

extension LlmProviderDomainEnumExtension on LlmProviderDomainEnum {
  double get defaultTemperature {
    switch (this) {
      case LlmProviderDomainEnum.chat:
        return 1;
      case LlmProviderDomainEnum.system:
        return 0.1;
      case LlmProviderDomainEnum.assistant:
        return 0.7;
      case LlmProviderDomainEnum.image:
      case LlmProviderDomainEnum.audioTts:
      case LlmProviderDomainEnum.audioMusic:
      case LlmProviderDomainEnum.video:
        return 0.8;
    }
  }

  /// Domains the user may leave unassigned (no feature hard-depends on them).
  /// Chat/system/assistant always auto-fill to the first valid preset.
  bool get isOptional {
    switch (this) {
      case LlmProviderDomainEnum.image:
      case LlmProviderDomainEnum.audioTts:
      case LlmProviderDomainEnum.audioMusic:
      case LlmProviderDomainEnum.video:
        return true;
      case LlmProviderDomainEnum.chat:
      case LlmProviderDomainEnum.system:
      case LlmProviderDomainEnum.assistant:
        return false;
    }
  }

  String get label {
    switch (this) {
      case LlmProviderDomainEnum.chat:
        return 'Chat';
      case LlmProviderDomainEnum.system:
        return 'System';
      case LlmProviderDomainEnum.assistant:
        return 'Assistant';
      case LlmProviderDomainEnum.image:
        return 'Image';
      case LlmProviderDomainEnum.audioTts:
        return 'Speech';
      case LlmProviderDomainEnum.audioMusic:
        return 'Music';
      case LlmProviderDomainEnum.video:
        return 'Video';
    }
  }
}
