import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';
import 'helpers/local_llm_test_backend.dart';

/// End-to-end: add a Local OpenAI-compatible provider, create a preset
/// for its model (which auto-assigns to chat domain via
/// TileProviderProfile._openPresetEditor's putIfAbsent loop), enter a
/// chat with Cass, send a message, verify the reply lands.
///
/// Backend selectable via LOCAL_LLM_BASE_URL — defaults to in-process
/// mock server. The mock streams a canned 'hello world' reply in OpenAI
/// SSE format.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'local provider — chat round-trip',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      if (kIsWeb) {
        markTestSkipped(
          'Android-only: uses HttpServer.bind for mock LLM server',
        );
        return;
      }
      final backend = LocalLlmTestBackend(enableChat: true);
      await backend.setUp();
      addTearDown(backend.tearDown);

      await wipeAppData();
      await seedOnboardingComplete();
      // Seed Test Character (lighter personality than Cass) so the chat
      // prompt is small enough that real local backends finish generating
      // within the test timeout. Cass's card alone balloons the prompt to
      // ~3300 tokens; Test Character's is closer to ~100.
      await seedTestCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // ─────────────────────────────────────────────────────────────
      // STEP 1: add the local provider via Settings
      // ─────────────────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-ai-providers')));
      await tester.pumpAndSettle();

      // The three add-provider variants now live behind one
      // FilledButton + MenuAnchor dropdown; open the menu first, then
      // pick "Local Provider".
      await tester.tap(find.widgetWithText(FilledButton, 'New Provider'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Local Provider'));
      await tester.pumpAndSettle();

      expect(
        find.text('Add Local Provider'),
        findsOneWidget,
        reason: 'local provider dialog should be open',
      );

      // Find Server URL by Key — type-based finders flake here because
      // the API Key field's TextFieldAutotrim wraps a TextFormField too.
      await tester.enterText(
        find.byKey(const Key('testServerUrlField')),
        backend.baseUrl,
      );
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Connect & Fetch Models'),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Connected. Found'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      // Poll for the "Adding provider…" overlay to disappear, then settle
      // any in-flight animations (the inner dialog's dismiss animation may
      // still be running when the overlay text vanishes — pumpAndSettle
      // ensures the route stack is fully quiescent).
      final addDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(addDeadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (!tester.any(find.text('Adding provider…'))) {
          await tester.pumpAndSettle();
          break;
        }
      }

      // ─────────────────────────────────────────────────────────────
      // STEP 2: create a preset for the model. The "Add Model"
      // TextButton sits in the provider's TileProviderProfile section
      // header band (Set default / Add Model / overflow). Only one
      // provider was added so the `.first` scope is unambiguous; the
      // post-tap assertion verifies the dialog by its form-field label
      // ('Model name') since the button text 'Add Model' is still on
      // screen behind the dialog scrim.
      // ─────────────────────────────────────────────────────────────
      final addPresetButton = find
          .widgetWithText(TextButton, 'Add Model')
          .first;
      await tester.ensureVisible(addPresetButton);
      await tester.pumpAndSettle();
      await tester.tap(addPresetButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Model name'),
        findsOneWidget,
        reason: 'preset dialog should be open (form field label visible)',
      );

      // Name field — labelText is "Preset Name" (not just "Name").
      // The preset dialog has several TextFieldAutotrim instances; scope
      // by the unique label.
      final nameField = find.ancestor(
        of: find.text('Model name'),
        matching: find.byType(TextFieldAutotrim),
      );
      await tester.enterText(nameField.first, 'Local Chat Preset');
      await tester.pump();
      await dismissKeyboard(tester);

      // Tap Model field to open DialogModelSelection.
      final modelField = find.ancestor(
        of: find.text('Model'),
        matching: find.byType(TextFieldAutotrim),
      );
      await tester.tap(modelField.first);
      await tester.pumpAndSettle();

      expect(
        find.byType(DialogModelSelection),
        findsOneWidget,
        reason: 'tapping the Model field should open the model picker',
      );

      // Tap the only model TileModel — mock-llama-3.1-8b (or whatever the
      // real backend has loaded).
      await tester.tap(find.byType(TileModel).first);
      await tester.pumpAndSettle();

      // Save the preset.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // ─────────────────────────────────────────────────────────────
      // STEP 3: close the AI Settings dialog and return to the grid.
      // DialogAiSettings is now a fullscreenDialog MaterialPageRoute
      // (Scaffold with a plain CloseButton, no AppDialog.dismissKey),
      // so pop via Android-back instead of tapping a keyed button.
      // ─────────────────────────────────────────────────────────────
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // ─────────────────────────────────────────────────────────────
      // STEP 4: enter Test Character's chat and send a message. Pick the
      // non-Cass card via CharacterService — Cass's heavy personality
      // would blow the prompt past what a 13B GGUF can chew through in
      // a reasonable time on consumer hardware.
      // ─────────────────────────────────────────────────────────────
      final cs = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = cs.characterFiles.firstWhere(
        (f) => f.card.displayName != kCassName,
        orElse: () =>
            throw StateError('seedTestCharacter should have placed a 2nd card'),
      );
      await tester.tap(findCharacterTile(testCharFile.card.displayName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      final input = find.byType(TextField).last;
      await tester.enterText(input, 'Hello local model.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Real local servers (KoboldCpp + 13B model on consumer GPU) can
      // take minutes to generate even a short reply; the mock returns
      // its canned SSE near-instantly. Branch the timeout accordingly.
      await awaitChatIdle(
        tester,
        timeout: Duration(seconds: backend.isReal ? 300 : 60),
      );

      // ─────────────────────────────────────────────────────────────
      // ASSERT: reply landed.
      // ─────────────────────────────────────────────────────────────
      expect(
        controller.messages.last.content,
        isNotEmpty,
        reason: 'AI reply should have content',
      );

      // Mock-only: prove the chat completion endpoint was actually hit
      // (not just /v1/models). The mock counts /models + /chat/completions
      // requests; /chat/completions adds at least one.
      final mock = backend.mock;
      if (mock != null) {
        expect(
          mock.requestCount,
          greaterThanOrEqualTo(2),
          reason: 'mock should have received both models + chat requests',
        );
      }
    },
  );
}
