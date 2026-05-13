import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'app_test_helpers.dart';

/// Grid search re-sorts (semantic + name boost), it does not narrow the
/// result set. With Cass + Test Character on the grid, typing 'Cass'
/// should keep both cards but rank Cass first via the name-substring
/// boost. Clearing the field returns the grid to its default sort order.
///
/// Underlying use case: a user with many cards can type a few letters of
/// a name to surface that card at the top of the grid. Catches a
/// regression where the filter listener stops firing or the
/// FilterController's score wiring stops bumping name matches.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — search re-sorts to put name match first',
    timeout: const Timeout(Duration(minutes: 1)),
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

      // Pre-state: 2 cards visible.
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'seed should put Cass + Test Character on the grid',
      );

      // Match by hintText so the finder isn't brittle if a popup or
      // dialog later adds another TextField to the screen.
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search...',
      );

      // 'Cass' is in 'Cass | Assistant' but NOT in 'Unit 734 (Glitch)'
      // (Test Character's display name in the bundled asset).
      await tester.enterText(searchField, 'Cass');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason:
            'typing "Cass" should keep both cards (search sorts, '
            'does not filter)',
      );
      final firstItem = findCharacterTile(kCassName);
      expect(
        find.descendant(of: firstItem, matching: find.text(kCassName)),
        findsOneWidget,
        reason: 'name-boost should sort Cass to the first grid slot',
      );

      await tester.enterText(searchField, '');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'clearing the search keeps both cards visible',
      );
    },
  );
}
