import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Group chat smoke. Covers: navigate to group grid, create new group,
/// add Cass as the single member, send message, assert reply. With only
/// one group member available (Cass is the bundled asset), this tests the
/// group-prompt path without multi-character activation complexity. One
/// chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group chat smoke — create group, add Cass, send',
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

      // Navigate from character grid to group grid via the "Groups" button.
      await tester.tap(find.byKey(const Key('grid-groups-button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // New group button — wide breakpoint shows the appbar FilledButton,
      // narrow shows the SpeedDial FAB. Both keyed; try each.
      final newGroupBtn = find.byKey(const Key('group-new-button'));
      if (newGroupBtn.evaluate().isNotEmpty) {
        await tester.tap(newGroupBtn);
      } else {
        await tester.tap(find.byKey(const Key('group-new-fab')));
      }
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('group-name-field')),
        'Smoke group',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('group-create-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Group chat page, empty state. "Add a character" button triggers
      // Scaffold.of(context).openDrawer() — drawer slides in with the
      // "Add Character" action that opens GroupCharacterPicker.
      await tester.tap(find.byKey(const Key('group-add-character')));
      await tester.pumpAndSettle();

      // Drawer's "Add Character" trigger.
      await tester.tap(find.byKey(const Key('group-add-character-drawer')));
      await tester.pumpAndSettle();

      // GroupCharacterPicker is open. Tap the Cass row, then "Add 1".
      // First ListTile inside the picker dialog is Cass.
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      await tester.tap(find.textContaining('Add 1'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After "Add 1" pops the picker, the drawer the user opened from the
      // empty-state stays up. Use a system back press — Flutter routes that
      // to ScaffoldState.closeDrawer() automatically when a drawer is open,
      // same as the Android hardware back button.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Same flow as the 1:1 chat: type into the chat input, tap send.
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();

      // Group sendMessage only appends the user turn — the user has to tap
      // "Next turn" (skip_next) in the app bar to fire one character reply.
      // (1:1 chat auto-replies; group is opt-in per character turn.)
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('group-next-turn')));
      await tester.pump();

      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      expect(
        controller.messages.length,
        greaterThanOrEqualTo(2),
        reason: 'expected at least user + character reply',
      );
      final last = controller.messages.last;
      expect(
        last.role == ChatRoleEnum.character ||
            last.role == ChatRoleEnum.assistant,
        isTrue,
        reason: 'last message should be the group reply',
      );
      expect(last.content.isNotEmpty, isTrue);
    },
  );
}
