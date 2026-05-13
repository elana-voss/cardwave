import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Send-during-in-flight: there is no concurrent-send path. The send
/// button at chat_view.dart:368-373 flips its icon (Icons.send →
/// Icons.stop) and its onPressed branch (sendMessage → stopGeneration)
/// the moment isGenerating is true. So a "send while generating" tap
/// is, by design, a cancel.
///
/// Asserts the cancel path: a long-output prompt buys streaming window;
/// during that window we tap the (now-Stop) button; isGenerating must
/// fall back to false. Catches regressions where stopGeneration doesn't
/// actually unset the flag or where the button forgets to repurpose.
///
/// One chat API call (cancelled mid-stream).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — Stop button cancels in-flight generation',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
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

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      // Long-output prompt widens the streaming window so we can observe
      // isGenerating=true and tap Stop before the reply finishes. A short
      // 2-word prompt completes in ~2s and risks racing the test.
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(
        input,
        'Write a five-paragraph story about a lighthouse keeper.',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Poll for isGenerating=true. sendMessage() sets the flag
      // synchronously then awaits the network — first pump after the tap
      // should already see it true, but loop briefly to be robust.
      final startDeadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(startDeadline)) {
        await tester.pump(const Duration(milliseconds: 50));
        if (controller.isGenerating) break;
      }
      expect(
        controller.isGenerating,
        isTrue,
        reason: 'send should flip controller into generating state',
      );

      // Send button has flipped to Icons.stop. The button keeps its
      // Key('chat-send') — only the inner icon swaps based on
      // controller.isGenerating.
      expect(
        find.byIcon(Icons.stop),
        findsOneWidget,
        reason: 'send button should display Icons.stop while generating',
      );
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Wait for the controller to release the generating flag. Streaming
      // may take a few hundred ms to unwind through the abort path.
      final stopDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(stopDeadline)) {
        await tester.pump(const Duration(milliseconds: 100));
        if (!controller.isGenerating) break;
      }
      expect(
        controller.isGenerating,
        isFalse,
        reason: 'Stop tap should halt generation within 10s',
      );

      // Button must have flipped back to Icons.send so subsequent sends
      // work — guards against a regression where the icon stays Icons.stop
      // after cancel.
      expect(
        find.byIcon(Icons.send),
        findsOneWidget,
        reason: 'send button should restore to Icons.send after cancel',
      );
    },
  );
}
