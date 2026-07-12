import 'dart:io';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Mounts a host that opens the approval dialog on tap, captures the
/// popped value into [out], and pumps until the dialog is on screen.
Future<void> _hostAndOpen(
  WidgetTester tester,
  List<CardEditProposal> proposals,
  _PoppedRef out,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsService>.value(
      value: SettingsService(),
      child: TranslationProvider(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    out.value = await showDialog<List<ApprovalDecision>>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          DialogCardEditApproval(proposals: proposals),
                    );
                    out.completed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(DialogCardEditApproval).evaluate().isNotEmpty) return;
  }
  fail('approval dialog never mounted');
}

Future<void> _pumpUntilCompleted(
  WidgetTester tester,
  _PoppedRef out, {
  int maxFrames = 40,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (out.completed) return;
  }
  fail('dialog never popped (waited ${maxFrames * step.inMilliseconds}ms)');
}

class _PoppedRef {
  List<ApprovalDecision>? value;
  bool completed = false;
}

void main() {
  // SettingsRepository uses `late final` for its app-data path, so the
  // singleton can only be initialised once per process. The temp dir is
  // created in setUpAll; each test resets the flags it depends on.
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('cardedit_dialog_test_');
    await SettingsService().init(tempDir.path);
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() {
    final s = SettingsService().settings;
    s.assistantCardEditRequireApprovalForEdits = false;
    s.assistantCardEditRequireApprovalForAdditions = false;
    s.assistantCardEditRequireApprovalForDeletions = true;
  });

  testWidgets('Approve-all + Confirm returns approved=true for every row',
      (tester) async {
    final proposals = <CardEditProposal>[
      const CardScalarSetProposal(
        field: CardFieldScalar.description,
        oldValue: 'old desc',
        newValue: 'new desc',
      ),
      const CardListSetProposal(
        field: CardFieldList.alternateGreeting,
        index: 0,
        oldValue: 'old greet',
        newValue: 'new greet',
      ),
      const CardListAppendProposal(
        field: CardFieldList.tag,
        newValue: 'fantasy',
      ),
      const CardListDeleteProposal(
        field: CardFieldList.tag,
        index: 0,
        oldValue: 'drop me',
      ),
    ];

    final out = _PoppedRef();
    await _hostAndOpen(tester, proposals, out);

    await tester.tap(find.text('Approve all'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Confirm'));
    await _pumpUntilCompleted(tester, out);

    expect(out.value, isNotNull);
    expect(out.value!, hasLength(4));
    for (final d in out.value!) {
      expect(d.approved, isTrue);
      expect(d.reason, isNull);
    }
  });

  testWidgets('Per-row deny + reason returns approved=false with text',
      (tester) async {
    final proposals = <CardEditProposal>[
      const CardScalarSetProposal(
        field: CardFieldScalar.description,
        oldValue: 'old desc',
        newValue: 'new desc',
      ),
      const CardScalarSetProposal(
        field: CardFieldScalar.personality,
        oldValue: 'old pers',
        newValue: 'new pers',
      ),
    ];

    final out = _PoppedRef();
    await _hostAndOpen(tester, proposals, out);

    final toggleIcons = find.byWidgetPredicate(
      (w) =>
          w is IconButton &&
          (w.icon is Icon) &&
          ((w.icon as Icon).icon == Icons.check_circle ||
              (w.icon as Icon).icon == Icons.radio_button_unchecked),
    );
    expect(toggleIcons, findsNWidgets(2));
    await tester.tap(toggleIcons.at(1));
    await tester.pump(const Duration(milliseconds: 100));

    final reasonField = find.byType(TextField);
    expect(reasonField, findsOneWidget);
    await tester.enterText(reasonField, 'wrong tone');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Confirm'));
    await _pumpUntilCompleted(tester, out);

    expect(out.value, isNotNull);
    expect(out.value!, hasLength(2));
    expect(out.value![0].approved, isTrue);
    expect(out.value![0].reason, isNull);
    expect(out.value![1].approved, isFalse);
    expect(out.value![1].reason, 'wrong tone');
  });

  testWidgets(
      "Don't ask again for deletions button flips the settings flag",
      (tester) async {
    expect(
      SettingsService().settings.assistantCardEditRequireApprovalForDeletions,
      isTrue,
      reason: 'default for deletions is true (aggressive default)',
    );

    final proposals = <CardEditProposal>[
      const CardListDeleteProposal(
        field: CardFieldList.tag,
        index: 0,
        oldValue: 'old tag',
      ),
    ];

    final out = _PoppedRef();
    await _hostAndOpen(tester, proposals, out);

    final dontAskButton = find.textContaining("Don't ask again");
    expect(dontAskButton, findsOneWidget);
    await tester.tap(dontAskButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      SettingsService().settings.assistantCardEditRequireApprovalForDeletions,
      isFalse,
    );
  });
}
