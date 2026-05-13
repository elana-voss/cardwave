import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

/// Onboarding walkthrough test. Skips the seed so the fresh-install
/// flow is exercised: type Grok key, finish, verify the app lands on
/// the character grid with onboardingComplete flipped true. Proves the
/// onboarding → settings → first-launch pipeline works end-to-end.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Onboarding walkthrough — enter key, finish',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      // Intentionally NO seedGrokRecovery — we want to drive onboarding.

      app.main();
      await awaitAppReady(tester);

      // On Android, the onboarding storage step is skipped. The first real
      // step is the AI Connection step asking for an API key.
      final apiKeyField = find.byKey(const Key('onboarding-api-key')).first;
      expect(
        apiKeyField,
        findsOneWidget,
        reason: 'Onboarding should surface an API key TextField',
      );
      await tester.enterText(apiKeyField, grokApiKey);
      await tester.pump();
      await dismissKeyboard(tester);

      // Debounce + model fetch (the onboarding controller pulls models
      // after a 500ms debounce). Poll until a Finish/Next button appears
      // enabled or timeout.
      await _awaitOnboardingReady(tester);

      // Tick the disclaimer checkbox — Finish is gated on acceptedDisclaimer
      // (see onboarding_page.dart:63). Without this, the Finish tap fires a
      // snackbar and onboardingComplete never flips.
      await tester.tap(find.byKey(const Key('onboarding-disclaimer')));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));

      // Progress through remaining steps. Finish button is labeled "Finish"
      // on the last step. Earlier steps have "Next". Tap whichever is shown,
      // repeatedly, up to 5 times to cover all steps.
      for (var i = 0; i < 5; i++) {
        final finish = find.byKey(const Key('onboarding-finish'));
        if (finish.evaluate().isNotEmpty) {
          await tester.tap(finish);
          await tester.pumpAndSettle(const Duration(seconds: 3));
          break;
        }
        final next = find.byKey(const Key('onboarding-next'));
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
          await tester.pumpAndSettle(const Duration(seconds: 1));
          continue;
        }
        fail('Neither Next nor Finish button found at onboarding step $i');
      }

      // Landed on grid — verify a card is rendered and settings are flipped.
      expect(
        find.byType(CharacterGridItem),
        findsAtLeastNWidgets(1),
        reason: 'Onboarding finish should route to the character grid',
      );
      expect(
        SettingsService().settings.onboardingComplete,
        isTrue,
        reason: 'finishOnboarding must flip onboardingComplete=true',
      );
      expect(
        SettingsService().settings.providerConfigs.length,
        1,
        reason: 'one Grok provider should be configured',
      );
    },
  );
}

Future<void> _awaitOnboardingReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const Key('onboarding-next')).evaluate().isNotEmpty ||
        find.byKey(const Key('onboarding-finish')).evaluate().isNotEmpty) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail(
    'Onboarding did not reach a step with Next/Finish in '
    '${timeout.inSeconds}s — model fetch may have failed.',
  );
}
