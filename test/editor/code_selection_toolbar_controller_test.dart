import 'package:cardwave/editor/src/pages/widgets/code_selection_toolbar_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  late CodeSelectionToolbarController toolbar;
  late CodeLineEditingController code;

  setUp(() {
    toolbar = CodeSelectionToolbarController();
    code = CodeLineEditingController.fromText('one\ntwo\nthree');
  });

  tearDown(() {
    toolbar.dispose();
    code.dispose();
  });

  // Pumps a host with a root overlay and returns a context under it; show()
  // inserts the menu into that overlay.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          ctx = context;
          return const SizedBox.expand();
        }),
      ),
    ));
    return ctx;
  }

  void show(BuildContext ctx) => toolbar.show(
        context: ctx,
        controller: code,
        anchors: const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(120, 120),
        ),
        layerLink: LayerLink(),
        visibility: ValueNotifier(true),
      );

  testWidgets('a range selection shows cut, copy, paste and select-all',
      (tester) async {
    final ctx = await pumpHost(tester);
    code.selection = const CodeLineSelection(
      baseIndex: 0,
      baseOffset: 0,
      extentIndex: 0,
      extentOffset: 3,
    );
    show(ctx);
    await tester.pump();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
  });

  testWidgets('a bare caret hides cut and copy but keeps paste and select-all',
      (tester) async {
    final ctx = await pumpHost(tester);
    code.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    show(ctx);
    await tester.pump();

    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Select all'), findsOneWidget);
  });

  testWidgets('Select all selects the whole document', (tester) async {
    final ctx = await pumpHost(tester);
    code.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    show(ctx);
    await tester.pump();

    await tester.tap(find.text('Select all'));
    await tester.pump();

    expect(code.selectedText, 'one\ntwo\nthree');
  });

  testWidgets('hide removes the menu', (tester) async {
    final ctx = await pumpHost(tester);
    show(ctx);
    await tester.pump();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);

    toolbar.hide(ctx);
    await tester.pump();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
  });
}
