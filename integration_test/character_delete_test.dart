import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Character delete: open the seed character's popup menu, tap "Delete", confirm in
/// the AlertDialog, and assert the card is gone from BOTH the grid +
/// in-memory list AND the on-disk PNG. The disk-state assertion via
/// AppStorage.fileExists is what catches a silent regression in
/// IoCharacter.deleteCharacter — checking the grid alone would pass
/// even if the PNG never got removed (the in-memory drop happens
/// synchronously regardless).
///
/// Pairs with character_import for full create/destroy lifecycle
/// coverage. No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — delete the seed card removes it from grid, memory, and disk',
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

      // ─── Pre-state: the seeded card is visible and on disk ─────────────
      expect(
        find.byType(CharacterGridItem),
        findsOneWidget,
        reason: 'seed should put exactly the seed character on the grid',
      );

      final gridContext = tester.element(findCharacterTile(kSeedCharacterName));
      final service = gridContext.read<CharacterService>();
      final storage = gridContext.read<AppStorage>();

      // Capture the card's on-disk filename BEFORE deletion so we can verify
      // it's gone afterward. Reading via loadByName keeps the test honest
      // if the seed/asset filename ever changes.
      final seedFile = (await service.loadByName(kSeedCharacterName))!;
      final seedImagePath = seedFile.appCardImagePath;
      expect(
        await storage.fileExists(StorageDomainEnum.cards, seedImagePath),
        isTrue,
        reason: 'seed PNG must exist on disk before the delete',
      );

      // Open the card's popup, tap Delete, confirm. The popup closes on the
      // first 'Delete' tap and the AlertDialog opens — so the dialog's own
      // 'Delete' button only enters the tree after the popup item dismisses,
      // and the two same-text taps don't collide.
      final seedMore = find.descendant(
        of: findCharacterTile(kSeedCharacterName),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(seedMore);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-item-delete')));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete Card'),
        findsOneWidget,
        reason: 'confirmation dialog should appear',
      );
      await tester.tap(find.byKey(const Key('dialog-confirm')));
      // Delete is async (chats → PNG → cache folder); drain before asserting.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Underlying use case: gone from grid, memory, AND disk. The seed was
      // the only card, so the grid empties out entirely.
      expect(
        find.byType(CharacterGridItem),
        findsNothing,
        reason: 'grid should be empty after deleting the only card',
      );
      expect(
        await service.allCardPaths(),
        isEmpty,
        reason: 'the library index should hold no cards',
      );
      expect(
        await service.loadByName(kSeedCharacterName),
        isNull,
        reason: 'the seed card must no longer be in the library index',
      );

      // The load-bearing assertion: the PNG is actually gone from disk.
      // A regression in IoCharacter.deleteCharacter (e.g. silent catch,
      // wrong path resolution) would leave the file behind even though
      // the in-memory checks above would still pass.
      expect(
        await storage.fileExists(StorageDomainEnum.cards, seedImagePath),
        isFalse,
        reason: 'seed PNG must be removed from disk after the delete',
      );
    },
  );
}
