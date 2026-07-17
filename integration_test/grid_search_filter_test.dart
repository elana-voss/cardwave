import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/search/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Grid search filters AND ranks. With the Ada Lovelace card + Test
/// Character on the grid, typing 'Lovelace' drops Test Character (no
/// literal "Lovelace" anywhere in its indexed fields, and the sci-fi
/// droid content is far below the 0.65 meaning-side cutoff against that
/// query) and leaves Ada as the sole tile. Clearing the field returns the
/// grid to its default sort order with both cards visible.
///
/// Underlying use case: a user with many cards can type a few letters of
/// a name to surface that card. Catches a regression where the filter
/// listener stops firing, the relevance gate fails to drop non-matches,
/// or the FilterController's score wiring stops bumping name matches.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — search filters non-matches and ranks the name match first',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();
      await seedTestCharacter();
      await seedSecondCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Pre-state: 2 cards visible.
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'seed should put both cards on the grid',
      );

      // Match by hintText so the finder isn't brittle if a popup or
      // dialog later adds another TextField to the screen.
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search...',
      );

      // The Ada card carries more text than Test Character; without this
      // poll the search fires while it has no BM25 tokens and the cutoff
      // returns an empty grid. Probe with "Babbage" (description-only)
      // rather than the query token so the exact-name override doesn't
      // falsely satisfy the wait before the tokens are actually indexed.
      final searchService = tester
          .element(find.byType(MaterialApp))
          .read<SearchService>();
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final targetCard =
          (await characterService.loadByName(kSecondCharacterName))!;
      final allPaths = await characterService.allCardPaths();
      final indexerDeadline = DateTime.now().add(const Duration(seconds: 45));
      var lexicalReady = false;
      while (DateTime.now().isBefore(indexerDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        final scores = await searchService.rankLexical('Babbage', allPaths);
        if (scores.containsKey(targetCard.appCardImagePath)) {
          lexicalReady = true;
          break;
        }
      }
      expect(
        lexicalReady,
        isTrue,
        reason:
            'keyword index should have the Ada card before we type the query',
      );

      // Test Character (Unit 734) has no "Lovelace" anywhere indexed; the
      // cutoff drops it.
      await tester.enterText(searchField, 'Lovelace');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        find.byType(CharacterGridItem),
        findsOneWidget,
        reason:
            'typing "Lovelace" should drop Test Character (no literal hit, '
            'meaning-side score below 0.65) — only the Ada card remains',
      );
      final onlyItem = findCharacterTile(kSecondCharacterName);
      expect(
        find.descendant(
          of: onlyItem,
          matching: find.text(kSecondCharacterName),
        ),
        findsOneWidget,
        reason: 'remaining tile must be the Ada card',
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
