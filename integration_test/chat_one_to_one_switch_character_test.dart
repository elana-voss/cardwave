import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Switch the active character mid-chat via the appbar's
/// AppBarSwitcherTitle. Setup seeds two cards so the picker has
/// something to pick. After tap, the
/// workspace replaces its route with a new WorkspacePage bound to the
/// chosen character — the appbar title must reflect the new character.
///
/// Underlying use case: a user can jump to a different character from
/// inside a chat without going back to the grid; the new chat loads
/// for the picked character. Catches regressions in WorkspaceSwitchCharacter
/// + DialogCharacterSwitcher + the route swap.
///
/// No API calls (the new character's chat boots into its greeting).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '1:1 chat — switch character mid-chat via appbar title',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedGrokRecovery();
      await seedTestCharacter();
      await seedSecondCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Sanity: the seed actually placed two cards on the grid.
      expect(
        find.byType(CharacterGridItem),
        findsNWidgets(2),
        reason: 'grid should show both seeded characters',
      );

      // Enter the first character (whichever the grid sorts to top —
      // could be either; we don't care which one is the source).
      await tester.tap(findCharacterTile(kSeedCharacterName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Capture the source character name via the AppBarSwitcherTitle —
      // its displayName matches `nickname ?? name` for whichever card we entered.
      final sourceTitle = tester.widget<AppBarSwitcherTitle>(
        find.byType(AppBarSwitcherTitle),
      );
      final sourceName = sourceTitle.displayName;

      // Open the picker. AppBarSwitcherTitle is an InkWell whose onTap
      // calls WorkspaceSwitchCharacter.switchCharacterInWorkspace.
      await tester.tap(find.byType(AppBarSwitcherTitle));
      await tester.pumpAndSettle();

      // Pick the OTHER character. Resolve the target via CharacterService
      // so we don't hardcode the name — Test Character's metadata could
      // change. Find the file whose name differs from the source, then
      // tap its ListTile by text. Use AppBarSwitcherTitle as the
      // provider-lookup anchor (still mounted in the appbar; the grid
      // CharacterGridItems are no longer in the tree once we entered chat).
      final cs = tester
          .element(find.byType(AppBarSwitcherTitle))
          .read<CharacterService>();
      final targetFile = (await cs.loadAll()).firstWhere(
        (f) => f.card.displayName != sourceName,
        orElse: () => throw StateError('seed should have put a 2nd card in cs'),
      );
      final targetName = targetFile.card.displayName;

      await tester.tap(find.text(targetName));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Underlying use case: the appbar now reflects the picked character.
      // Reading the title widget back proves the route was actually
      // swapped (pushReplacement to a new WorkspacePage with the new
      // characterFile) — not just the dialog dismissed.
      final newTitle = tester.widget<AppBarSwitcherTitle>(
        find.byType(AppBarSwitcherTitle),
      );
      final newName = newTitle.displayName;
      expect(
        newName,
        targetName,
        reason: 'appbar title should show the picked character',
      );
      expect(
        newName,
        isNot(sourceName),
        reason: 'sanity — character actually changed',
      );
    },
  );
}
