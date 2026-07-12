import 'dart:convert';

import 'package:cardwave/editor/src/pages/widgets/code_find_panel_view.dart';
import 'package:cardwave/editor/src/pages/widgets/code_selection_toolbar_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// Fullscreen raw-JSON editor for a card's whole `cardwave_nodes` block,
/// opened from the structured nodes panel. A second way in for experts:
/// the structured form stays the primary editor. Validation reuses the
/// same loader the panel uses, so what the form rejects the raw editor
/// rejects too; problems show in a list beneath the editor because
/// re_editor cannot draw inline marks. The panel owns the write, so this
/// page hands back a parsed extension instead of touching the card.
class NodesRawEditorPage extends StatefulWidget {
  const NodesRawEditorPage({
    required this.initialJson,
    required this.onSaved,
    super.key,
  });

  final String initialJson;

  /// Called with the validated extension when the author saves. The panel
  /// owns the strip-and-write path so it stays in one place.
  final ValueChanged<CardNodesExtension> onSaved;

  @override
  State<NodesRawEditorPage> createState() => _NodesRawEditorState();
}

class _NodesRawEditorState extends State<NodesRawEditorPage> {
  /// Shown when [FormatException] omits a character offset.
  static const String _unknownOffset = 'unknown';

  final CodeLineEditingController _controller = CodeLineEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Supplies the cut/copy/paste/select-all menu re_editor leaves to the host.
  final CodeSelectionToolbarController _selectionToolbar =
      CodeSelectionToolbarController();

  /// Live problems, republished on every edit. Held in a [ValueNotifier]
  /// so only the list beneath the editor rebuilds. A page-wide setState
  /// per keystroke would let the platform IME push its cached value back
  /// during the rebuild and overwrite typed text (the same reason the
  /// per-node editor avoids setState on its predicate field).
  final ValueNotifier<List<CardExtensionLoadError>> _problems =
      ValueNotifier(const []);

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialJson;
    _controller.addListener(_revalidate);
    _problems.value = _validate(widget.initialJson).errors;
  }

  @override
  void dispose() {
    _controller.removeListener(_revalidate);
    _controller.dispose();
    _focusNode.dispose();
    _problems.dispose();
    _selectionToolbar.dispose();
    super.dispose();
  }

  void _revalidate() => _problems.value = _validate(_controller.text).errors;

  /// Validates the editor text in two layers: JSON syntax via [jsonDecode],
  /// then shape and meaning via the loader (predicate field paths,
  /// emotion-baseline bounds). [extension] is the parsed block, non-null
  /// only when the text is a JSON object the loader could read; it is safe
  /// to save when [errors] is empty. A bare array or number is valid JSON
  /// but a wrong top level, caught before the loader runs.
  ({List<CardExtensionLoadError> errors, CardNodesExtension? extension})
      _validate(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return (
          errors: [
            CardExtensionLoadError(
              path: 'root',
              message: t.editor.nodesRawEditorPage.topLevelMustBeObject,
            ),
          ],
          extension: null,
        );
      }
      final result = loadCardNodesExtension(decoded);
      return (errors: result.errors, extension: result.extension);
    } on FormatException catch (e) {
      final where = e.offset == null ? _unknownOffset : 'char ${e.offset}';
      return (
        errors: [CardExtensionLoadError(path: where, message: e.message)],
        extension: null,
      );
    }
  }

  void _onSave() {
    final result = _validate(_controller.text);
    if (result.errors.isNotEmpty) {
      _problems.value = result.errors;
      return;
    }
    widget.onSaved(result.extension!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.editor.nodesRawEditorPage.editNodesJsonTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              key: const Key('nodes-raw-editor-save-button'),
              onPressed: _onSave,
              child: Text(t.common.actions.save),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CodeEditor(
              controller: _controller,
              focusNode: _focusNode,
              toolbarController: _selectionToolbar,
              autofocus: true,
              wordWrap: false,
              style: CodeEditorStyle(
                fontFamily: 'monospace',
                backgroundColor: cs.surface,
                textColor: cs.onSurface,
                cursorColor: cs.primary,
                selectionColor: cs.primary.withValues(alpha: 0.3),
                codeTheme: CodeHighlightTheme(
                  languages: {'json': CodeHighlightThemeMode(mode: langJson)},
                  theme: dark ? atomOneDarkTheme : atomOneLightTheme,
                ),
              ),
              indicatorBuilder:
                  (context, editingController, chunkController, notifier) => Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editingController,
                    notifier: notifier,
                  ),
                  DefaultCodeChunkIndicator(
                    width: 20,
                    controller: chunkController,
                    notifier: notifier,
                  ),
                ],
              ),
              findBuilder: (context, controller, readOnly) =>
                  CodeFindPanelView(controller: controller, readOnly: readOnly),
            ),
          ),
          _RawEditorProblemList(problems: _problems),
        ],
      ),
    );
  }
}

/// Problem list shown beneath the editor, matching the structured panel's
/// load-error banner. Driven by a [ValueListenable] so it rebuilds without
/// rebuilding the editor.
class _RawEditorProblemList extends StatelessWidget {
  const _RawEditorProblemList({required this.problems});

  final ValueListenable<List<CardExtensionLoadError>> problems;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<CardExtensionLoadError>>(
      valueListenable: problems,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: Card(
            margin: const EdgeInsets.all(8),
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.editor.nodesRawEditorPage.fixProblemsMessage(
                        n: list.length,
                      ),
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    for (final error in list)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• $error',
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
