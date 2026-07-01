import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/search/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Grid search filters AND ranks. With Cass + Test Character on the
/// grid, typing 'Cass' drops Test Character (no literal "Cass" anywhere
/// in its indexed fields, and the sci-fi droid content is far below the
/// 0.65 meaning-side cutoff against the query "Cass") and leaves Cass as
/// the sole tile. Clearing the field returns the grid to its default
/// sort order with both cards visible.
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

      // Cass has more text than Test Character (~6 s to ingest); without
      // this poll the search fires while Cass has no BM25 tokens and the
      // cutoff returns an empty grid. Probe with "assistant" instead of
      // "cass" so the exact-name override doesn't falsely satisfy the
      // wait before Cass's tokens are actually indexed.
      final searchService = tester
          .element(find.byType(MaterialApp))
          .read<SearchService>();
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final cassCard = (await characterService.loadByName(kCassName))!;
      final allPaths = await characterService.allCardPaths();
      final indexerDeadline = DateTime.now().add(const Duration(seconds: 45));
      var lexicalReady = false;
      while (DateTime.now().isBefore(indexerDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        final scores = await searchService.rankLexical('assistant', allPaths);
        if (scores.containsKey(cassCard.appCardImagePath)) {
          lexicalReady = true;
          break;
        }
      }
      expect(
        lexicalReady,
        isTrue,
        reason:
            'keyword index should have Cass before we type the search query',
      );

      // Test Character (Unit 734) has no "Cass" anywhere indexed; the
      // cutoff drops it.
      await tester.enterText(searchField, 'Cass');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(
        find.byType(CharacterGridItem),
        findsOneWidget,
        reason:
            'typing "Cass" should drop Test Character (no literal hit, '
            'meaning-side score below 0.65) — only Cass remains',
      );
      final onlyItem = findCharacterTile(kCassName);
      expect(
        find.descendant(of: onlyItem, matching: find.text(kCassName)),
        findsOneWidget,
        reason: 'remaining tile must be Cass',
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
