import 'package:cardwave/character/character.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_nodes.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_view.dart';
import 'package:cardwave/editor/src/pages/widgets/nodes_raw_editor_page.dart';
import 'package:cardwave/editor/src/pages/widgets/panel_enum.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import 'app_test_helpers.dart';

/// Raw-JSON nodes editor round-trip. Opens the editor on Cass, switches to
/// the Nodes panel, opens the fullscreen raw editor via its toggle, then:
///   - types invalid JSON and confirms Save is blocked and a problem is
///     shown (the editor stays open)
///   - types a valid block (goal + one authored node) and confirms Save
///     pops back to the panel and the block survives a disk reload
///
/// Catches regressions in:
///   - the "Edit JSON" toggle opening NodesRawEditorPage
///   - the two-layer validate gate (jsonDecode + loadCardNodesExtension)
///   - the save handing a parsed extension back to the panel, which writes
///     it through its own strip-and-persist path
///   - runtime-field stripping on raw save (no leaked session state)
///
/// No LLM calls — the editor never contacts a model, so no API key is
/// required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Raw nodes editor — valid JSON round-trips, invalid blocks save',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      await tapEditOnCharacterTile(tester, kCassName);

      // Switch to the Nodes panel through the controller — the scrollable
      // TabBar puts 'Nodes' off-screen on the Pixel 6 viewport, so the tab
      // tap is unreliable.
      final editorController =
          tester.element(find.byType(EditorView)).read<EditorPageController>();
      editorController.setSelectedPanel(PanelEnum.nodes);
      await tester.pumpAndSettle();
      expect(find.byType(EditorNodes), findsOneWidget);

      await dismissDebugErrorFab(tester);
      await clearSnackBars(tester);

      // Open the fullscreen raw editor.
      final rawButton = find.byKey(const Key('editor-nodes-raw-button'));
      expect(rawButton, findsOneWidget);
      await tester.ensureVisible(rawButton);
      await tester.pumpAndSettle();
      await tester.tap(rawButton);
      await tester.pumpAndSettle();
      expect(find.byType(NodesRawEditorPage), findsOneWidget);

      // The route push can fly the toggle's Tooltip through the Hero
      // animation and latch the debug overlay-error FAB in front of the
      // Save button; clear it (and any snackbar) before tapping.
      await dismissDebugErrorFab(tester);
      await clearSnackBars(tester);

      final saveButton = find.byKey(const Key('nodes-raw-editor-save-button'));
      final codeEditor = find.byType(CodeEditor);

      // First pass: invalid JSON must block save and surface a problem.
      // The editor text is set on re_editor's own controller, not via
      // `tester.enterText` — the same direct-write pattern the structured
      // editor test uses to dodge the Android IME overwrite.
      tester.widget<CodeEditor>(codeEditor).controller!.text = '{ not json';
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(
        find.byType(NodesRawEditorPage),
        findsOneWidget,
        reason: 'invalid JSON must keep the raw editor open',
      );
      expect(find.textContaining('to save.'), findsOneWidget);

      // Second pass: a valid block with one authored node + a goal.
      const goalSentinel = 'meet the stranger at the tavern';
      const predicateSentinel = 'character.cass.emotion.joy > 0.5';
      const validJson = '{'
          '"initial_goal":"$goalSentinel",'
          '"authored_nodes":[{'
          '"id":"n1","origin":"authored","type":"characterBehavior",'
          '"trigger_prob":1.0,"delay":0,"cooldown":0,"sticky":0,"alive":-1,'
          '"scope":"session","predicate":"$predicateSentinel",'
          '"narrative_payload":"She smiles."'
          '}]}';
      tester.widget<CodeEditor>(codeEditor).controller!.text = validJson;
      await tester.pump();

      // Capture CharacterService while the raw page is still mounted; the
      // save pops it.
      final characterService = tester
          .element(find.byType(NodesRawEditorPage))
          .read<CharacterService>();

      await tester.tap(saveButton);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(
        find.byType(EditorNodes),
        findsOneWidget,
        reason: 'a clean save should pop back to the Nodes panel',
      );

      // Pop the editor back to the grid; PopScope flushes the autosave.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(CharacterGridItem), findsAtLeastNWidgets(1));

      // Force a fresh disk read so inspection reflects only what persisted.
      await characterService.loadCharacters();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final files = await characterService.loadAll();
      expect(files, hasLength(1));
      final raw = files.first.card.extensions[nodesCardExtensionKey];
      expect(
        raw,
        isA<Map<String, dynamic>>(),
        reason: 'the raw save should have written a cardwave_nodes block',
      );
      final extension =
          CardNodesExtension.fromJson(raw! as Map<String, dynamic>);
      expect(extension.initialGoal, goalSentinel);
      expect(extension.authoredNodes, hasLength(1));
      final saved = extension.authoredNodes.first;
      expect(saved.predicate, predicateSentinel);
      expect(saved.currentDelay, 0, reason: 'strip still applied on raw save');
      expect(saved.currentAlive, -1, reason: 'strip still applied on raw save');
    },
  );
}
