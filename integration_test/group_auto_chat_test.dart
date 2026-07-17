import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Group auto-chat: with 2 characters in the roster, tapping Start
/// auto-chat (Icons.play_circle_outline → controller.startAutoChat)
/// kicks off a loop that fires `generateReply` repeatedly, picking
/// successive characters from the activation strategy. Tapping Stop
/// auto-chat (Icons.stop_circle_outlined when isAuto) sets
/// `_isAutoChatActive = false` so the loop drops out at the next
/// iteration boundary.
///
/// Underlying use case: hands-off conversation between characters.
/// Asserts (a) auto-chat actually generates more than one reply, and
/// (b) Stop actually halts the loop. Catches regressions where
/// startAutoChat fires once and exits, or where stopAutoChat fails to
/// release the flag.
///
/// Several chat API calls (we wait for ~2 auto replies then stop).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group chat — auto-chat generates multiple turns + stops on tap',
    timeout: const Timeout(Duration(minutes: 4)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();
      await seedTestCharacter();
      await seedSecondCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // ─── Build a 2-character group ─────────────────────────────────
      await tester.tap(find.byKey(const Key('grid-groups-button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      final newGroupBtn = find.byKey(const Key('group-new-button'));
      if (newGroupBtn.evaluate().isNotEmpty) {
        await tester.tap(newGroupBtn);
      } else {
        await tester.tap(find.byKey(const Key('group-new-fab')));
      }
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('group-name-field')),
        'Auto chat group',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('group-create-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('group-add-character')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-add-character-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(ListTile).at(1));
      await tester.pump();
      await tester.tap(find.textContaining('Add 2'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ─── Send a user message to seed the conversation ──────────────
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final controller = tester
          .element(find.byType(ChatView))
          .read<GroupChatController>();
      final userIdx = controller.messages.lastIndexWhere(
        (m) => m.role == ChatRoleEnum.user,
      );
      final initialReplyCount = controller.messages
          .sublist(userIdx + 1)
          .where(
            (m) =>
                m.role == ChatRoleEnum.character ||
                m.role == ChatRoleEnum.assistant,
          )
          .length;
      expect(
        initialReplyCount,
        0,
        reason: 'before auto-chat the user turn should have no reply yet',
      );

      // ─── Start auto-chat ───────────────────────────────────────────
      await tester.tap(find.byKey(const Key('group-auto-chat-toggle')));
      await tester.pump();

      expect(
        controller.isAutoChatActive,
        isTrue,
        reason: 'startAutoChat should flip isAutoChatActive',
      );

      // Poll for at least 2 character/assistant replies after the user
      // turn — proves auto-chat actually fires multiple iterations.
      var seenReplies = 0;
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        seenReplies = controller.messages
            .sublist(userIdx + 1)
            .where(
              (m) =>
                  m.role == ChatRoleEnum.character ||
                  m.role == ChatRoleEnum.assistant,
            )
            .length;
        if (seenReplies >= 2) break;
      }
      expect(
        seenReplies,
        greaterThanOrEqualTo(2),
        reason: 'auto-chat must fire at least 2 reply iterations',
      );

      // ─── Stop auto-chat ────────────────────────────────────────────
      // Once isAuto flipped, the appbar IconButton swaps to Icons.stop_circle_outlined
      // with tooltip 'Stop auto-chat' (group_chat_page.dart:255-266).
      await tester.tap(find.byKey(const Key('group-auto-chat-toggle')));
      await tester.pump();

      // The flag must release; in-flight generation may still finish but
      // the loop won't queue another iteration.
      final stopDeadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(stopDeadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        if (!controller.isAutoChatActive) break;
      }
      expect(
        controller.isAutoChatActive,
        isFalse,
        reason: 'Stop auto-chat must release the flag within 30s',
      );
    },
  );
}
