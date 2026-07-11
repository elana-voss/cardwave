import 'dart:async';

import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:flutter/foundation.dart';

/// Owns the app's UI language. Mirrors [ThemeNotifier]: a singleton
/// [ChangeNotifier] the language modal listens to. Unlike the theme notifier
/// (pure display state), this one also persists the choice through the
/// [SettingsService] singleton, because the live slang locale and the stored
/// [AppSettings.localeTag] must stay in lockstep.
class LocaleController extends ChangeNotifier {
  factory LocaleController() => _instance;
  LocaleController._internal();
  static final LocaleController _instance = LocaleController._internal();

  /// The persisted BCP-47 tag, or null when following the device locale.
  String? get localeTag => SettingsService().settings.localeTag;

  /// The active slang locale (never null — resolves to the device locale, or
  /// the base locale, when no tag is set).
  AppLocale get currentLocale => LocaleSettings.currentLocale;

  /// Applies [tag] as the UI language (null = follow the device locale),
  /// switches the live slang locale, persists it, and notifies listeners so
  /// the language modal re-marks its checkmark.
  void setLocale(String? tag) {
    if (tag == null) {
      LocaleSettings.useDeviceLocale();
    } else {
      LocaleSettings.setLocaleRaw(tag);
    }
    final settingsService = SettingsService();
    settingsService.settings.localeTag = tag;
    unawaited(settingsService.saveSettings());
    notifyListeners();
  }

  /// Applies the persisted [AppSettings.localeTag] once at bootstrap. Called
  /// right after settings load, at the same point the [ThemeNotifier] is
  /// seeded from saved settings. A null tag follows the device locale.
  void applyPersisted() {
    final tag = SettingsService().settings.localeTag;
    if (tag != null) {
      LocaleSettings.setLocaleRaw(tag);
    } else {
      LocaleSettings.useDeviceLocale();
    }
  }
}
