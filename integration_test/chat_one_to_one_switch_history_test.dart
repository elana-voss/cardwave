import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Switch back to a historical chat via the All Chats drawer entry.
/// Sets up two chats for Cass: chat A holds a user turn + reply
/// (3 messages), chat B is fresh from "Keep Current" (1 greeting).
/// Opens the drawer → All Chats list, taps the entry with the
/// '3 messages' subtitle, and asserts the controller now holds
/// chat A's session id and content again.
///
/// Underlying use case: a user can return to a previous conversation
/// from the chat history without losing what they typed before.
///
/// One chat API call (the reply on chat A).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — switch back to historical chat via All Chats',
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

      // ─── Chat A: greeting + user + reply ────────────────────────────
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));
      // Persistence is async beyond awaitChatIdle (see persistence test).
      await tester.pump(const Duration(seconds: 3));

      final chatA = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final chatAId = chatA.chatSession!.id;
      final chatAUserContent = chatA.messages
          .firstWhere((m) => m.role.toString().contains('user'))
          .content;
      expect(
        chatA.messages.length,
        3,
        reason: 'chat A should have greeting + user + reply',
      );

      // ─── New Chat → Keep Current ───────────────────────────────────
      // Open end-drawer (Icons.menu in chat appbar). Tap top-level 'New
      // Chat' tile — drawer auto-pops, then a confirmation dialog appears.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-menu-new-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));

      final chatB = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final chatBId = chatB.chatSession!.id;
      expect(
        chatBId,
        isNot(chatAId),
        reason: 'New Chat should produce a different session',
      );
      expect(
        chatB.messages.length,
        1,
        reason: 'fresh chat should hold only the greeting',
      );

      // ─── All Chats → tap chat A's entry ────────────────────────────
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-all-chats')));
      await tester.pumpAndSettle();

      // Both chats appear in the list (ChatListItem subtitles read
      // '{messageCount} messages' — see chat_list_item.dart:46). Chat A
      // is the only one with 3 messages; chat B has 1.
      expect(
        find.text('3 messages'),
        findsOneWidget,
        reason: 'chat A entry must be visible in the All Chats list',
      );
      await tester.tap(find.text('3 messages'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Underlying use case: chat A is fully re-loaded — same session id,
      // same length, same user-message content as before the switch.
      final reloaded = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      expect(
        reloaded.chatSession!.id,
        chatAId,
        reason: 'switching back must restore chat A',
      );
      expect(
        reloaded.messages.length,
        3,
        reason: 'all of chat A must reload, not just the greeting',
      );
      expect(
        reloaded.messages.any((m) => m.content == chatAUserContent),
        isTrue,
        reason: 'the user message must come back with the chat',
      );
    },
  );
}
