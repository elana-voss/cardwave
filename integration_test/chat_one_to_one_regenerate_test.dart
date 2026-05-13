import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Regenerate the last AI reply via the swipe flipper's right chevron.
/// MessageSwipeFlipper at message_swipe_flipper.dart:65-84 uses one
/// IconButton whose tooltip flips between 'Next version' and
/// 'Regenerate' based on whether a next swipe variant exists. Right
/// after a fresh send, the AI reply has exactly one swipe and the
/// chevron's tooltip is 'Regenerate' — `find.byTooltip('Regenerate')`
/// is unique because the disabled chevrons on other bubbles fall back
/// to 'Next version'.
///
/// Two chat API calls (initial reply + regen).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — regenerate appends a swipe variant',
    timeout: const Timeout(Duration(minutes: 3)),
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

      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      final initialSwipes = controller.messages.last.swipes.length;
      final firstReplyContent = controller.messages.last.content;
      expect(
        initialSwipes,
        1,
        reason: 'fresh AI reply should have exactly one swipe',
      );

      // ListView is reverse:true, so `.first` is the most recent bubble
      // (the AI reply). Other bubbles' swipe-next is disabled.
      await tester.tap(find.byKey(const Key('msg-swipe-next')).first);
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      expect(
        controller.messages.last.swipes.length,
        initialSwipes + 1,
        reason: 'regenerate should append a new swipe variant',
      );
      expect(
        controller.messages.last.swipeIndex,
        controller.messages.last.swipes.length - 1,
        reason: 'after regen, swipeIndex should point at the new variant',
      );
      // Sanity: regen produced different content (LLM is non-deterministic
      // but a 2-word repeat is unlikely). If the model echoes verbatim
      // this would be a false positive — accept that risk.
      expect(
        controller.messages.last.content,
        isNot(firstReplyContent),
        reason: 'regen should produce a different reply (best-effort)',
      );
    },
  );
}
