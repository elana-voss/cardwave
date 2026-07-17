import 'package:cardwave/chat/chat.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
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

      await bootSeedChat(tester);
      await enableToolViaDrawer(
        tester,
        toggleLabel: 'Character Can Send Videos',
      );

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
      await sendChatPrompt(tester, userPrompt);

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

      // send_video's record lands on the assistant text reply, NOT on
      // the separate video bubble that follows — must scan every
      // message rather than just the last.
      final videoRecord = assertToolFiredOnAnyMessage(
        controller,
        toolName: SendVideoTool.toolName,
      );
      expect(
        videoRecord.success,
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
