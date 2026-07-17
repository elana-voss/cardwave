import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// TTS smoke test. Send one short message, wait for reply, tap the play
/// button on the reply bubble, assert TextToSpeechController transitions
/// through loading → playing state. One chat call + one TTS call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TTS smoke — play a reply bubble',
    timeout: const Timeout(Duration(minutes: 2)),
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

      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with three words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      await awaitChatIdle(tester, timeout: const Duration(seconds: 45));

      // The reply bubble has a play_arrow IconButton (TTS trigger). Tap the
      // last one (assistant reply is the newest, bottom of reversed list).
      final playButtons = find.byKey(const Key('msg-tts-play'));
      expect(
        playButtons,
        findsAtLeastNWidgets(1),
        reason: 'reply bubble should surface a play button',
      );
      await tester.tap(playButtons.first);
      await tester.pump();

      // Wait through the synth→playback transition. State machine:
      //   synth:    isLoading=true, playingMessage!=null
      //   playing:  isLoading=false, playingMessage!=null  (audio file is now
      //             on disk and audio_player has started playback)
      //   done/fail: both clear
      // We wait for the playing state — proves the request returned, the mp3
      // was written, and playback actually started. Then call stop() so we
      // don't sit through the full clip during teardown.
      final tts = tester
          .element(find.byType(ChatView))
          .read<TextToSpeechController>();
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
        reason:
            'TTS should reach the playing state '
            '(synth completed, mp3 written, playback started)',
      );

      // Let audio actually play for a few seconds so a human running the test
      // hears it confirm-out-loud rather than truncating immediately. Then
      // stop so we don't sit through the whole clip during teardown.
      await tester.pump(const Duration(seconds: 3));
      await tts.stop();
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    },
  );
}
