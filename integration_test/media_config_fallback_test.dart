import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Stale-preset fallback. Setup: seed Grok + NanoGPT in the recovery
/// file (Grok first so it claims the image-domain app default). Open
/// Cass chat, drawer-pick a NanoGPT image preset (writes a session-layer
/// override different from the app default), send a short message so the
/// session JSON flushes to disk with the override present. Pop back to
/// grid, delete the NanoGPT provider via AI Settings, re-enter the
/// chat. The new ChatController's on-construction validator should null
/// the stale image preset id silently. The wand → free-prompt image
/// flow then succeeds against the Grok app-layer default — proving the
/// resolver fell through one layer instead of erroring on the dangling
/// id.
///
/// Asserts: in-memory session has imagePresetId == null after re-entry,
/// the validator's debug-log line is present for THIS session id, and
/// an image attachment lands on the chat thread.
///
/// Cost: 1 chat + 1 image. Grok-priced (cheapest defaults in each
/// domain).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'stale-preset fallback — NanoGPT delete → Grok app default takes over',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }
      if (!hasNanogptKey) {
        markTestSkipped('NANOGPT_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokAndNanogptRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Recovery rebuild fetches model lists for both providers and
      // assigns app-layer defaults from the first provider that serves
      // each domain — Grok wins because it's listed first in
      // `seedGrokAndNanogptRecovery`.
      final settings = tester
          .element(find.byType(MaterialApp))
          .read<SettingsService>()
          .settings;
      expect(
        settings.providerConfigs.length,
        2,
        reason: 'recovery rebuild should produce both Grok and NanoGPT',
      );
      final nanogpt = settings.providerConfigs.firstWhere(
        (p) => p.providerEnum == LLMProviderEnum.nanogpt,
      );
      final grok = settings.providerConfigs.firstWhere(
        (p) => p.providerEnum == LLMProviderEnum.grok,
      );

      final settingsService = tester
          .element(find.byType(MaterialApp))
          .read<SettingsService>();
      final pureHelpers = tester
          .element(find.byType(MaterialApp))
          .read<LlmPureHelpers>();
      final mgmt = tester
          .element(find.byType(MaterialApp))
          .read<LlmManagementService>();

      // Force app-layer defaults to Grok across every domain Grok
      // serves BEFORE any chat session is created. Recovery rebuild
      // fetches providers in parallel, so seeding order in the
      // recovery file does NOT decide which provider claims app
      // defaults — observed in practice: NanoGPT often finishes first
      // and claims chat / assistant / system / image / video / TTS.
      // The test is about image-domain fallback; if any other domain
      // is set to a NanoGPT preset, deleting NanoGPT later orphans
      // the chat's modelPresetId and surfaces an "Active AI connection
      // is invalid" banner that occludes the wand. Pinning Grok up
      // front isolates the change to the image axis.
      mgmt.resetDomainsToProviderDefaults(
        settings: settings,
        profile: grok,
      );
      await settingsService.saveSettings();
      await tester.pumpAndSettle();

      // Need the NanoGPT image preset id we'll force onto the session.
      // Computed against [nanogpt] only so we don't accidentally pick
      // the Grok preset.
      final nanogptImagePresets = pureHelpers.getValidPresetsForDomain(
        LlmProviderDomainEnum.image,
        [nanogpt],
      );
      expect(
        nanogptImagePresets,
        isNotEmpty,
        reason: 'NanoGPT default models must include an image preset',
      );
      final nanogptImagePresetId = nanogptImagePresets.first.config.id;

      // Enter Cass chat.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final chatContext = tester.element(find.byType(ChatView));
      final controller = chatContext.read<BaseChatViewController>();
      final originalSession = controller.chatSession;
      expect(originalSession, isNotNull);
      final sessionId = originalSession!.id;

      // Open the end-drawer.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      // Image is the bottom-most ExpansionTile in the drawer (order:
      // Chat → Chat Theme → Speech → Video → Image), below the fold on
      // a phone viewport.
      final imageHeader = find.text('Image');
      await tester.dragUntilVisible(
        imageHeader,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(imageHeader);
      await tester.pumpAndSettle();

      // After expanding 'Image', the 'Image Model' tile sits further
      // down the drawer and is itself off-screen on a phone viewport —
      // scroll again so the tap actually hits it.
      final imageModelTile = find.text('Image Model');
      await tester.dragUntilVisible(
        imageModelTile,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      // 'Image Model' tile pops the drawer synchronously before opening
      // the picker (tile_image_preset.dart line 64) — no manual close
      // needed afterwards.
      await tester.tap(imageModelTile);
      await tester.pumpAndSettle();

      // Picker open. Pick the NanoGPT row. Each row renders the
      // provider enum name uppercased ('NANOGPT'); tap the ListTile
      // ancestor of that text so the row's onTap fires.
      final nanogptRow = find.ancestor(
        of: find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('NANOGPT'),
        ),
        matching: find.byType(ListTile),
      );
      expect(
        nanogptRow,
        findsOneWidget,
        reason: 'picker should offer exactly one NanoGPT image preset',
      );
      await tester.tap(nanogptRow);
      await tester.pumpAndSettle();

      // Sanity: session got the NanoGPT id as the override.
      expect(originalSession.configMedia, isNotNull);
      expect(
        originalSession.configMedia!.imagePresetId,
        nanogptImagePresetId,
        reason: 'session override should be the picked NanoGPT preset id',
      );

      // Send a short message so session JSON flushes with the NanoGPT
      // id present. Without this, the in-memory ChatSession's override
      // may evaporate on dispose without ever hitting disk and the
      // on-re-entry validator would have nothing to clean.
      await tester.enterText(find.byKey(const Key('chat-input')).first, 'hi');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));
      // Settle window for the post-turn save before the controller
      // disposes.
      await tester.pump(const Duration(seconds: 1));

      // Pop chat back to grid (Android system-back equivalent —
      // pattern from character_create_test.dart). Forces
      // ChatController.dispose so re-entry constructs a fresh one and
      // the validator runs on a fresh `providers` snapshot.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Delete NanoGPT via the same API the UI gear-menu → AI Providers
      // → Edit → Delete → Confirm flow calls. Bypassing the UI here
      // sidesteps `DialogProviderConfig._isLocked`, which hides the
      // Delete button when the provider holds any active app-layer
      // default. Recovery rebuild runs the two model fetches in
      // parallel and assigns app defaults from whichever finishes
      // first, so list order in the recovery file is NOT a stable
      // selector — NanoGPT may have ended up holding several app
      // defaults despite Grok being listed first. The validator-on-
      // entry path is what's under test; the UI plumbing for delete is
      // covered by the AI Settings flow elsewhere.
      mgmt.deleteProvider(
        settings: settings,
        providerId: nanogpt.id,
      );
      await settingsService.saveSettings();
      await tester.pumpAndSettle();

      expect(
        settings.providerConfigs.any(
          (p) => p.providerEnum == LLMProviderEnum.nanogpt,
        ),
        isFalse,
        reason: 'NanoGPT should be removed from settings after deleteProvider',
      );

      // Snapshot the log size so we can assert ONLY new validator
      // lines emitted during the upcoming re-entry.
      final logsBefore = LoggingService().logsNotifier.value.length;

      // Re-enter Cass chat. New ChatController constructs →
      // validateConfigMediaSession + validateConfigMediaCharacter run
      // → stale NanoGPT id is nulled in memory.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Re-read controller / session — the new ChatController may hold
      // a different ChatSession instance than `originalSession`.
      final freshController = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final freshSession = freshController.chatSession;
      expect(freshSession, isNotNull);
      expect(
        freshSession!.id,
        sessionId,
        reason: 'getLatestChat should reload the same session by id',
      );

      expect(freshSession.configMedia, isNotNull);
      expect(
        freshSession.configMedia!.imagePresetId,
        isNull,
        reason: 'on-entry validator should null the deleted NanoGPT preset',
      );

      final newLogs = LoggingService().logsNotifier.value.skip(logsBefore);
      final hadValidatorLine = newLogs.any(
        (entry) =>
            entry.message.startsWith('media-validator: nulled image preset') &&
            entry.message.contains('on session $sessionId'),
      );
      expect(
        hadValidatorLine,
        isTrue,
        reason: 'validator should log the nulled image preset on re-entry',
      );

      // Wand → Generate image → Free prompt. Same shape as
      // image_generation_test.dart. Image generation reaching done is
      // the smoke proof that resolveMedia fell back to the Grok
      // app-layer default instead of erroring on the now-null session
      // id.
      await tester.tap(find.byKey(const Key('chat-media-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-menu-image')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-image-mode-free')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'a red apple');
      await tester.pump();
      await dismissKeyboard(tester);
      final confirm =
          find.byKey(const Key('media-generate-confirm')).evaluate().isNotEmpty
          ? find.byKey(const Key('media-generate-confirm'))
          : find.text('OK');
      expect(
        confirm,
        findsOneWidget,
        reason: 'free-prompt dialog should have a confirm button',
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      await _awaitImageAttached(tester, timeout: const Duration(seconds: 90));
    },
  );
}

Future<void> _awaitImageAttached(
  WidgetTester tester, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    final controller = tester
        .element(find.byType(ChatView))
        .read<BaseChatViewController>();
    final hasImage = controller.messages.any(
      (m) => m.swipes.any((s) => s.attachedImages.isNotEmpty),
    );
    if (hasImage) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('No image attached to any message within ${timeout.inSeconds}s');
}
