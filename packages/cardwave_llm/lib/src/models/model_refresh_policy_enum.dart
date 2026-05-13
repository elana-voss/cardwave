enum ModelRefreshPolicyEnum { never, daily }

extension ModelRefreshPolicyEnumExtension on ModelRefreshPolicyEnum {
  String get label {
    switch (this) {
      case ModelRefreshPolicyEnum.never:
        return 'Never';
      case ModelRefreshPolicyEnum.daily:
        return 'Daily on startup';
    }
  }
}
