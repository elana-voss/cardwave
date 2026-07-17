import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Delete the currently-active chat from the All Chats drawer list.
/// Setup: chat A (greeting + user + reply, 3 msgs) created first, then
/// "New Chat → Keep Current" creates chat B (1 msg, current). Open All
/// Chats, delete chat B's entry, and assert the controller auto-loads
/// chat A — proving onChatDeleted's reloadLatestChat path
/// (workspace_page.dart:1174-1182) actually picks the next regular
/// chat instead of leaving the user stuck on a deleted session.
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — delete active chat falls back to next one',
    timeout: const Timeout(Duration(minutes: 3)),
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

      // ─── Chat A: send a turn and capture its id + user content ──────
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 3));

      final chatA = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final chatAId = chatA.chatSession!.id;
      final chatAUserContent = chatA.messages
          .firstWhere((m) => m.role.toString().contains('user'))
          .content;

      // ─── Chat B: New Chat → Keep Current (becomes current) ─────────
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
      expect(chatBId, isNot(chatAId), reason: 'chat B should be a new session');

      // ─── Delete chat B from the All Chats list ─────────────────────
      // Order in the list is by lastActive desc — chat B was created
      // most recently so its entry is first. Scope more_vert to the
      // drawer's AllChatsDrawerList to avoid hitting bubble icons in
      // the underlying chat view.
      await tester.tap(find.byKey(const Key('appbar-end-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-all-chats')));
      await tester.pumpAndSettle();

      final drawerMoreVerts = find.descendant(
        of: find.byType(AllChatsDrawerList),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(drawerMoreVerts.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat-history-delete')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Are you sure you want to delete this chat history',
        ),
        findsOneWidget,
        reason: 'delete confirm dialog should appear',
      );
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Underlying use case: controller auto-loads chat A (the next
      // regular chat by lastActive) — user is not stuck on a deleted or
      // null session, and the assistant chat is correctly skipped by the
      // isAssistant filter even though it has its own lastActive.
      final reloaded = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      expect(
        reloaded.chatSession!.id,
        chatAId,
        reason: 'after deleting current, controller must load chat A',
      );
      expect(
        reloaded.messages.length,
        3,
        reason: 'chat A should reload with all of its messages',
      );
      expect(
        reloaded.messages.any((m) => m.content == chatAUserContent),
        isTrue,
        reason: 'chat A user message must come back',
      );
    },
  );
}
