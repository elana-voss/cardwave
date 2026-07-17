import 'package:cardwave/character/character.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Character import: drive [CharacterRepository.importCharacter] directly
/// (bypassing the native file picker which integration tests can't drive)
/// with the bundled `Test_Character.png` bytes. The seed already placed a
/// `Test_Character.png` on disk, so the import path must collide-handle by
/// suffixing the destination filename — io_character.dart:341-369 appends
/// `_<n>` until the name is free.
///
/// Underlying use case: a user can add a card to the grid by importing a
/// PNG, and re-importing the same filename does NOT overwrite the
/// original — both cards survive on the grid under distinct filenames.
/// Catches regressions in the suffix loop or in the post-import grid
/// refresh.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Grid — import PNG suffixes on collision and shows on grid',
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

      // Pre-state: the seeded Test Character on the grid.
      expect(
        find.byType(CharacterGridItem),
        findsOneWidget,
        reason: 'seed should put 1 card on the grid',
      );

      // Look up service + repo via any mounted grid item (both are
      // root-level Providers).
      final gridContext = tester.element(findCharacterTile(kSeedCharacterName));
      final repo = gridContext.read<CharacterRepository>();
      final service = gridContext.read<CharacterService>();

      // Import Test_Character.png AGAIN — same bytes, same source filename.
      // The destination should land as Test_Character_1.png because
      // Test_Character.png already exists from the seed.
      final byteData = await rootBundle.load(
        'assets/test_cards/Test_Character.png',
      );
      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final imported = await repo.importCharacter(bytes, 'Test_Character.png');

      expect(
        imported.appCardImagePath,
        'Test_Character_1.png',
        reason: 'collision must be resolved by appending _1, not overwrite',
      );

      // repo.importCharacter writes to disk but doesn't update the
      // service's in-memory list — loadCharacters rescans and notifies.
      await service.loadCharacters();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'after import the grid should show 2 cards',
      );

      // Confirm the suffixed file landed in the library index — proves
      // loadCharacters picked it up, not just that bytes hit disk.
      final hasSuffixed = (await service.allCardPaths()).contains(
        'Test_Character_1.png',
      );
      expect(
        hasSuffixed,
        isTrue,
        reason: 'CharacterService should expose the suffixed file',
      );
    },
  );
}
