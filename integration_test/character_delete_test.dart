import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Character delete: open Cass's popup menu, tap "Delete", confirm in
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
    'Grid — delete Cass removes her from grid, memory, and disk',
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

      // ─── Pre-state: 2 cards visible, both on disk ──────────────────────
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'seed should put Cass + Test Character on the grid',
      );

      final gridContext = tester.element(findCharacterTile(kCassName));
      final service = gridContext.read<CharacterService>();
      final storage = gridContext.read<AppStorage>();

      // Capture Cass's on-disk filename BEFORE deletion so we can verify
      // it's gone afterward. Reading from the live in-memory list keeps
      // the test honest if the seed/asset filename ever changes.
      final cassFile = service.characterFiles.firstWhere(
        (f) => f.card.name == kCassName,
      );
      final cassImagePath = cassFile.appCardImagePath;
      expect(
        await storage.fileExists(StorageDomainEnum.cards, cassImagePath),
        isTrue,
        reason: 'Cass PNG must exist on disk before the delete',
      );

      // Open Cass's popup, tap Delete, confirm. The popup closes on the
      // first 'Delete' tap and the AlertDialog opens — so the dialog's own
      // 'Delete' button only enters the tree after the popup item dismisses,
      // and the two same-text taps don't collide.
      final cassMore = find.descendant(
        of: findCharacterTile(kCassName),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(cassMore);
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

      // Underlying use case: gone from grid, memory, AND disk.
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(1),
        reason: 'grid should shrink to 1 card after deleting Cass',
      );
      expect(
        service.characterFiles.length,
        1,
        reason: 'CharacterService should hold exactly one file',
      );
      expect(
        service.characterFiles.any((f) => f.card.name == kCassName),
        isFalse,
        reason: 'Cass must NOT be in the in-memory list anymore',
      );

      // The load-bearing assertion: Cass's PNG is actually gone from disk.
      // A regression in IoCharacter.deleteCharacter (e.g. silent catch,
      // wrong path resolution) would leave the file behind even though
      // the in-memory checks above would still pass.
      expect(
        await storage.fileExists(StorageDomainEnum.cards, cassImagePath),
        isFalse,
        reason: 'Cass PNG must be removed from disk after the delete',
      );
    },
  );
}
