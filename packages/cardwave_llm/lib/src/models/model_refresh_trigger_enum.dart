enum ModelRefreshTriggerEnum { manual, startupDaily, recoveryRebuild }

extension ModelRefreshTriggerEnumExtension on ModelRefreshTriggerEnum {
  String get label {
    switch (this) {
      case ModelRefreshTriggerEnum.manual:
        return 'manual';
      case ModelRefreshTriggerEnum.startupDaily:
        return 'startup daily';
      case ModelRefreshTriggerEnum.recoveryRebuild:
        return 'recovery rebuild';
    }
  }
}
