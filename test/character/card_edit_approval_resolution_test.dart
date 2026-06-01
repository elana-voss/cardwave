import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Wires NavigationService's navigator key into a pumped host so
/// `resolveCardEditApprovals` (via the gate controller) can open the real
/// approval dialog.
Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: SettingsService(),
      child: MaterialApp(
        navigatorKey: NavigationService().navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
}

Future<void> _awaitDialog(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(DialogCardEditApproval).evaluate().isNotEmpty) return;
  }
  fail('approval dialog never mounted');
}

void main() {
  // SettingsService is a singleton with a late-final path; init once per
  // process. The dialog only reads it when "Don't ask again" is tapped, which
  // these tests never do, but the provider keeps the lookup safe.
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('card_edit_resolve_test_');
    await SettingsService().init(tempDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets('Stop during the approval dialog applies nothing', (tester) async {
    await _pumpHost(tester);

    final cancelToken = ValueNotifier(false);
    final ctx = ToolCallContext(appData: Object(), cancelToken: cancelToken);
    var applied = false;

    final future = resolveCardEditApprovals(
      writeRaw: const [ToolResult.ok()],
      proposals: const [
        CardListDeleteProposal(
          field: CardFieldList.tag,
          index: 0,
          oldValue: 'keepme',
        ),
      ],
      ctx: ctx,
      deniedKeys: <String>{},
      requireApprovalForEdits: true,
      requireApprovalForAdditions: true,
      requireApprovalForDeletions: true,
      applyApproved: (_) async => applied = true,
    );

    await _awaitDialog(tester);

    // User changes their mind: presses Stop while the dialog is open, then
    // taps Confirm out of habit (every row defaults to approved).
    cancelToken.value = true;
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    final results = await future;
    expect(
      applied,
      isFalse,
      reason: 'a write begun before Stop must not be applied',
    );
    expect(results, hasLength(1));
    expect(results.single.success, isFalse);
    cancelToken.dispose();
  });

  testWidgets(
    'Dismissing the dialog denies the whole batch, including an auto-approved edit',
    (tester) async {
      await _pumpHost(tester);

      final ctx = ToolCallContext(
        appData: Object(),
        cancelToken: ValueNotifier(false),
      );
      var applied = false;

      final future = resolveCardEditApprovals(
        writeRaw: const [ToolResult.ok(), ToolResult.ok()],
        proposals: const [
          // Edit: not gated below, so on its own it would apply with no dialog.
          CardScalarSetProposal(
            field: CardFieldScalar.description,
            oldValue: 'old',
            newValue: 'new',
          ),
          // Deletion: gated, so the dialog opens.
          CardListDeleteProposal(
            field: CardFieldList.tag,
            index: 0,
            oldValue: 'tag',
          ),
        ],
        ctx: ctx,
        deniedKeys: <String>{},
        requireApprovalForEdits: false,
        requireApprovalForAdditions: false,
        requireApprovalForDeletions: true,
        applyApproved: (_) async => applied = true,
      );

      await _awaitDialog(tester);

      // Close the dialog with the system back gesture (pop with no result).
      NavigationService().navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      final results = await future;
      expect(
        applied,
        isFalse,
        reason: 'closing the dialog cancels the whole batch, including the '
            'auto-approved edit',
      );
      expect(results.every((r) => !r.success), isTrue);
    },
  );

  test('a previously-declined change is auto-denied without a dialog', () async {
    const proposal = CardScalarSetProposal(
      field: CardFieldScalar.description,
      oldValue: 'old',
      newValue: 'new',
    );
    final deniedKeys = {cardEditProposalDedupKey(proposal)};
    var applied = false;

    final results = await resolveCardEditApprovals(
      writeRaw: const [ToolResult.ok()],
      proposals: const [proposal],
      ctx: ToolCallContext(
        appData: Object(),
        cancelToken: ValueNotifier(false),
      ),
      deniedKeys: deniedKeys,
      requireApprovalForEdits: true,
      requireApprovalForAdditions: true,
      requireApprovalForDeletions: true,
      applyApproved: (_) async => applied = true,
    );

    expect(applied, isFalse);
    expect(results.single.success, isFalse);
  });

  test('an auto-approved edit applies with no dialog', () async {
    const proposal = CardScalarSetProposal(
      field: CardFieldScalar.description,
      oldValue: 'old',
      newValue: 'new',
    );
    List<CardEditProposal>? appliedList;

    final results = await resolveCardEditApprovals(
      writeRaw: const [ToolResult.ok()],
      proposals: const [proposal],
      ctx: ToolCallContext(
        appData: Object(),
        cancelToken: ValueNotifier(false),
      ),
      deniedKeys: <String>{},
      requireApprovalForEdits: false,
      requireApprovalForAdditions: false,
      requireApprovalForDeletions: true,
      applyApproved: (a) async => appliedList = a,
    );

    expect(appliedList, isNotNull);
    expect(appliedList!.single, same(proposal));
    expect(results.single.success, isTrue);
    expect(results.single.data, 'edit applied');
  });

  test('dedup key separates by new value and by location', () {
    const a = CardScalarSetProposal(
      field: CardFieldScalar.description,
      oldValue: '',
      newValue: 'X',
    );
    const b = CardScalarSetProposal(
      field: CardFieldScalar.description,
      oldValue: '',
      newValue: 'Y',
    );
    expect(cardEditProposalDedupKey(a), isNot(cardEditProposalDedupKey(b)));

    const d0 = CardListDeleteProposal(
      field: CardFieldList.tag,
      index: 0,
      oldValue: 'x',
    );
    const d1 = CardListDeleteProposal(
      field: CardFieldList.tag,
      index: 1,
      oldValue: 'y',
    );
    expect(cardEditProposalDedupKey(d0), isNot(cardEditProposalDedupKey(d1)));
  });
}
