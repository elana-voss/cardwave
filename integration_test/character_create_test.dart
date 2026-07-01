import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Create a new character from scratch via the grid's SpeedDial FAB
/// ('Add or Import' tooltip → 'Create' child → DialogCreateCharacter).
/// Verifies the full create-from-scratch path: dialog accepts a name,
/// `CharacterRepository.createCharacter` writes a PNG (with the default
/// asset bytes + JSON metadata) to `<name>.png` under StorageDomainEnum.cards,
/// the new card lands in the library index and notifies, and the grid grows
/// by one tile.
///
/// Pairs with character_import + character_delete to cover the full
/// create/destroy lifecycle on Android (mobile path uses the dialog;
/// the Windows desktop path uses a native save-file picker we can't
/// drive from an integration test).
///
/// Underlying use case: a user can create a brand-new card with no
/// import + no AI, just a name. Catches regressions in the SpeedDial
/// trigger, the dialog wiring, the PNG write, and the in-memory list
/// refresh.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — create new character via dialog lands on grid + disk',
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

      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'seed should put 2 cards on the grid',
      );

      final gridContext = tester.element(findCharacterTile(kCassName));
      final service = gridContext.read<CharacterService>();
      final storage = gridContext.read<AppStorage>();

      // Sentinel name with a millisecond stamp — guarantees uniqueness
      // across runs and avoids the dialog's "name already exists" branch.
      // Avoid filename-invalid characters: <>:"/\|?* (per dialog regex).
      final sentinelName =
          'Sentinel Char ${DateTime.now().millisecondsSinceEpoch}';
      final expectedPath = '$sentinelName.png';

      expect(
        await storage.fileExists(StorageDomainEnum.cards, expectedPath),
        isFalse,
        reason: 'sentinel filename must NOT exist on disk before the test',
      );

      // Open the SpeedDial FAB (mobile path) and pick the Create child.
      // The wide-screen 'Create New' button is hidden on this viewport.
      await tester.tap(find.byKey(const Key('grid-fab-speed-dial')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-fab-create')));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('character-name-field'));
      await tester.enterText(nameField, sentinelName);
      await tester.pump();
      await dismissKeyboard(tester);

      await tester.tap(find.byKey(const Key('character-create-confirm')));
      // Submit lands the workspace in editor mode on top of the grid.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Pop back to grid so we can assert on grid widgets.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Underlying use case: present on grid, in memory, and on disk.
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(3),
        reason: 'grid should grow to 3 cards after creating a new one',
      );

      final created = (await service.loadAll())
          .where((f) => f.card.name == sentinelName)
          .toList();
      expect(
        created,
        hasLength(1),
        reason:
            'CharacterService should hold exactly one entry for the new name',
      );
      expect(
        created.single.appCardImagePath,
        expectedPath,
        reason: 'the new file should sit at <name>.png',
      );

      // The load-bearing disk assertion: the new PNG is actually on disk.
      // A regression in IoCharacter.createCharacter (e.g. the writeBytes
      // call silently no-ops, or the PNG path resolves wrong) would still
      // pass the in-memory checks above because the service stores the
      // CharacterFile object whether or not the bytes hit disk.
      expect(
        await storage.fileExists(StorageDomainEnum.cards, expectedPath),
        isTrue,
        reason: 'new character PNG must land on disk',
      );
    },
  );
}
