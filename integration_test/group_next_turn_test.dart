import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Group "Next turn" (Icons.skip_next, tooltip 'Next turn' in
/// group_chat_page.dart:248-254) with two characters in the roster.
/// Sends a user message, then taps Next turn ONCE. Asserts exactly one
/// character/assistant reply appears — the activation strategy must
/// pick a single speaker, not cascade into both.
///
/// Underlying use case: round-robin / talkativeness-weighted next-turn
/// produces one reply per tap, leaving the user in control of the
/// conversation pace.
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group chat — Next turn produces exactly one reply',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();
      await seedTestCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Navigate to Groups grid + create a new group.
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
        'Next turn group',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('group-create-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Add both characters via the picker.
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

      // Send the user turn.
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Tap Next turn ONCE — activation strategy picks one speaker.
      await tester.tap(find.byKey(const Key('group-next-turn')));
      await tester.pump();
      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      // Use case: exactly one character/assistant reply appended after
      // the user message — round-robin must not run more than one turn
      // per tap.
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final userIdx = controller.messages.lastIndexWhere(
        (m) => m.role == ChatRoleEnum.user,
      );
      final repliesAfterUser = controller.messages
          .sublist(userIdx + 1)
          .where(
            (m) =>
                m.role == ChatRoleEnum.character ||
                m.role == ChatRoleEnum.assistant,
          )
          .length;
      expect(
        repliesAfterUser,
        1,
        reason: 'one tap on Next turn must produce exactly one reply',
      );

      final last = controller.messages.last;
      expect(
        last.content,
        isNotEmpty,
        reason: 'reply must have non-empty content',
      );
    },
  );
}
