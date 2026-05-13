import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Video generation smoke. Gated by `--dart-define=RUN_VIDEO=true` because
/// video calls are ~$0.10-0.50 each; off-by-default keeps default runs
/// cheap. Uses the magic wand → "Generate video" → Free prompt path,
/// then polls the chat controller's messages until any swipe gains a
/// `videoPath` — the service drops the job from its registry the moment
/// download completes (see `video_generation_service.dart:337`), so the
/// only durable signal is the message attachment itself. Same pattern as
/// the image test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Video generation smoke — free prompt',
    timeout: const Timeout(Duration(minutes: 8)),
    (tester) async {
      if (!runVideo) {
        markTestSkipped(
          'Video test skipped. Opt-in via --dart-define=RUN_VIDEO=true.',
        );
        return;
      }
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.byKey(const Key('chat-media-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-menu-video')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('media-video-mode-free')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'a spinning red apple',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      final confirmFinder =
          find.byKey(const Key('media-generate-confirm')).evaluate().isNotEmpty
          ? find.byKey(const Key('media-generate-confirm'))
          : find.text('OK');
      expect(confirmFinder, findsOneWidget);
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();

      // Wait for an mp4 path to land on any message swipe. The service
      // removes the job from its registry the instant download completes
      // (video_generation_service.dart:337), so the durable success signal
      // is the swipe's videoPath. Pump every 2s; bail out within seconds of
      // download — long pump loops while the inline VideoPlayer is mounted
      // can hang on emulator S/W rendering.
      final chatController = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      var hasVideo = false;
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(seconds: 2));
        hasVideo = chatController.messages.any(
          (m) => m.swipes.any((s) => s.videoPath != null),
        );
        if (hasVideo) break;
      }
      expect(
        hasVideo,
        isTrue,
        reason: 'No videoPath attached to any message within 5 minutes',
      );
    },
  );
}
