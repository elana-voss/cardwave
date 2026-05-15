import 'dart:convert';
import 'dart:io';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'app_test_helpers.dart';

/// Foundational sanity test: no network, no provider needed. Validates
/// that the app boots end-to-end on the emulator and that a settings
/// mutation survives a round-trip through the on-disk JSON file.
///
/// If this passes, the integration test runner is wired correctly. If it
/// fails, the rest of the suite has no chance — fix this one first.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings round-trip — change, save, reload from disk', (
    tester,
  ) async {
    await wipeAppData();

    app.main();
    await awaitAppReady(tester, timeout: const Duration(seconds: 30));

    final settings = SettingsService();

    // Sanity: fresh install — onboarding should not be marked complete
    // and theme should be the default (dark).
    expect(
      settings.settings.onboardingComplete,
      isFalse,
      reason: 'fresh install should leave onboardingComplete=false',
    );
    expect(
      settings.settings.themeMode,
      ThemeMode.dark,
      reason: 'default theme is dark',
    );

    // Mutate two unrelated fields and persist.
    settings.settings
      ..onboardingComplete = true
      ..themeMode = ThemeMode.light;
    await settings.saveSettings();

    // Read back the persisted JSON. On native (Android), the test reads
    // the on-disk file directly. On web, `dart:io File` and
    // `path_provider` aren't supported, so we go through the same
    // `AppStorage` abstraction the production app uses (IndexedDB-backed
    // on web).
    final Map<String, dynamic> raw;
    if (kIsWeb) {
      expect(
        await AppStorage.instance.fileExists(
          StorageDomainEnum.settings,
          AppConstants.settingsFileName,
        ),
        isTrue,
        reason: 'saveSettings should produce ${AppConstants.settingsFileName}',
      );
      raw =
          jsonDecode(
                await AppStorage.instance.readString(
                  StorageDomainEnum.settings,
                  AppConstants.settingsFileName,
                ),
              )
              as Map<String, dynamic>;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final settingsFile = File(
        '${dir.path}${Platform.pathSeparator}'
        '${AppConstants.settingsFileName}',
      );
      expect(
        settingsFile.existsSync(),
        isTrue,
        reason: 'saveSettings should produce ${AppConstants.settingsFileName}',
      );
      raw =
          jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
    }
    expect(raw['onboarding_complete'], isTrue);
    expect(raw['theme_mode'], 'light');
  });
}
