import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Chat persistence: send a message + receive a reply, navigate back to
/// the grid, re-enter Cass, and assert the same chat session reloads
/// with the same content.
///
/// Underlying use case: nothing the user just typed disappears when
/// they leave the chat. _loadLatestChatOrNew at chat_page_controller.dart:128
/// is supposed to pick up the most recent chat for the character on
/// re-entry — this test catches regressions where it creates a new chat
/// instead, or where the save-on-reply path doesn't persist messages
/// to disk in time for the next load.
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — messages survive navigate-away-and-back',
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

      final firstController = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final firstChatId = firstController.chatSession!.id;

      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));
      // awaitChatIdle only checks the controller flag — the save-to-disk
      // step that follows reply completion is async (and likely
      // unawaited). Give the persist a window to land before popping the
      // route, otherwise re-entry sees no saved chat and starts fresh.
      await tester.pump(const Duration(seconds: 3));

      final beforeCount = firstController.messages.length;
      final beforeUserContent = firstController.messages
          .firstWhere((m) => m.role.toString().contains('user'))
          .content;
      final beforeReplyContent = firstController.messages.last.content;
      expect(
        beforeCount,
        greaterThanOrEqualTo(3),
        reason: 'after send + reply: greeting + user + reply',
      );

      // Pop back to the grid via the chat appbar's leading button
      // (Icons.grid_view_rounded → Navigator.pop, appbar_chat.dart:27-30).
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.byType(CharacterGridItem),
        findsAtLeastNWidgets(1),
        reason: 'should be back on the character grid',
      );

      // Re-enter Cass. _loadLatestChatOrNew should reload the most recent
      // chat (the one we just created), NOT create a fresh one.
      await tester.tap(findCharacterTile(kCassName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final secondController = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();

      // Underlying use case: same session id (no fresh chat), same length
      // (no message loss), same user message + reply content (no
      // corruption on round-trip).
      expect(
        secondController.chatSession!.id,
        firstChatId,
        reason: 'same chat session must reload, not a new one',
      );
      expect(
        secondController.messages.length,
        beforeCount,
        reason: 'all messages must survive navigation',
      );
      expect(
        secondController.messages.any((m) => m.content == beforeUserContent),
        isTrue,
        reason: 'user message content must survive round-trip',
      );
      expect(
        secondController.messages.last.content,
        beforeReplyContent,
        reason: 'reply content must survive round-trip',
      );
    },
  );
}
