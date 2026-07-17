import 'package:cardwave/chat/chat.dart';
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

/// Change the active TTS voice via the end-drawer's Voice tile. Tile
/// (tile_tts_voice.dart) reads the currently effective voice through
/// the layered resolver (session → character → app default), shows a
/// SelectionDialog, and on pick writes the new voiceId through the
/// session-layer paired setter.
///
/// Asserts both the picker plumbing AND the consequence: picking an
/// inactive voice flips the resolved voice id, then the play button on
/// the greeting bubble actually synthesizes audio with that voice
/// (TextToSpeechController transitions through synth → playing).
///
/// One TTS call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — change TTS voice via drawer Voice tile',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedTestCharacter();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      await tester.tap(findCharacterTile(kSeedCharacterName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final chatContext = tester.element(find.byType(ChatView));
      final controller = chatContext.read<BaseChatViewController>();
      final settings = chatContext.read<SettingsService>().settings;
      final tts = chatContext.read<TextToSpeechController>();
      final session = controller.chatSession;
      expect(session, isNotNull, reason: 'chat should have an active session');

      // Resolve the currently effective voice — could come from
      // session.tts, character TTS layer, or app default. After picking a
      // different voice in the drawer, session.tts.voiceId must change to
      // a different id.
      final resolvedBefore = resolveMedia(
        settings: settings,
        pureHelpers: chatContext.read<LlmPureHelpers>(),
        session: session,
        character: controller.resolveCharacterFile(controller.messages.last),
      );
      expect(
        resolvedBefore.ttsPreset,
        isNotNull,
        reason: 'Grok TTS resolves a default voice on a fresh chat',
      );
      final originalVoiceId = resolvedBefore.ttsVoiceId!;

      // Open end-drawer via the appbar menu icon (app_bar_chat.dart:62).
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      // Speech section is now a flat DrawerSectionHeader (not an
      // ExpansionTile) — Voice/Preset tiles are always visible, no expand
      // step needed. Drag in case the section sits below the fold.
      final voiceTile = find.text('Voice');
      await tester.dragUntilVisible(
        voiceTile,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(voiceTile);
      await tester.pumpAndSettle();

      // SelectionDialog now open. Tap any radio_button_unchecked option
      // (i.e. any voice that isn't the active one). Scope the finder to
      // the dialog so we don't accidentally match other unchecked-radio
      // icons elsewhere in the tree.
      final dialogUnchecked = find.descendant(
        of: find.byType(AppDialog),
        matching: find.byIcon(Icons.radio_button_unchecked),
      );
      expect(
        dialogUnchecked,
        findsWidgets,
        reason: 'voice picker must offer at least one alternate voice',
      );
      await tester.tap(dialogUnchecked.first);
      await tester.pumpAndSettle();

      expect(
        session!.configMedia,
        isNotNull,
        reason: 'pick must assign session.configMedia',
      );
      expect(
        session.configMedia!.ttsVoiceId,
        isNot(originalVoiceId),
        reason: 'picked voice id should differ from the original',
      );
      final newVoiceId = session.configMedia!.ttsVoiceId;

      // The dialog auto-popped on tap; close the drawer behind it so the
      // greeting bubble's play button is reachable. handlePopRoute is the
      // Android system-back equivalent (see chat_group_test).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Play the greeting via the bubble's TTS button. message_actions_row
      // renders Icons.play_arrow when the message isn't currently playing.
      final playButtons = find.byKey(const Key('msg-tts-play'));
      expect(
        playButtons,
        findsAtLeastNWidgets(1),
        reason: 'greeting bubble should surface a play button',
      );
      await tester.tap(playButtons.first);
      await tester.pump();

      // Same wait pattern as tts_test: poll for the playing state, which
      // proves the synth request returned, the mp3 was written, and audio
      // playback started — using the new voice id.
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      var reachedPlaying = false;
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
        if (!tts.isLoading && tts.playingMessage != null) {
          reachedPlaying = true;
          break;
        }
      }
      expect(
        reachedPlaying,
        isTrue,
        reason: 'TTS should reach playing with the newly picked voice',
      );

      // Sanity: session still carries the picked voice id at playback time.
      expect(
        session.configMedia?.ttsVoiceId,
        newVoiceId,
        reason: 'session should still hold the picked voice during playback',
      );

      // Brief audible window so a human running the test can hear the
      // alternate voice, then stop to keep teardown quick.
      await tester.pump(const Duration(seconds: 2));
      await tts.stop();
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    },
  );
}
