import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_nodes.dart';
import 'package:cardwave/editor/src/pages/widgets/editor_view.dart';
import 'package:cardwave/editor/src/pages/widgets/node_editor_form.dart';
import 'package:cardwave/editor/src/pages/widgets/node_list_tile.dart';
import 'package:cardwave/editor/src/pages/widgets/panel_enum.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/main.dart' as app;
import 'package:cardwave/nodes/nodes.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// Node editor round-trip. Opens the editor on Cass, switches to the
/// Nodes panel, types into the engine-seed goal field, adds an
/// authored node, opens its editor page, sets a predicate and a
/// narrative payload, leaves, forces a fresh disk read, then asserts
/// every typed value is back in `card.extensions['cardwave_nodes']`.
///
/// Catches regressions in:
///   - PanelEnum.nodes wiring (tab + rail + switch case → EditorNodes)
///   - engine-seed goal field auto-save
///   - "Add Node" path: button → mutated authoredNodes → list row
///   - tap on a NodeListTile opens the NodeEditorForm dialog
///   - predicate field auto-save (live `findPredicateProblems` runs
///     on every keystroke; should not block persistence)
///   - narrative payload auto-save
///   - PopScope flush serializes `cardwave_nodes` correctly through
///     `CardNodesExtension.toJson`
///   - runtime-field stripping (no leaked session state in saved JSON)
///
/// No LLM calls — the editor never contacts a model, so no API key
/// is required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Node editor — engine seed + authored node survive disk round-trip',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Open Cass in editor mode (auto-copied by CharacterService).
      await tapEditOnCharacterTile(tester, kCassName);

      // Switch to the Nodes panel. The scrollable TabBar would put
      // 'Nodes' off-screen on the Pixel 6 viewport (5+ tabs), so
      // toggling the panel through `EditorPageController` is more
      // reliable than driving the tab tap. `WorkspacePage`'s
      // `Consumer3<EditorPageController>` re-passes the new
      // `selectedPanel` into `EditorView` on notify.
      final editorController = tester
          .element(find.byType(EditorView))
          .read<EditorPageController>();
      editorController.setSelectedPanel(PanelEnum.nodes);
      await tester.pumpAndSettle();
      final panelSwapException = tester.takeException();
      if (panelSwapException != null) {
        fail('Panel switch to Nodes threw: $panelSwapException');
      }
      expect(
        find.byType(EditorNodes),
        findsOneWidget,
        reason: 'controller swap should render the EditorNodes panel',
      );

      // Engine seed: fresh card → no extension → the ExpansionTile
      // starts expanded (per `initiallyExpanded: nodes.isEmpty`), so
      // the Initial goal field is on screen.
      const goalSentinel = 'meet the stranger at the tavern';
      final goalCard = find.byWidgetPredicate(
        (w) => w is TextFieldCard && w.label == 'Initial goal',
      );
      expect(
        goalCard,
        findsOneWidget,
        reason: 'Nodes panel should expose the engine-seed Initial goal field',
      );
      await tester.enterText(
        find.descendant(of: goalCard, matching: find.byType(TextFormField)),
        goalSentinel,
      );
      await tester.pump();
      await dismissKeyboard(tester);

      // Two defensive cleanups before tapping UI below the fold:
      //
      // 1. The editor route push can fly a widget with a `Tooltip`
      //    through the Hero animation. `Tooltip` looks up its `Overlay`
      //    ancestor at build time, but the in-flight Hero overlay isn't
      //    an `Overlay` — Flutter throws "No Overlay widget found".
      //    The error is harmless to the running app but the debug
      //    OverlayError FAB latches on and sits in front of buttons,
      //    so `tester.tap` lands on the FAB instead of the real button.
      // 2. Any latent snackbar at the bottom of the screen intercepts
      //    hit-tests on whatever is rendered behind it.
      await dismissDebugErrorFab(tester);
      await clearSnackBars(tester);

      // Engine seed is initially expanded on an empty card, so on a phone
      // viewport the Add Node button can land below the visible area.
      // The panel is wrapped in EditorScrollablePanel (a
      // SingleChildScrollView) so `ensureVisible` scrolls the button
      // into view before tapping.
      final addButton = find.byKey(const Key('editor-nodes-add-button'));
      expect(
        addButton,
        findsOneWidget,
        reason: 'Add Node button should be in the panel widget tree',
      );
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(
        find.byType(NodeListTile),
        findsOneWidget,
        reason: 'Add Node should produce exactly one list row',
      );

      // The new list row is appended at the bottom of the scrollable
      // panel, also potentially below the visible area. The snackbar
      // can also re-appear during the rebuild, so clear again first.
      await clearSnackBars(tester);
      final firstTile = find.byType(NodeListTile).first;
      await tester.ensureVisible(firstTile);
      await tester.pumpAndSettle();

      // Open the per-node editor dialog.
      await tester.tap(firstTile);
      await tester.pumpAndSettle();
      expect(
        find.byType(NodeEditorForm),
        findsOneWidget,
        reason: 'tapping the tile should open the NodeEditorForm dialog',
      );

      // Set the predicate + narrative payload directly on their
      // controllers instead of `tester.enterText`. Why: on the Android
      // emulator, `enterText` routes through the platform IME, which
      // caches each field's initial value when focus opens it. When
      // focus shifts between two multi-line fields, the real IME can
      // asynchronously push its cached value back through the
      // platform channel — overwriting whatever the test typed.
      // This is a known Flutter integration-test quirk (the real IME
      // and `TestTextInput` mock both write to the same channel) and
      // is not visible to real users. Direct controller writes fire
      // the same listeners the production code uses, without the IME.
      const predicateSentinel = 'character.cass.emotion.joy > 0.5';
      final predicateField = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is TextFieldCard && w.label == 'Predicate',
        ),
        matching: find.byType(TextFormField),
      );
      tester.widget<TextFormField>(predicateField).controller!.text =
          predicateSentinel;
      await tester.pump();

      const payloadSentinel = 'She finally returns the smile.';
      final narrativeField = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is TextFieldCard && w.label == 'Narrative payload',
        ),
        matching: find.byType(TextFormField),
      );
      tester.widget<TextFormField>(narrativeField).controller!.text =
          payloadSentinel;
      await tester.pump();

      // Capture CharacterService BEFORE dismissing so the reload does
      // not depend on the editor's element still being mounted.
      final characterService = tester
          .element(find.byType(NodeEditorForm))
          .read<CharacterService>();

      // Dismiss the per-node editor dialog back to the Nodes panel.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Pop the editor back to the grid; PopScope flushes any pending
      // PNG write the autosave debounce hadn't yet flushed.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.byType(CharacterGridItem),
        findsAtLeastNWidgets(1),
        reason: 'should be back on the grid after popping the editor',
      );

      // Force a fresh disk read so subsequent inspection reflects only
      // what was persisted — not the in-memory mutation we did.
      await characterService.loadCharacters();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Inspect Cass's reloaded card. The editor writes to
      // `extensions[nodesCardExtensionKey]` via `CardNodesExtension.toJson`;
      // the disk reload parses the same key back via `fromJson`.
      // The test seeds onboarding-complete with only the bundled
      // assistant, so `characterFiles` has exactly one entry — pull
      // it directly. Asserting on the count gives a clear failure
      // message if the reload state is wrong.
      final files = characterService.characterFiles;
      expect(
        files,
        hasLength(1),
        reason:
            'expected exactly the bundled Cass card after reload, '
            'got: ${files.map((f) => f.card.displayName).toList()}',
      );
      final reloaded = files.first;
      final raw = reloaded.card.extensions[nodesCardExtensionKey];
      expect(
        raw,
        isA<Map<String, dynamic>>(),
        reason: 'the editor should have written a cardwave_nodes block',
      );
      final extension =
          CardNodesExtension.fromJson(raw! as Map<String, dynamic>);

      // Engine seed.
      expect(extension.initialGoal, goalSentinel,
          reason: 'engine-seed Initial goal must persist');

      // Authored node + the two fields we typed on its page.
      expect(extension.authoredNodes, hasLength(1),
          reason: 'the added node must persist');
      final saved = extension.authoredNodes.first;
      expect(saved.predicate, predicateSentinel,
          reason: 'predicate field must persist verbatim');
      expect(saved.narrativePayload, payloadSentinel,
          reason: 'narrative payload must persist verbatim');

      // Runtime-field stripping: the saved JSON must look like a
      // freshly-authored node (no leaked session state). New-node
      // defaults are delay=0, cooldown=0, sticky=0, alive=-1, so the
      // current_* fields should equal those constructor defaults.
      expect(saved.currentDelay, 0,
          reason: 'currentDelay must equal delay default after strip');
      expect(saved.currentCooldown, 0,
          reason: 'currentCooldown must equal 0 after strip');
      expect(saved.currentSticky, 0,
          reason: 'currentSticky must equal 0 after strip');
      expect(saved.currentAlive, -1,
          reason: 'currentAlive must equal alive default after strip');
    },
  );
}
