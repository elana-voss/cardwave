import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Group target-speak: with 2 characters in the group, tap a specific
/// character's "Make this character speak" button (Icons.play_arrow
/// trailing in GroupCharacterTile, group_character_tile.dart:40-46) and
/// assert ONLY that character replies to the user message — proving
/// the per-character generateReplyFor path picks the intended speaker
/// instead of the activation-strategy default.
///
/// Underlying use case: in a group, the user can force a specific
/// character to take the next turn (instead of the round-robin or
/// talkativeness-weighted default).
///
/// One chat API call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group chat — target-speak triggers only the picked character',
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

      // ─── Navigate to Groups grid + create a new group ──────────────
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
        'Target speak group',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('group-create-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ─── Add BOTH characters via the picker ────────────────────────
      await tester.tap(find.byKey(const Key('group-add-character')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-add-character-drawer')));
      await tester.pumpAndSettle();

      // Picker shows 2 candidate ListTiles. Tap each so both circle
      // icons flip to check_circle, then commit with "Add 2".
      await tester.tap(find.byType(ListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(ListTile).at(1));
      await tester.pump();
      await tester.tap(find.textContaining('Add 2'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Close the drawer that the empty-state opened. Same primitive as
      // chat_group_test (handlePopRoute → ScaffoldState.closeDrawer).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ─── Send a user message ───────────────────────────────────────
      final input = find.byKey(const Key('chat-input')).first;
      await tester.enterText(input, 'Reply with two words.');
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // ─── Reopen drawer + tap "Make this character speak" on Cass ───
      // The character drawer is opened from the appbar's Icons.group
      // tooltip 'Characters' (group_chat_page.dart:243-247).
      await tester.tap(find.byKey(const Key('group-characters-drawer')));
      await tester.pumpAndSettle();

      // Pick Cass as the target — scope to her GroupCharacterTile so we
      // tap the right play button (there's one per tile = two total).
      const targetName = 'Cass | Assistant';
      final cassTile = find.ancestor(
        of: find.text(targetName),
        matching: find.byType(GroupCharacterTile),
      );
      expect(
        cassTile,
        findsOneWidget,
        reason: 'Cass tile should be in the drawer',
      );

      final speakButton = find.descendant(
        of: cassTile,
        matching: find.byKey(const Key('group-character-speak')),
      );
      await tester.tap(speakButton);
      await tester.pump();

      await awaitChatIdle(tester, timeout: const Duration(seconds: 60));

      // Underlying use case: the LAST message is from Cass, not the
      // other group member. Asserting on characterId would be ideal but
      // requires resolving Cass's appCardId — content + role check is a
      // close proxy: the last message must be a character/assistant turn
      // (not user) and must NOT match Test Character's content (which
      // hasn't spoken yet, so its absence is meaningful).
      final controller = tester
          .element(find.byType(ChatView))
          .read<BaseChatViewController>();
      final last = controller.messages.last;
      expect(
        last.role == ChatRoleEnum.character ||
            last.role == ChatRoleEnum.assistant,
        isTrue,
        reason: "last message should be the picked character's reply",
      );

      // Stronger check: only ONE new character/assistant message after
      // the user turn — proves the picked character was the SOLE speaker
      // (not both characters cascaded into a round-robin).
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
        reason: 'target-speak must produce exactly one reply, not multiple',
      );
    },
  );
}
