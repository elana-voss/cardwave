import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// REAL end-to-end lifecycle of a hand-entered custom-provider model, driven
/// through the Settings GUI and answered by a live model. It points the custom
/// ("Your own server, OpenAI-compatible") provider at xAI's Grok endpoint —
/// which speaks the same OpenAI chat shape a self-hosted server would — using a
/// real API key, so the chat message gets a genuine reply over the network, not
/// a canned stub.
///
/// One run covers:
///   1. add a custom provider (server URL + API key) and enter a model BY HAND
///      — no fetch — then confirm every typed value reached disk,
///   2. edit that model's name and context size and confirm the edit persisted,
///   3. add a second model by hand, confirm it persisted, then delete it with
///      the per-model trash control and confirm it is gone from disk,
///   4. send a chat message and confirm a real reply lands — proving the
///      hand-entered, then edited, model works end to end against a live server.
///
/// The message step runs LAST on purpose: it proves the model still chats after
/// being edited, and keeps all the Settings work in one screen session.
///
/// Requires the key: `--dart-define=GROK_API_KEY=xai-...`. Skips (does not fail)
/// when the key is absent, so a keyless CI run stays green.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const grokKey = String.fromEnvironment('GROK_API_KEY');
  const grokBaseUrl = 'https://api.x.ai/v1';
  const modelId = 'grok-4.3';
  const modelName = 'My Grok Model';
  const modelNameEdited = 'My Grok Model v2';
  const scratchId = 'scratch-model';
  const scratchName = 'Scratch Model';
  const initialContext = 8192;
  const editedContext = 16384;
  const initialMaxTokens = 2048;

  testWidgets(
    'custom provider — hand-entered model add / edit / delete + live chat',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      if (kIsWeb) {
        markTestSkipped('Android-only integration test');
        return;
      }
      if (grokKey.isEmpty) {
        markTestSkipped(
          'No GROK_API_KEY — pass --dart-define=GROK_API_KEY=xai-... to run '
          'the live end-to-end path.',
        );
        return;
      }

      await wipeAppData();
      await seedOnboardingComplete();
      await seedTestCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // The model editor's text fields, in build order: 0 = Model ID,
      // 1 = Display name, 2 = Context size, 3 = Max response length (sampling
      // fields follow but this test only touches these four).
      const modelIdField = 0;
      const modelNameField = 1;
      const contextField = 2;
      const maxTokensField = 3;

      // Enters a value into the model editor by field index, scoped to the
      // top-most dialog so the provider dialog's own fields behind it are never
      // matched. Addressing by index (not by label) is deterministic whether
      // the field is empty or pre-filled — a label-ancestor lookup mis-targets
      // once the edit form arrives pre-populated. Tap first to focus: enterText
      // into a just-opened, unfocused field can otherwise be dropped.
      Future<void> enterModelField(int index, String value) async {
        final fields = find.descendant(
          of: find.byType(AppDialog).last,
          matching: find.byType(EditableText),
        );
        await tester.tap(fields.at(index));
        await tester.pump();
        await tester.enterText(fields.at(index), value);
        await tester.pump();
      }

      // Saves the model editor (dialog-from-dialog), scoping to the top-most
      // dialog so its Save is hit, not the provider dialog's behind it.
      Future<void> saveModelEditor() async {
        await dismissKeyboard(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(AppDialog).last,
            matching: find.widgetWithText(FilledButton, 'Save'),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Opens the provider's Edit dialog from its section-header overflow menu.
      Future<void> openEditProviderDialog() async {
        await tester.ensureVisible(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, 'Edit provider'));
        await tester.pumpAndSettle();
        expect(
          find.text('Edit Custom Provider'),
          findsOneWidget,
          reason: 'the custom-provider edit dialog should open',
        );
      }

      // Saves the provider Edit dialog and waits for it to close. The edit
      // path shows no overlay (unlike add), so poll on the title vanishing.
      Future<void> saveEditProviderDialog() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (!tester.any(find.text('Edit Custom Provider'))) break;
        }
        await tester.pumpAndSettle();
      }

      LlmProviderConfig currentProvider() =>
          SettingsService().settings.providerConfigs.first;

      // A model row INSIDE the open provider dialog. Scoped to the dialog
      // because the AI-settings screen behind it renders its own ListTile per
      // model (the preset inventory row), so an unscoped find would match two.
      Finder rosterTile(String name) => find.descendant(
        of: find.byType(AppDialog),
        matching: find.widgetWithText(ListTile, name),
      );

      // Pumps until the named roster tile is present. The model editor closes
      // through an async `showDialog` future, so the provider roster rebuilds
      // one microtask after the editor pops — a plain `pumpAndSettle` in
      // `saveModelEditor` occasionally returns just before that rebuild paints,
      // leaving the tile momentarily absent. Poll a few frames so the caller's
      // assertion sees the settled roster instead of racing it.
      Future<void> awaitRosterTile(String name) async {
        for (var i = 0; i < 20; i++) {
          if (tester.any(rosterTile(name))) return;
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // ─────────────────────────────────────────────────────────────
      // STEP 1: add a custom provider (server URL + real API key) and enter
      // one model BY HAND — no Connect, no fetch.
      // ─────────────────────────────────────────────────────────────
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-ai-providers')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'New Provider'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          MenuItemButton,
          'Your own server (OpenAI-compatible)',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Provider'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('testServerUrlField')),
        grokBaseUrl,
      );
      await tester.pump();
      // Only one TextFieldAutotrim exists in the provider dialog (the Server
      // URL uses a plain TextFormField), so this resolves the API Key field.
      await tester.enterText(find.byType(TextFieldAutotrim), grokKey);
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Add model by hand'));
      await tester.pumpAndSettle();
      expect(find.text('Add Model'), findsOneWidget);

      await enterModelField(modelIdField, modelId);
      await enterModelField(modelNameField, modelName);
      await enterModelField(contextField, '$initialContext');
      await enterModelField(maxTokensField, '$initialMaxTokens');
      await saveModelEditor();

      await awaitRosterTile(modelName);
      expect(
        rosterTile(modelName),
        findsOneWidget,
        reason: 'the hand-entered model should appear in the roster',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      final addDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(addDeadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (!tester.any(find.text('Adding provider…'))) break;
      }
      await tester.pumpAndSettle();

      // Assert the hand-entered values reached disk verbatim, and that adding
      // the provider auto-seeded a default chat preset (what makes the model
      // immediately usable in STEP 4).
      final afterAdd = SettingsService().settings.providerConfigs;
      expect(afterAdd, hasLength(1));
      expect(afterAdd.first.providerEnum, LLMProviderEnum.localOpenAi);
      expect(afterAdd.first.baseUrl, grokBaseUrl);
      expect(afterAdd.first.apiKey, grokKey);
      expect(afterAdd.first.models, hasLength(1));
      final added = afterAdd.first.models.first;
      expect(added.id, modelId);
      expect(added.name, modelName);
      expect(added.contextLength, initialContext);
      expect(added.maxOutputTokens, initialMaxTokens);
      expect(
        added.presets,
        isNotEmpty,
        reason: 'add should seed a default chat preset onto the model',
      );

      // ─────────────────────────────────────────────────────────────
      // STEP 2: edit the model — change display name and context size —
      // and confirm the edit survives to disk.
      // ─────────────────────────────────────────────────────────────
      await openEditProviderDialog();
      await tester.tap(rosterTile(modelName));
      await tester.pumpAndSettle();
      expect(find.text('Edit Model'), findsOneWidget);

      await enterModelField(modelNameField, modelNameEdited);
      await enterModelField(contextField, '$editedContext');
      await saveModelEditor();

      await awaitRosterTile(modelNameEdited);
      expect(
        rosterTile(modelNameEdited),
        findsOneWidget,
        reason: 'the roster tile should reflect the new name',
      );
      await saveEditProviderDialog();

      final edited = currentProvider().models.firstWhere(
        (m) => m.id == modelId,
      );
      expect(edited.name, modelNameEdited);
      expect(edited.contextLength, editedContext);
      expect(
        edited.presets,
        isNotEmpty,
        reason: 'editing a model must preserve its seeded chat preset',
      );

      // ─────────────────────────────────────────────────────────────
      // STEP 3: add a SECOND model by hand and confirm it persists. (The
      // first model backs the active chat domain, so its own delete control
      // is hidden — deletion is tested on this un-assigned scratch model.)
      // ─────────────────────────────────────────────────────────────
      await openEditProviderDialog();
      await tester.tap(find.widgetWithText(TextButton, 'Add model by hand'));
      await tester.pumpAndSettle();
      await enterModelField(modelIdField, scratchId);
      await enterModelField(modelNameField, scratchName);
      await saveModelEditor();

      await awaitRosterTile(scratchName);
      expect(rosterTile(scratchName), findsOneWidget);
      expect(rosterTile(modelNameEdited), findsOneWidget);
      await saveEditProviderDialog();

      final afterScratch = currentProvider().models;
      expect(afterScratch, hasLength(2));
      expect(afterScratch.any((m) => m.id == scratchId), isTrue);

      // ─────────────────────────────────────────────────────────────
      // STEP 4: delete the scratch model with the per-model trash control
      // and confirm it is gone from the roster AND from disk.
      // ─────────────────────────────────────────────────────────────
      await openEditProviderDialog();
      expect(rosterTile(scratchName), findsOneWidget);
      // Only the scratch model shows a delete control — the chat-backing model
      // hides its own while its preset is domain-assigned.
      final deleteControl = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byIcon(Icons.delete_outline),
      );
      expect(deleteControl, findsOneWidget);
      await tester.tap(deleteControl);
      await tester.pumpAndSettle();

      expect(
        rosterTile(scratchName),
        findsNothing,
        reason: 'deleting removes the model from the roster',
      );
      expect(rosterTile(modelNameEdited), findsOneWidget);
      await saveEditProviderDialog();

      final afterDelete = currentProvider().models;
      expect(afterDelete, hasLength(1));
      expect(afterDelete.any((m) => m.id == scratchId), isFalse);
      expect(afterDelete.first.id, modelId);

      // ─────────────────────────────────────────────────────────────
      // STEP 5: send a message and confirm a real reply lands — the edited,
      // hand-entered model answers over the live Grok endpoint.
      // ─────────────────────────────────────────────────────────────
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final cs = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final testCharFile = (await cs.loadByName(kSeedCharacterName))!;
      await tester.tap(findCharacterTile(testCharFile.card.displayName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      final input = find.byType(TextField).last;
      await tester.enterText(input, 'Hello there — say hi back in one line.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Live network call to xAI: allow generously for connect + generation.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 120));

      expect(
        controller.messages.last.content,
        isNotEmpty,
        reason: 'the live Grok reply should have content',
      );
    },
  );
}
