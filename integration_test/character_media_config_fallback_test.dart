import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Character-level stale-preset fallback. Companion to
/// `media_config_fallback_test.dart` (which covers the session-level
/// path). Drives the validator's OTHER call site —
/// `validateConfigMediaCharacter` running in `EditorPageController`'s
/// constructor.
///
/// Flow: seed Grok + NanoGPT → force Grok app defaults → set Cass's
/// `configMedia.imagePresetId` to a NanoGPT preset and flush to disk
/// (imperatively — the editor's media UI now lives in
/// `MediaSettingsGridPage`; this test is about the validator, not the
/// UI prelude) → delete NanoGPT via API → force fresh disk reload →
/// open editor → `EditorPageController` constructor runs validator →
/// stale id nulled.
///
/// Asserts the in-memory state AND the validator's debug-log line
/// (matched against `appCardId`, since that's what the validator
/// embeds in the character-side log message). The disk reload is
/// load-bearing — without it the test would pass even if the prior
/// flush silently failed.
///
/// Cost: $0 — no chat, no image, no TTS, no video. Just model-list
/// fetches during recovery rebuild.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'character-level stale-preset fallback — editor entry validates configMedia',
    timeout: const Timeout(Duration(minutes: 3)),
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
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();

      // Pin Grok across every domain Grok serves before any character
      // file is mutated. Recovery rebuild is parallel, so seeding order
      // does not decide who claims app defaults — see the session
      // test's notes on this.
      mgmt.resetDomainsToProviderDefaults(
        settings: settings,
        profile: grok,
      );
      await settingsService.saveSettings();
      await tester.pumpAndSettle();

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

      // Look up Cass via CharacterService so we can mutate her on-disk
      // state without touching the editor UI. The validator path under
      // test runs when the editor opens — it doesn't care which UI
      // wrote the state.
      final cassFile = characterService.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      final appCardId = cassFile.appCardId;

      // Imperatively pin Cass's image preset to NanoGPT and flush so
      // the next disk reload picks it up.
      final nanogptResolved = pureHelpers.resolvePresetOrNull(
        configId: nanogptImagePresetId,
        providers: [nanogpt],
      );
      expect(
        nanogptResolved,
        isNotNull,
        reason: 'picked NanoGPT image preset must resolve against NanoGPT',
      );
      cassFile.configMedia ??= ConfigMediaCharacter();
      cassFile.configMedia!.setImagePreset(
        nanogptImagePresetId,
        firstImageAspectRatioId(nanogptResolved!.model),
      );
      // Direct field mutation doesn't bump the dirty timestamp, so
      // `flushJsonInCacheAndPngIfDirtyOrPending` would no-op. Use the
      // unconditional save so the change actually reaches disk before
      // the loadCharacters() reload below.
      await characterService.saveJsonInCacheAndPngNow(cassFile);
      expect(
        cassFile.configMedia!.imagePresetId,
        nanogptImagePresetId,
        reason: 'character override should be the imperatively-set id',
      );

      // Delete NanoGPT via API.
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

      // Force fresh disk reload so the next editor open works against a
      // CharacterFile whose state can ONLY have come from disk. Without
      // this, a silently-failed PopScope flush would still let the test
      // pass on stale in-memory state.
      await characterService.loadCharacters();
      await tester.pumpAndSettle();

      // Snapshot the log size so we only inspect lines emitted during
      // the upcoming editor reopen.
      final logsBefore = LoggingService().logsNotifier.value.length;

      // Reopen editor. New EditorPageController builds against the
      // fresh CharacterFile → validateConfigMediaCharacter fires →
      // stale NanoGPT id nulled in memory.
      await tapEditOnCharacterTile(tester, kCassName);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final freshCass = characterService.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      expect(
        freshCass.appCardId,
        appCardId,
        reason: 'loadCharacters should re-read the same Cass by appCardId',
      );

      expect(freshCass.configMedia, isNotNull);
      expect(
        freshCass.configMedia!.imagePresetId,
        isNull,
        reason:
            'on-entry validator should null the deleted NanoGPT preset on '
            'character.configMedia',
      );

      final newLogs = LoggingService().logsNotifier.value.skip(logsBefore);
      final hadValidatorLine = newLogs.any(
        (entry) =>
            entry.message.startsWith('media-validator: nulled image preset') &&
            entry.message.contains('on character $appCardId'),
      );
      expect(
        hadValidatorLine,
        isTrue,
        reason:
            'validator should log the nulled image preset on editor '
            're-entry',
      );
    },
  );
}
