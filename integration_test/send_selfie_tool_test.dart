import 'package:cardwave/chat/chat.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// send_selfie round-trip on the manual tool loop.
///
/// Sister test to `fetch_website_tool_test.dart` — covers the *other*
/// branch of the loop's terminate-on-empty-data policy. Where
/// `fetch_website` returns markdown and the loop continues to a second
/// model call, `send_selfie` is side-effect-only: the image gets
/// attached to the bubble, the tool returns `ToolResult.ok()` with no
/// data, and the loop terminates after one round so the model's prose
/// + the attached image become the final reply (no second LLM call).
///
/// Asserts:
/// 1. Drawer toggle flips `imageToolSelfieAllowed` on the session.
/// 2. The assistant's last swipe carries one `send_selfie` tool-call
///    record with `success: true` AND `resultData == null`. The null
///    data is the proof that the side-effect-only branch ran (a
///    non-null payload would have caused a second LLM call).
/// 3. The same swipe has a non-empty `attachedImages` list — proves
///    the dispatch closure actually drove `generateImage` end-to-end
///    against the in-flight bubble (not just emitted the tool call).
///
/// Cost: 1 chat turn + 1 image on Grok defaults.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'send_selfie tool — image attached, loop terminates without second LLM call',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await bootSeedChat(tester);
      await enableToolViaDrawer(
        tester,
        toggleLabel: 'Character Can Send Selfies',
      );

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final session = controller.chatSession;
      expect(session, isNotNull);
      expect(
        session!.configMedia?.imageToolSelfieAllowed,
        isTrue,
        reason: 'drawer toggle should set imageToolSelfieAllowed on session',
      );

      // Naming the tool and asking explicitly drives Grok to emit one
      // send_selfie call. "Right now" gives the model an obvious
      // emotional beat for the schema's purpose/emotion fields.
      const userPrompt =
          'Please use the send_selfie tool to share a selfie '
          'showing how you feel right now.';
      await sendChatPrompt(tester, userPrompt);

      // Manual loop: iter 1 LLM call + image generation in dispatch.
      // Image gen on Grok can take 30-60s; chat is "idle" only after
      // dispatch completes and Complete fires.
      await awaitChatIdle(tester, timeout: const Duration(seconds: 120));

      final selfie = assertToolFiredOnLastMessage(
        controller,
        toolName: SendSelfieTool.toolName,
      );
      expect(
        selfie.success,
        isTrue,
        reason:
            'send_selfie call should have succeeded; '
            'errorMessage=${selfie.errorMessage}',
      );
      expect(
        selfie.resultData,
        isNull,
        reason:
            'send_selfie is side-effect-only — null resultData is '
            'what tells the loop to terminate without a second LLM '
            'call. Non-null here would mean the terminate-on-empty-data '
            'policy regressed.',
      );

      // The image must have actually attached to the bubble — proves
      // the dispatch closure drove generateImage end-to-end, not just
      // logged the call.
      final lastMessage = controller.messages.last;
      final activeSwipe = lastMessage.swipes[lastMessage.swipeIndex];
      expect(
        activeSwipe.attachedImages,
        isNotEmpty,
        reason:
            'send_selfie should have attached an image to the active '
            'swipe; got attachedImages=${activeSwipe.attachedImages}',
      );

      // Hold the final UI state for a few seconds of real wall time
      // so a watching operator can visually confirm the attached
      // selfie before the test framework tears down the app.
      // `pumpAndSettle` only advances Flutter's frame clock; an actual
      // delay needs `Future.delayed` plus a final `pump` to flush.
      await Future<void>.delayed(const Duration(seconds: 5));
      await tester.pump();
    },
  );
}
