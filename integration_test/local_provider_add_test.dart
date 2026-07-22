import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';
import 'helpers/local_llm_test_backend.dart';

/// Drives the full Add-Local-Provider UI flow against either an
/// in-process Dart mock server (default) or a real KoboldCpp/Ollama/
/// LM Studio/llama.cpp instance reachable at `LOCAL_LLM_BASE_URL`
/// (set by `scripts/run_kobold_integration.sh`).
///
/// Underlying use case: a user with a self-hosted OpenAI-compatible
/// server adds it to Cardwave so they can chat against their local
/// model. Catches regressions in the Settings → AI Providers → New
/// Local Provider path, the Connect & Fetch flow, the dismissal-block
/// guard, and the post-save profile landing in the providers list.
///
/// No GROK_API_KEY required — the local-provider path is independent
/// of cloud credentials.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local provider — add via Settings',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      if (kIsWeb) {
        markTestSkipped(
          'Android-only: uses HttpServer.bind for mock LLM server',
        );
        return;
      }
      final backend = LocalLlmTestBackend(enableChat: false);
      await backend.setUp();
      addTearDown(backend.tearDown);

      await wipeAppData();
      await seedOnboardingComplete();
      // A card must be on the grid for awaitGridReady to settle; this test
      // never taps it, it just needs the grid past its initial scan before
      // opening the settings menu.
      await seedTestCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Grid → gear menu → AI Providers
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-ai-providers')));
      await tester.pumpAndSettle();

      // AI Settings → open the "New Provider" dropdown then tap
      // "Your own server (OpenAI-compatible)" inside it. The three
      // add-provider variants were consolidated into one FilledButton +
      // MenuAnchor; opening the menu and clicking the menu item is the
      // new flow.
      await tester.tap(find.widgetWithText(FilledButton, 'New Provider'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          MenuItemButton,
          'Your own server (OpenAI-compatible)',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Add Custom Provider'),
        findsOneWidget,
        reason: 'local provider dialog title should be present',
      );

      // Find Server URL by Key — the dialog has two TextFormFields
      // (TextFieldAutotrim wraps one for the API Key field), and
      // tree-order finders have flaked between mock and real-backend runs.
      await tester.enterText(
        find.byKey(const Key('testServerUrlField')),
        backend.baseUrl,
      );
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Connect & Fetch Models'),
      );
      // Connect issues a network call. For mock it's near-instant; for
      // real KoboldCpp it can take a moment. Pump generously.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(
        find.textContaining('Connected. Found'),
        findsOneWidget,
        reason: 'server should respond with at least one model',
      );

      // Save — kicks off the in-dialog pop, then the parent's
      // _completeAdd refresh which shows an "Adding provider…" overlay.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));

      // Poll for the overlay to disappear. pumpAndSettle alone may not
      // detect disappearance reliably while async work is in flight.
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (!tester.any(find.text('Adding provider…'))) break;
      }
      await tester.pumpAndSettle();

      // Verify the new provider landed in the list. The TileProviderProfile
      // renders the provider's label as a Text widget.
      expect(
        find.text('Custom (OpenAI-compatible)'),
        findsWidgets,
        reason: 'new local provider should appear in the AI Settings list',
      );

      // Sanity: settings should now have exactly one provider, and it
      // should be localOpenAi with the baseUrl we entered.
      final settings = SettingsService().settings;
      expect(settings.providerConfigs, hasLength(1));
      expect(
        settings.providerConfigs.first.providerEnum,
        LLMProviderEnum.localOpenAi,
      );
      expect(
        settings.providerConfigs.first.baseUrl,
        backend.baseUrl,
        reason: 'baseUrl entered in the dialog should round-trip into settings',
      );

      // For the mock backend, prove the app actually hit it (rather than
      // passing because the server fetch silently no-op'd). Real-server
      // mode skips this — we only own the mock.
      final mock = backend.mock;
      if (mock != null) {
        expect(
          mock.requestCount,
          greaterThan(0),
          reason: 'mock should have received at least one /models request',
        );
      }
    },
  );
}
