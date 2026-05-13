import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

/// Group roster edit: after adding Cass, open her tile in the character
/// panel (ExpansionTile) and tap "Remove from chat". The group is now
/// empty again — the page should rebuild back into the empty state with
/// the "Add a character" action.
///
/// No API call. Covers the remove-last-character → revert-to-empty-state
/// path, which is the state-management edge most likely to regress when
/// the character-panel UI gets refactored.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Group — remove last character reverts to empty state',
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

      // Grid → Groups grid.
      await tester.tap(find.byKey(const Key('grid-groups-button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Create a new group (narrow: SpeedDial Icons.add; wide: "New group").
      final newGroupBtn = find.byKey(const Key('group-new-button'));
      if (newGroupBtn.evaluate().isNotEmpty) {
        await tester.tap(newGroupBtn);
      } else {
        await tester.tap(find.byKey(const Key('group-new-fab')));
      }
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('group-name-field')),
        'Roster test',
      );
      await tester.pump();
      await dismissKeyboard(tester);
      await tester.tap(find.byKey(const Key('group-create-confirm')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Empty state → drawer → picker → add Cass.
      await tester.tap(find.byKey(const Key('group-add-character')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-add-character-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();
      await tester.tap(find.textContaining('Add 1'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Picker has popped; drawer still shows the roster panel with Cass's
      // ExpansionTile. Tap to expand the tile, then "Remove from chat".
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('group-character-remove')));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Close the drawer (system back press — same primitive we use in
      // chat_group_test for clean drawer dismiss).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Group is empty again → empty-state widget should be rendered. The
      // "Add a character" label (lowercase 'a') is unique to the empty
      // state; the drawer uses "Add Character" (capital C).
      expect(
        find.byKey(const Key('group-add-character')),
        findsOneWidget,
        reason: 'Removing the last character must revert to empty state',
      );
    },
  );
}
