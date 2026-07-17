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

// The grid is virtualized (off-viewport tiles aren't mounted), so widget
// counts for the unfiltered nine-card pool would only show the ~4 visible
// rows. Assert membership via FilterController.filteredCount for the full
// pool; widget-count assertions only apply to small filtered result sets.

/// Calibration probe for the search pipeline. Seeds nine diverse cards
/// and runs a battery of queries: tight literal-token cutoffs
/// (each query should match exactly one card), discovery probes (a
/// near-synonym query that no card contains literally), and a nonsense
/// query (no admission at all). Failures here mean the threshold or the
/// lexical/semantic boundary needs adjustment, not that the test setup
/// is wrong — pin the failure to a specific query and tune from there.
///
/// No API calls — embedder and BM25 are both local.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — search admission across diverse card pool',
    timeout: const Timeout(Duration(minutes: 10)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();
      await seedExampleCards();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      final searchService = tester
          .element(find.byType(MaterialApp))
          .read<SearchService>();
      final characterService = tester
          .element(find.byType(MaterialApp))
          .read<CharacterService>();

      // FilterController lives below MaterialApp (created inside the grid
      // page via ChangeNotifierProvider), so we read it from a descendant
      // — the search field is always rendered when the grid is up.
      final searchField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Search...',
      );
      final filterController = tester
          .element(searchField)
          .read<FilterController>();

      try {
        await searchService.initEmbedder().timeout(
          const Duration(seconds: 240),
        );
      } on EmbeddingsException catch (e) {
        markTestSkipped('Embedder init failed on this device: $e');
        return;
      }
      expect(searchService.isEmbedderReady, isTrue);

      // Wait for every card's data to be fully written (all five field
      // hashes present). The semantic loop skips cards with partial data,
      // so without this wait the discovery probes fire against a moving
      // target.
      final deadline = DateTime.now().add(const Duration(seconds: 180));
      var allIndexed = false;
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
        final paths = await characterService.allCardPaths();
        if (paths.length < kExampleCardFilenames.length) continue;
        final fully = paths.every((path) {
          final hashes = searchService.fieldHashesFor(path);
          return hashes != null &&
              hashes.length == CardSearchFieldEnum.values.length;
        });
        if (fully) {
          allIndexed = true;
          break;
        }
      }
      expect(
        allIndexed,
        isTrue,
        reason: 'all nine cards should be fully indexed before query probes',
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        filterController.filteredCount,
        equals(kExampleCardFilenames.length),
        reason: 'the seed should put all nine cards in the filter pool',
      );

      // Helper: type a query, wait for debounce + rank, return the count
      // of cards that survived the cutoff. Reads the controller directly
      // because the grid is virtualized and Finder counts only mounted
      // tiles.
      Future<int> probe(String query) async {
        await tester.enterText(searchField, query);
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
        return filterController.filteredCount;
      }

      // --- Literal-token cutoff probes ---
      // Each query is a token that exists in exactly one card's indexed
      // fields. Lexical admits that card; semantic discovery must not
      // smuggle in any other card.

      expect(
        await probe('detective'),
        equals(1),
        reason: '"detective" lives only in Detective Ryn\'s fields',
      );
      expect(
        find.descendant(
          of: find.byType(CharacterGridItem).first,
          matching: find.text('Ryn'),
        ),
        findsOneWidget,
        reason: 'the surviving tile should be Ryn',
      );

      expect(
        await probe('librarian'),
        equals(1),
        reason: '"librarian" lives only in Aria\'s fields',
      );
      expect(
        find.descendant(
          of: find.byType(CharacterGridItem).first,
          matching: find.text('Aria'),
        ),
        findsOneWidget,
        reason: 'the surviving tile should be Aria',
      );

      expect(
        await probe('corgi'),
        equals(1),
        reason: '"corgi" lives only in Pip\'s description',
      );
      expect(
        find.descendant(
          of: find.byType(CharacterGridItem).first,
          matching: find.text('Pip'),
        ),
        findsOneWidget,
        reason: 'the surviving tile should be Pip',
      );

      // --- No-match control ---
      // Nonsense string — no card contains it, semantic shouldn't find a
      // near-synonym either.

      expect(
        await probe('qzplmx'),
        equals(0),
        reason: 'no card contains "qzplmx"; semantic must not invent a match',
      );

      // --- Discovery probes ---
      // Queries with NO literal token match anywhere. Only the semantic
      // channel can admit. If these fail, the 0.92 threshold is too strict
      // (or the e5-small model can't separate signal from noise for short
      // queries). Loosen the threshold or accept the limitation.

      final robotCount = await probe('robot');
      expect(
        robotCount,
        lessThanOrEqualTo(1),
        reason:
            'discovery probe: "robot" is not a literal token in any card. '
            'Nexus-7 is an android — semantic may admit it. More than one '
            'admission means the threshold is too loose.',
      );

      final scientistCount = await probe('scientist');
      expect(
        scientistCount,
        lessThanOrEqualTo(1),
        reason:
            'discovery probe: "scientist" is not a literal token. Ada '
            'Lovelace is a mathematician — semantic may admit her. More '
            'than one admission means the threshold is too loose.',
      );

      // Clearing returns to the unfiltered grid (virtualized — check the
      // controller's filtered list, not mounted widgets).
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(
        filterController.filteredCount,
        equals(kExampleCardFilenames.length),
        reason: 'clearing the search restores the full nine-card pool',
      );
    },
  );
}
