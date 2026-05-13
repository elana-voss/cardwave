import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// send_video round-trip on the manual tool loop.
///
/// Sister test to `send_selfie_tool_test.dart` — same side-effect-only
/// shape (tool returns `ToolResult.ok()` with no data so the loop
/// terminates after one round), but the video flow always creates a
/// fresh placeholder message (see `chat_video_generation_mixin.dart`)
/// rather than attaching to the assistant's bubble. So the assertion
/// shape differs:
///   - the assistant text reply (one of the last messages) carries the
///     `send_video` tool-call record on its active swipe;
///   - a separate "*(sent a video: …)*" message follows it with
///     `swipes[0].videoPath != null`.
///
/// Gated by `--dart-define=RUN_VIDEO=true` because real Grok video
/// generation is ~$0.10–0.50 per call and 2–10 minutes wall time.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'send_video tool — video attached, loop terminates without second LLM call',
    timeout: const Timeout(Duration(minutes: 10)),
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

      // Enter Cass chat.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Open the end-drawer.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();

      // Video is the third-to-last ExpansionTile (order: Chat → Chat
      // Theme → Speech → Video → Image → Web), below the fold on a
      // phone viewport.
      final videoHeader = find.text('Video');
      await tester.dragUntilVisible(
        videoHeader,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(videoHeader);
      await tester.pumpAndSettle();

      // Toggle "Character Can Send Videos".
      final videoToggle = find.text('Character Can Send Videos');
      await tester.dragUntilVisible(
        videoToggle,
        find.byType(Scrollable).last,
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(videoToggle);
      await tester.pumpAndSettle();

      // Close the drawer (Android system-back) so the chat input is
      // hit-testable again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Sanity: the session reflects the toggle.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final session = controller.chatSession;
      expect(session, isNotNull);
      expect(
        session!.configMedia?.videoToolSendAllowed,
        isTrue,
        reason: 'drawer toggle should set videoToolSendAllowed on session',
      );

      // Naming the tool and asking explicitly drives Grok to emit one
      // send_video call. "Right now" gives the model an obvious
      // emotional beat for the schema's purpose/emotion/motion fields.
      const userPrompt =
          'Please use the send_video tool to share a short clip '
          'showing how you feel right now.';
      await tester.enterText(
        find.byKey(const Key('chat-input')).first,
        userPrompt,
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Video gen runs inside the dispatch loop and can take 2–10 min on
      // Grok. The durable success signal is a videoPath landing on some
      // swipe — see `video_generation_test.dart` for the same pattern.
      // Pump every 2s; bail out once the path appears.
      final deadline = DateTime.now().add(const Duration(minutes: 8));
      var hasVideo = false;
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(seconds: 2));
        hasVideo = controller.messages.any(
          (m) => m.swipes.any((s) => s.videoPath != null),
        );
        if (hasVideo) break;
      }
      // The tool-call record is written to the assistant message by
      // the chat controller a few awaits AFTER `videoPath` lands. Give
      // those post-dispatch writes a chance to settle before the search
      // below — without this, the record search can race the write.
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        hasVideo,
        isTrue,
        reason:
            'send_video should have attached an mp4 to some swipe '
            'within 8 minutes',
      );

      // Tool-call record assertion: send_video's record lands on the
      // assistant text reply's active swipe (the bubble that emitted
      // the call), NOT on the separate video message that follows.
      // Search every message's active swipe for the record.
      ChatToolCallRecord? videoRecord;
      for (final m in controller.messages) {
        if (m.swipes.isEmpty) continue;
        final active = m.swipes[m.swipeIndex];
        for (final r in active.toolCalls) {
          if (r.toolName == SendVideoTool.toolName) {
            videoRecord = r;
            break;
          }
        }
        if (videoRecord != null) break;
      }
      expect(
        videoRecord,
        isNotNull,
        reason:
            'model should have called send_video at least once; '
            'recorded tool calls across all messages: '
            '${controller.messages.expand((m) => m.swipes.expand((s) => s.toolCalls.map((r) => r.toolName))).toList()}',
      );
      expect(
        videoRecord!.success,
        isTrue,
        reason:
            'send_video call should have succeeded; '
            'errorMessage=${videoRecord.errorMessage}',
      );
      expect(
        videoRecord.resultData,
        isNull,
        reason:
            'send_video is side-effect-only — null resultData is '
            'what tells the loop to terminate without a second LLM '
            'call. Non-null here would mean the terminate-on-empty-data '
            'policy regressed.',
      );

      // Hold the final UI state briefly so a watching operator can
      // visually confirm the attached video.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
    },
  );
}
