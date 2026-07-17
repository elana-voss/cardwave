enum LlmProviderDomainEnum {
  chat,
  system,
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
      case LlmProviderDomainEnum.image:
      case LlmProviderDomainEnum.audioTts:
      case LlmProviderDomainEnum.audioMusic:
      case LlmProviderDomainEnum.video:
        return 0.8;
    }
  }

  /// Domains the user may leave unassigned (no feature hard-depends on them).
  /// Chat/system always auto-fill to the first valid preset.
  bool get isOptional {
    switch (this) {
      case LlmProviderDomainEnum.image:
      case LlmProviderDomainEnum.audioTts:
      case LlmProviderDomainEnum.audioMusic:
      case LlmProviderDomainEnum.video:
        return true;
      case LlmProviderDomainEnum.chat:
      case LlmProviderDomainEnum.system:
        return false;
    }
  }

  String get label {
    switch (this) {
      case LlmProviderDomainEnum.chat:
        return 'Chat';
      case LlmProviderDomainEnum.system:
        return 'System';
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
