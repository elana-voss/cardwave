import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Editor round-trip: open the editor, type a sentinel into Description,
/// leave, force a fresh disk reload, re-enter, assert the sentinel
/// survived. Catches regressions in the editor's autosave debounce, the
/// PopScope flush on navigate-away, the PNG write path, or the disk
/// read on cold load.
///
/// The disk reload is load-bearing: CharacterFile is a single in-memory
/// object the editor mutates in place, so a naive leave+re-enter would
/// pass even if the bytes never hit disk. The grid reloads each card from
/// disk on demand, so the post-reload value reflects ONLY what was persisted.
///
/// No API calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Editor — description edit survives navigate-away + disk reload',
    timeout: const Timeout(Duration(minutes: 1)),
    (tester) async {
      if (!hasGrokKey) {
        markTestSkipped('GROK_API_KEY not supplied (pass --dart-define).');
        return;
      }

      await wipeAppData();
      await seedTestCharacter();
      await seedGrokRecovery();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Sentinel string includes a timestamp so a stale-cache pass would be
      // visibly impossible — the value cannot have existed before this run.
      final sentinel =
          'Round-trip sentinel ${DateTime.now().millisecondsSinceEpoch}';

      // RouteEditCharacter pushes the workspace with WorkspaceBaseEnum.editor,
      // so the editor is on screen immediately — no toggle needed.
      await tapEditOnCharacterTile(tester, kSeedCharacterName);

      // EditorBasic wraps Description in TextFieldCard.multiLine with
      // showTokenCount:true, which renders the label as 'Description - N
      // tokens'. Match on the widget's `label` property instead of text.
      final descCard = find.byWidgetPredicate(
        (w) => w is TextFieldCard && w.label == 'Description',
      );
      expect(
        descCard,
        findsOneWidget,
        reason: 'editor should show the Description TextFieldCard',
      );
      final descInput = find.descendant(
        of: descCard,
        matching: find.byType(TextFormField),
      );

      await tester.enterText(descInput, sentinel);
      await tester.pump();
      await dismissKeyboard(tester);

      // Capture the service from the editor context BEFORE we pop, so the
      // post-pop reload doesn't depend on still finding the old context.
      final characterService = tester
          .element(descCard)
          .read<CharacterService>();

      // Leave the editor → PopScope flushes pending edits to PNG. No need
      // to wait for the 1s autosave debounce first; the flush handles it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byType(CharacterGridItem),
        findsAtLeastNWidgets(1),
        reason: 'should be back on the grid after popping the editor',
      );

      // Force a fresh disk read. After this call the in-memory card is a
      // fresh object whose card.description equals whatever's on disk.
      await characterService.loadCharacters();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tapEditOnCharacterTile(tester, kSeedCharacterName);

      // Read back: pull the live TextFormField's controller text and
      // compare to the sentinel.
      final descCard2 = find.byWidgetPredicate(
        (w) => w is TextFieldCard && w.label == 'Description',
      );
      final descInput2 = find.descendant(
        of: descCard2,
        matching: find.byType(TextFormField),
      );
      final loadedField = tester.widget<TextFormField>(descInput2);
      final loadedText = loadedField.controller!.text;

      expect(
        loadedText,
        sentinel,
        reason:
            'Description must equal the sentinel after disk reload — proves '
            'the edit reached PNG/JSON and was read back from disk, not '
            'just retained in memory',
      );
    },
  );
}
