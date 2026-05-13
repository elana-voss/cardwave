import 'package:cardwave/character/character.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Favorite toggle persistence: tap the heart overlay on Cass's grid
/// tile, assert the in-memory `card.cardwaveData.isFavorite` flipped,
/// then force a fresh disk reload (`CharacterService.loadCharacters`)
/// and assert the toggled value survived.
///
/// Underlying use case: a user can mark a card as favorite and the
/// flag persists across restarts. Catches regressions in the favorite
/// overlay's GestureDetector wiring, the JSON-cache save, AND the
/// disk-read path in `_readCharacter` (which prefers `card.json` over
/// re-parsing the PNG).
///
/// CRITICAL: the favorite write is `unawaited` in the overlay, and it
/// goes only to the JSON cache (NOT to PNG metadata — different from
/// the editor round-trip). That's fine because `_readCharacter` reads
/// `card.json` first if present. The `loadCharacters()` reload between
/// toggle and assertion proves the bytes actually reached cache, not
/// just the in-memory CharacterFile object.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — favorite toggle persists across disk reload',
    timeout: const Timeout(Duration(minutes: 1)),
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

      final service = tester
          .element(findCharacterTile(kCassName))
          .read<CharacterService>();

      // Capture initial favorite state from memory so we can assert on the
      // OPPOSITE value after the toggle. Don't hardcode "default = false"
      // — it's a card-asset detail that could drift.
      final cassBefore = service.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      final initialFav = cassBefore.card.cardwaveData.isFavorite;
      final targetFav = !initialFav;

      // The favorite overlay icon swaps between `Icons.favorite` (on, red)
      // and `Icons.favorite_border` (off, white) — pick whichever the
      // current state demands.
      final favIcon = find.descendant(
        of: findCharacterTile(kCassName),
        matching: find.byIcon(
          initialFav ? Icons.favorite : Icons.favorite_border,
        ),
      );
      expect(
        favIcon,
        findsOneWidget,
        reason:
            'Cass tile should expose the heart overlay matching the initial '
            'favorite state ($initialFav)',
      );

      await tester.tap(favIcon);
      // The favorite save is fire-and-forget (unawaited in the overlay's
      // GestureDetector); pumpAndSettle drains the microtask queue.
      await tester.pumpAndSettle();

      final cassAfterTap = service.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      expect(
        cassAfterTap.card.cardwaveData.isFavorite,
        targetFav,
        reason: 'tap should flip in-memory isFavorite to $targetFav',
      );

      // Force a fresh disk read. _readCharacter prefers card.json (the JSON
      // cache); if the unawaited save never ran, the cache wouldn't reflect
      // the toggle and the post-reload assertion would fail.
      await service.loadCharacters();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final cassAfterReload = service.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      expect(
        cassAfterReload.card.cardwaveData.isFavorite,
        targetFav,
        reason:
            'favorite must equal $targetFav after the disk reload — proves '
            'the toggle reached the JSON cache, not just the in-memory '
            'CharacterFile',
      );

      // Identity sanity: the post-reload object is a FRESH instance,
      // not the same one we mutated. (If it WERE the same object, the
      // assertion above would pass trivially via in-memory mutation.)
      expect(
        identical(cassBefore, cassAfterReload),
        isFalse,
        reason:
            'loadCharacters() should rebuild _characterFiles with fresh '
            'instances; otherwise the persistence assertion is vacuous',
      );
    },
  );
}
