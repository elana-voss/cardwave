import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Persona management moved from a drawer-internal `/persona` route into a
/// `NavigationService.showPersonasDialog()` call (commit 74fc98f). This
/// test exercises the full path from the chat appbar:
///
///   1. Open end drawer → tap the persona button in the title row.
///   2. Drawer closes; AppDialog opens hosting `SettingsTabPersonas`.
///   3. Tap "New Persona" → `DialogPersona` (nested) opens.
///   4. Enter a name → save.
///   5. Tap the new RadioListTile to make it the active persona.
///   6. Close the dialog → reopen the drawer.
///   7. Drawer's title-row button now shows the new persona's name.
///
/// No network calls; runs without GROK_API_KEY.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'persona dialog — open from drawer, add, switch active',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Enter the chat workspace — the persona button lives on the chat
      // drawer's title row.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final settings = tester
          .element(find.byType(MaterialApp))
          .read<SettingsService>();

      // AppSettings auto-seeds one default persona on first run (see
      // app_settings.dart constructor); capture the count so we can
      // assert it grew by exactly one after Save.
      final initialCount = settings.settings.personas.length;
      expect(
        initialCount,
        1,
        reason: 'fresh-install settings auto-seed one default persona',
      );

      // Open end drawer.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      // Tap the drawer's persona button. Per app_end_drawer.dart, this
      // closes the drawer (rootNavigator pop) and opens the personas
      // dialog via NavigationService.showPersonasDialog().
      await tester.tap(find.byKey(const Key('drawer-persona-button')));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsTabPersonas),
        findsOneWidget,
        reason: 'tapping the persona button must open the personas dialog',
      );

      // Open the create-persona form.
      await tester.tap(find.byKey(const Key('persona-new-button')));
      await tester.pumpAndSettle();

      // DialogPersona is the only TextField source on screen; the first
      // field is the autofocused name field.
      const newName = 'Integration Test Persona';
      await tester.enterText(find.byType(TextField).first, newName);
      await dismissKeyboard(tester);

      await tester.tap(find.byKey(const Key('persona-edit-save')));
      await tester.pumpAndSettle();

      // PersonasController.addPersona appended + saved settings.
      expect(
        settings.settings.personas.length,
        initialCount + 1,
        reason: 'save must add exactly one persona',
      );
      final newPersona = settings.settings.personas.firstWhere(
        (p) => p.name == newName,
      );

      // Tap the new row's title text — the surrounding RadioListTile
      // catches the gesture and fires onChanged with the persona id,
      // setting settings.defaultPersonaId.
      await tester.tap(find.text(newName));
      await tester.pumpAndSettle();

      expect(
        settings.settings.defaultPersonaId,
        newPersona.id,
        reason: 'tapping the radio row must switch defaultPersonaId',
      );

      // Close the personas dialog (mobile-fullscreen close button).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Reopen the drawer; the title-row persona button now shows the
      // new active persona's name (TextButton.icon's label is bound to
      // settings.activePersona.name).
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      expect(
        find.text(newName),
        findsOneWidget,
        reason: 'drawer persona button should reflect the new active persona',
      );
    },
  );
}
