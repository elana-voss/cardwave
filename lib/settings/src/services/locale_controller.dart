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
  ///
  /// Persistence is unconditional: `SettingsService.init` assigns a non-null
  /// `characterPath` (falling back to the native default) before any save can
  /// run, so `saveSettings`'s `characterPath!` never trips — even during
  /// onboarding. A language picked on the first-run screen therefore survives
  /// a quit-before-finish, which matters most for non-English users setting
  /// their language up front.
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
    _registerPluralResolvers();
    final tag = SettingsService().settings.localeTag;
    if (tag != null) {
      LocaleSettings.setLocaleRaw(tag);
    } else {
      LocaleSettings.useDeviceLocale();
    }
  }

  /// slang ships CLDR cardinal plural resolvers for only a fixed set of
  /// languages (of ours: en, es — es-419's language code is `es` — and ru).
  /// The remaining UI languages otherwise fall back to a tolerant default
  /// resolver that also prints a console warning on every plural render.
  /// Register explicit resolvers so those locales pluralize per CLDR and stay
  /// silent. Called once at bootstrap.
  void _registerPluralResolvers() {
    // Single-category languages: only `other` applies (ja, zh-Hans, zh-Hant,
    // ko). `language: 'zh'` covers both Chinese scripts.
    String otherOnly(num n,
            {String? zero,
            String? one,
            String? two,
            String? few,
            String? many,
            String? other}) =>
        other!;
    for (final language in const ['ja', 'zh', 'ko']) {
      LocaleSettings.setPluralResolver(
        language: language,
        cardinalResolver: otherOnly,
      );
    }

    // pt-BR and hi: the `one` category also covers 0.
    String oneCoversZeroAndOne(num n,
            {String? zero,
            String? one,
            String? two,
            String? few,
            String? many,
            String? other}) =>
        (n == 0 || n == 1) ? (one ?? other!) : other!;
    for (final language in const ['pt', 'hi']) {
      LocaleSettings.setPluralResolver(
        language: language,
        cardinalResolver: oneCoversZeroAndOne,
      );
    }
  }
}
