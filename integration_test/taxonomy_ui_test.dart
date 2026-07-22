import 'package:cardwave/character/character.dart';
import 'package:cardwave/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'app_test_helpers.dart';

/// UI-driven test focused on the parts of the taxonomy editor that are
/// genuinely UI-specific:
/// 1. The full navigation chain (grid → gear menu → App Settings →
///    Taxonomy Tags) actually opens the editor dialog.
/// 2. Tapping a root group's chevron expands it.
/// 3. Tapping a SUB-group's chevron expands it — regression check for
///    `_TaxonomyNode` equality. Without nodeId-based ==/hashCode, fresh
///    `_GroupNode` instances on every `_childrenOf` call fall out of the
///    package's expansion-state set and sub-groups silently re-collapse.
/// 4. Tapping the "Add Root Group" toolbar button + submitting the form
///    actually mutates the repository — verifying the UI is wired to
///    `TaxonomyEditorController.addGroup`.
///
/// Add/edit/delete persistence and validation are covered by the
/// repo+controller back-end tests (`taxonomy_test.dart`); replicating the
/// whole chain through the UI would require scrolling a virtualized tree
/// and reading off-screen rows, which is brittle for marginal coverage.
///
/// One `testWidgets` per file because each `app.main()` re-initialises
/// late-final fields on the singleton services.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'taxonomy editor — open via settings, expand root + sub-group, add root group',
    timeout: const Timeout(Duration(minutes: 2)),
    (tester) async {
      await wipeAppData();
      await seedOnboardingComplete();
      // The grid is empty on a fresh install, but awaitGridReady waits for a
      // card to render; seed one so the home grid is ready before we open the
      // gear menu.
      await seedTestCharacter();

      app.main();
      await awaitAppReady(tester);
      await awaitGridReady(tester);

      // Grid → gear menu → App Settings → Taxonomy Tags.
      await tester.tap(find.byKey(const Key('settings-gear-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-app-settings')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await tester.tap(find.text('Taxonomy Tags'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(
        find.text('Taxonomy Editor'),
        findsOneWidget,
        reason: 'tapping the Taxonomy Tags tile should open the editor',
      );
      expect(
        find.text('Format'),
        findsOneWidget,
        reason: 'bundled seed must populate the "Format" root group',
      );

      // Expand "Format" by tapping its chevron, scoped to the row that
      // contains the "Format" label so we don't grab another group's
      // chevron.
      final formatChevron = find.descendant(
        of: find
            .ancestor(
              of: find.text('Format'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      await tester.tap(formatChevron.first);
      await tester.pumpAndSettle();
      expect(
        find.text('Single-character'),
        findsOneWidget,
        reason:
            'expanding Format should reveal its leaf tag "Single-character"',
      );

      // Expand "Source Material" → its sub-group "Established IP" → leaf
      // "Books / Literature". The sub-group expand is the regression
      // check: a few minutes ago, sub-group chevrons silently did
      // nothing because the tree's expansion-state set used object
      // identity and `_childrenOf` produced fresh instances on every
      // build.
      final sourceChevron = find.descendant(
        of: find
            .ancestor(
              of: find.text('Source Material'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      await tester.tap(sourceChevron.first);
      await tester.pumpAndSettle();
      expect(find.text('Established IP'), findsOneWidget);

      final ipChevron = find.descendant(
        of: find
            .ancestor(
              of: find.text('Established IP'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.widgetWithIcon(IconButton, Icons.chevron_right),
      );
      await tester.tap(ipChevron.first);
      await tester.pumpAndSettle();
      expect(
        find.text('Books / Literature'),
        findsOneWidget,
        reason:
            'sub-group "Established IP" must expand to show its leaves '
            '— if this fails, the _TaxonomyNode equality regression is back',
      );

      // Tap "Add Root Group" toolbar icon → submit the prefilled form.
      // Verify via the repository (the new group lives at the bottom of
      // a virtualized list, so `find.text('New Group')` is unreliable —
      // checking the repo proves the UI button reached the controller).
      await tester.tap(find.byKey(const Key('taxonomy-add-root-group')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final repo = tester
          .element(find.byType(MaterialApp))
          .read<TaxonomyRepository>();
      final added = repo.getGroup('new_group');
      expect(
        added,
        isNotNull,
        reason:
            'submitting the Add Root Group form should add the group '
            'to the repository',
      );
      expect(added?.name, 'New Group');
      expect(
        added?.parentGroupId,
        isNull,
        reason: '"Add Root Group" should add at top level',
      );

      // ----- Add sub-group via the row's Icons.create_new_folder_outlined.
      // Re-locate the Format row so we hit its specific "Add sub-group"
      // icon and not another row's. Enter unique ids in the form so we
      // don't collide with the new_group already created above.
      final formatRow = find
          .ancestor(
            of: find.text('Format'),
            matching: find.byType(Row),
          )
          .first;
      await tester.tap(
        find.descendant(
          of: formatRow,
          matching: find.widgetWithIcon(
            IconButton,
            Icons.create_new_folder_outlined,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Group ID'),
        'format_sub',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Format Sub',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final addedSub = repo.getGroup('format_sub');
      expect(
        addedSub,
        isNotNull,
        reason: 'tapping "Add sub-group" on Format should add a child group',
      );
      expect(
        addedSub?.parentGroupId,
        'format',
        reason: 'sub-group should be parented to Format',
      );

      // ----- Add a direct tag to Format via Icons.label_outline.
      final formatRowAgain = find
          .ancestor(
            of: find.text('Format'),
            matching: find.byType(Row),
          )
          .first;
      await tester.tap(
        find.descendant(
          of: formatRowAgain,
          matching: find.widgetWithIcon(IconButton, Icons.label_outline),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tag ID'),
        'fmt_extra',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Format Extra',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final addedTag = repo.getTag('fmt_extra');
      expect(
        addedTag,
        isNotNull,
        reason: 'tapping "Add tag" on Format should add a tag',
      );
      expect(
        addedTag?.groupId,
        'format',
        reason: 'added tag should belong to Format',
      );

      // ----- Edit the bundled "Multi-Character" tag via the pencil
      // icon, rename it, and verify through the repo.
      final multiRow = find
          .ancestor(
            of: find.text('Multi-Character'),
            matching: find.byType(Row),
          )
          .first;
      await tester.tap(
        find.descendant(
          of: multiRow,
          matching: find.widgetWithIcon(IconButton, Icons.edit_outlined),
        ),
      );
      await tester.pumpAndSettle();
      // Target the EditableText inside the Display name TextField
      // directly. Going through `find.widgetWithText(TextField, ...)`
      // failed in edit-mode (initial!=null) — `enterText`'s focus
      // handoff from the prior form's tear-down didn't always land,
      // and the controller text stayed on the seeded "Multi-Character".
      // An explicit tap to force focus, plus targeting the EditableText
      // by index inside the open AlertDialog, removes the ambiguity.
      final tagDialog = find.byType(AlertDialog).last;
      final fieldsInDialog = find.descendant(
        of: tagDialog,
        matching: find.byType(EditableText),
      );
      // Field order in _TagFormDialog: 0=Tag ID, 1=Display name,
      // 2=Description, 3=Synonyms.
      final displayNameField = fieldsInDialog.at(1);
      await tester.ensureVisible(displayNameField);
      await tester.pumpAndSettle();
      await tester.tap(displayNameField);
      await tester.pumpAndSettle();
      await tester.enterText(displayNameField, 'Multi-Character (renamed)');
      await tester.pumpAndSettle();
      // Diagnostic: verify the controller actually picked up the new
      // text before submitting. If this fails, the test framework's
      // focus + IME handoff dropped the input — fixing the assertion
      // below first would just hide the real issue.
      expect(
        find.text('Multi-Character (renamed)'),
        findsAtLeastNWidgets(1),
        reason: 'enterText should have updated the form field',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        repo.getTag('fmt_multi')?.tagName,
        'Multi-Character (renamed)',
        reason:
            'editing via the pencil icon should persist via the '
            'controller into the repo',
      );

      // ----- Delete the renamed tag via the trash icon. Confirmation
      // shows an AlertDialog with a "Delete tag?" title and a red
      // FilledButton labelled "Delete".
      final renamedRow = find
          .ancestor(
            of: find.text('Multi-Character (renamed)'),
            matching: find.byType(Row),
          )
          .first;
      await tester.tap(
        find.descendant(
          of: renamedRow,
          matching: find.widgetWithIcon(IconButton, Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Delete tag?'),
        findsOneWidget,
        reason: 'tag delete should pop a confirmation',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(
        repo.getTag('fmt_multi'),
        isNull,
        reason: 'confirming delete should remove the tag from the repo',
      );

      // No final "Close" tap — both the outer App Settings dialog and
      // the taxonomy editor have a `TextButton('Close')` mounted at
      // this point, which would be ambiguous. The test framework tears
      // down the widget tree at end-of-test regardless.
    },
  );
}
