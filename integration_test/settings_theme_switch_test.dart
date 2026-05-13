import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

/// UI-driven theme switch: gear menu → "App Settings" → tap the "Light"
/// segment of the SegmentedButton, assert both SettingsService and
/// ThemeNotifier flipped, then close + re-open the dialog and assert the
/// state survived the dismiss/reopen.
///
/// Complements settings_round_trip_test.dart which mutates via the
/// SettingsService API and reads the JSON file directly. This one drives
/// the actual user flow through SettingsGearMenu, exercising the popup +
/// AppDialog + SegmentedButton wiring.
///
/// No API calls, but still gated on the Grok key: the gear menu only
/// renders post-onboarding, and the only sanctioned way to skip onboarding
/// in tests is `seedGrokRecovery` (CLAUDE.md bans hand-built settings JSON
/// because of schema drift).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Settings — theme switch via gear menu',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Default theme is dark (asserted in settings_round_trip_test).
      expect(
        SettingsService().settings.themeMode,
        ThemeMode.dark,
        reason: 'fresh install should boot in dark mode',
      );

      // Open gear menu. The SettingsGearMenu PopupMenuButton uses tooltip
      // 'Settings'; matching by tooltip avoids ambiguity with any other
      // Icons.settings instance in the tree (e.g. the menu's own item icon).
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();

      // Pick "App Settings" from the popup. Opens an AppDialog hosting
      // SettingsTabGeneral.
      await tester.tap(find.byKey(const Key('settings-app-settings')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // SegmentedButton segments are icon-only on narrow viewports
      // (settings_tab_general.dart drops labels below mobileBreakpoint to
      // avoid an overflow assertion in ListTile.trailing). Find the Light
      // segment by descending into the SegmentedButton — there are two
      // Icons.light_mode in the tree once light is selected (segment +
      // tile leading icon), so the descendant scope is required even on
      // wide viewports.
      final lightSegment = find.descendant(
        of: find.byType(SegmentedButton<ThemeMode>),
        matching: find.byIcon(Icons.light_mode),
      );
      await tester.ensureVisible(lightSegment);
      await tester.pumpAndSettle();
      await tester.tap(lightSegment);
      await tester.pumpAndSettle();

      expect(
        SettingsService().settings.themeMode,
        ThemeMode.light,
        reason: 'tapping Light should mutate SettingsService.themeMode',
      );
      expect(
        ThemeNotifier().themeMode,
        ThemeMode.light,
        reason: 'ThemeNotifier drives MaterialApp themeMode — must agree',
      );

      // Underlying use case check: the rendered theme actually flipped to
      // light. Asserts on the active Theme inherited at a deep widget
      // (SettingsGearMenu sits in the appbar, so it's always mounted). A
      // regression where ThemeNotifier flipped but MaterialApp didn't
      // rebuild — or where MaterialApp uses the wrong themeMode source —
      // would pass the state checks above but fail this one.
      final renderedBrightness = Theme.of(
        tester.element(find.byType(SettingsGearMenu).first),
      ).brightness;
      expect(
        renderedBrightness,
        Brightness.light,
        reason: 'rendered theme should be light after the switch',
      );

      // Close the dialog. AppDialog auto-renders a dismiss affordance with
      // the stable [AppDialog.dismissKey]: a CloseButton icon in the AppBar
      // leading slot on fullscreen-mobile, a "Close" TextButton in the
      // bottom action row on desktop. `.last` scopes to the topmost dialog
      // in case stacked dialogs each carry the same key.
      await tester.tap(find.byKey(AppDialog.dismissKey).last);
      await tester.pumpAndSettle();

      // Re-open via the same gear menu path. State must survive the
      // dismiss/reopen — the dialog reads ThemeNotifier on each build, so
      // a stale-cache regression would surface here.
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-app-settings')));
      await tester.pumpAndSettle();

      expect(
        ThemeNotifier().themeMode,
        ThemeMode.light,
        reason: 'theme must persist across dialog dismiss/reopen',
      );

      // Sanity: SettingsGearMenu is still mounted in the underlying scaffold.
      expect(
        find.byType(SettingsGearMenu),
        findsWidgets,
        reason: 'gear menu should remain available after dialog reopen',
      );
    },
  );
}
