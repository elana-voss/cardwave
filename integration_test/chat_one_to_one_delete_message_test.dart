import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Delete a message via the bubble's more_vert popup. Confirmation
/// dialog must appear (chat_view.dart:113), and tapping its "Delete"
/// button must drop the message from the controller's history.
///
/// Targets the AI reply (last message). Catches regressions in the
/// confirm-dialog wiring and in the controller.deleteMessage flow,
/// which is shared with the swipe-to-delete path.
///
/// One chat API call (the greeting auto-reply path).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — delete AI reply via bubble actions menu',
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

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final initialCount = controller.messages.length;
      expect(
        initialCount,
        greaterThanOrEqualTo(1),
        reason: 'seed card greeting should be present at boot',
      );

      // Send a user message → 1:1 auto-replies. End state: greeting + user
      // + AI reply (3 messages). Need the reply done so the bubble's
      // more_vert popup is enabled (PopupMenuButton at message_actions_row
      // line 88 is gated on !isStreamingThisMessage).
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      final afterReplyCount = controller.messages.length;
      expect(
        afterReplyCount,
        greaterThanOrEqualTo(initialCount + 2),
        reason: 'send + auto-reply should add user turn + AI reply',
      );

      // Open the more_vert popup on the AI reply. The chat ListView uses
      // `reverse: true` (chat_view.dart:182 inverts msgIndex), so build
      // order of bubbles is bottom-up — `.first` is the most recent
      // message (the reply), `.last` is the greeting.
      final replyContent = controller.messages.last.content;
      await tester.tap(find.byKey(const Key('msg-menu-trigger')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('msg-menu-delete')));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete Message'),
        findsOneWidget,
        reason: 'delete confirm dialog should appear',
      );
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle();

      expect(
        controller.messages.length,
        afterReplyCount - 1,
        reason: 'deleting one message should drop the count by one',
      );
      // Verify the reply specifically is gone — guards against the
      // selector hitting the wrong bubble (e.g. the greeting), which a
      // count-only assertion would silently miss.
      expect(
        controller.messages.any((m) => m.content == replyContent),
        isFalse,
        reason: 'the AI reply specifically should be the one deleted',
      );
    },
  );
}
