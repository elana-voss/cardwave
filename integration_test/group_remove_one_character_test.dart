import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Group roster shrink: with 2 characters in the group, expand Cass's
/// GroupCharacterTile and tap "Remove from chat". Assert the
/// controller's characters list now holds only the OTHER character —
/// proves removeCharacter targets the picked id and leaves the rest
/// of the roster intact (regression: removing any character could
/// drop more than one, or wipe the roster entirely).
///
/// Underlying use case: a user can prune a group without recreating
/// it. Complements group_clear_characters_test which removes the LAST
/// character (1→0); this exercises the 2→1 path which the
/// removeCharacter implementation must handle without falling through
/// to the empty-state branch.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group chat — remove one of two characters leaves the other',
    timeout: const Timeout(Duration(minutes: 2)),
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

      // Build a 2-character group.
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
        'Roster shrink group',
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

      // Drawer is still open from the empty-state path; both characters
      // appear as GroupCharacterTiles. Sanity-check the pre-state.
      final controller = tester
          .element(find.byType(ChatView))
          .read<GroupChatController>();
      expect(
        controller.characters.length,
        2,
        reason: 'group should have both characters before removal',
      );
      final survivor = controller.characters
          .firstWhere((c) => c.card.name != 'Cass | Assistant')
          .card
          .name;

      // Expand Cass's tile, then tap "Remove from chat".
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
      await tester.tap(cassTile);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-character-remove')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Underlying use case: only the OTHER character remains. Picking
      // by id (via the .first survivor before removal) catches a
      // regression where removeCharacter accidentally drops both, or
      // drops the wrong one.
      expect(
        controller.characters.length,
        1,
        reason: 'after removing Cass exactly one character should remain',
      );
      expect(
        controller.characters.first.card.name,
        survivor,
        reason: 'the OTHER character (not Cass) must be the survivor',
      );
    },
  );
}
