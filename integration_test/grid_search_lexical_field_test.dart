import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/search/search.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Bug being defended: a card with the searched word in `description`
/// (a low-weighted field) used to rank far below cards whose `name`
/// merely embedded close-ish to the query via topical similarity. With
/// BM25F + RRF, a literal hit in any indexed field beats a fuzzy
/// no-literal-hit semantic neighbor.
///
/// Underlying use case: type a word that exists literally in a card's
/// description but nowhere else — that card should be at position 0.
///
/// No API calls — embedder and keyword index are both local.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — literal hit in description beats fuzzy neighbors',
    timeout: const Timeout(Duration(minutes: 6)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();
      await seedVietnameseDescriptionCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Pre-state: 2 cards visible (Cass auto-copied + Vietnamese seeded).
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'seed should put Cass + Vietnamese card on the grid',
      );

      // Wait for the meaning-search engine to finish unpacking its
      // 132 MB model file. On a fresh emulator install this is the slow
      // path; cached installs return immediately.
      final searchService = tester
          .element(find.byType(MaterialApp))
          .read<SearchService>();
      try {
        await searchService.initEmbedder().timeout(
          const Duration(seconds: 240),
        );
      } on EmbeddingsException catch (e) {
        markTestSkipped('Embedder init failed on this device: $e');
        return;
      }
      expect(searchService.isEmbedderReady, isTrue);

      // Wait until the keyword index has the Vietnamese card. Polling
      // the actual end-to-end signal (does rankLexical return Vietnamese
      // for "vietnamese"?) sidesteps the indexer's per-card counter race
      // where progress flips back to 0/0 the moment the queue drains.
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();
      final vietnameseCard = characterService.characterFiles.firstWhere(
        (f) => f.appCardImagePath.endsWith('Vietnamese_Desc_Character.png'),
      );
      final indexerDeadline = DateTime.now().add(const Duration(seconds: 60));
      var lexicalReady = false;
      while (DateTime.now().isBefore(indexerDeadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        final scores = searchService.rankLexical(
          'vietnamese',
          characterService.characterFiles.map((f) => f.appCardImagePath),
        );
        if (scores.containsKey(vietnameseCard.appCardImagePath)) {
          lexicalReady = true;
          break;
        }
      }
      expect(
        lexicalReady,
        isTrue,
        reason:
            'keyword index should rank Vietnamese for "vietnamese" '
            'before we type',
      );

      // Match by hintText so the finder isn't brittle if a popup or
      // dialog later adds another TextField to the screen.
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search...',
      );

      // 500ms debounce inside FilterController + an embed roundtrip;
      // 700ms covers both with margin.
      await tester.enterText(searchField, 'Vietnamese');
      await tester.pumpAndSettle(const Duration(milliseconds: 700));

      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'typing "Vietnamese" sorts but does not filter cards out',
      );

      // The Vietnamese-in-description card has no "Vietnamese" in its name
      // by construction (that's the whole point of the test). So the
      // first-tile assertion is "not Cass" — the seeded card is the only
      // other one on the grid, so anything-but-Cass means the literal hit
      // landed at the top.
      final firstItem = find.byType(CharacterGridItem).first;
      expect(
        find.descendant(of: firstItem, matching: find.text(kCassName)),
        findsNothing,
        reason:
            'BM25F + RRF should rank the literal-description-hit card '
            'above the fuzzy-only Cass match — Cass should not be first',
      );
    },
  );
}
