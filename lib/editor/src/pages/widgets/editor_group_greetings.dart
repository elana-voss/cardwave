import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorGroupGreetings extends StatefulWidget {
  const EditorGroupGreetings({
    required this.characterCard,
    required this.onChanged,
    super.key,
  });
  final CharacterCardV3 characterCard;
  final VoidCallback onChanged;

  @override
  State<EditorGroupGreetings> createState() => EditorGroupGreetingsState();
}

class EditorGroupGreetingsState extends State<EditorGroupGreetings> {
  final List<TextEditingController> _controllers = [];
  FocusNode? _newEntryFocusNode;

  @override
  void initState() {
    super.initState();
    for (final greeting in widget.characterCard.groupOnlyGreetings) {
      final controller = TextEditingController(text: greeting);
      controller.onTextChanged(_updateCard);
      _controllers.add(controller);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _newEntryFocusNode?.dispose();
    super.dispose();
  }

  void _updateCard() {
    widget.characterCard.groupOnlyGreetings = _controllers
        .map((c) => c.text)
        .toList();
    widget.onChanged();
  }

  void _addGreeting() {
    setState(() {
      _newEntryFocusNode = FocusNode();
      final controller = TextEditingController();
      controller.onTextChanged(_updateCard);
      _controllers.add(controller);
      widget.characterCard.groupOnlyGreetings.add('');
      widget.onChanged();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newEntryFocusNode?.requestFocus();
      _newEntryFocusNode = null;
    });
  }

  Future<void> _removeGreeting(int index) async {
    // `index` comes from the row this handler is wired to.
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (_controllers[index].text.trim().isEmpty) {
      setState(() {
        final controller = _controllers.removeAt(index);
        controller.dispose();
        _updateCard();
      });
      return;
    }

    final pageController = context.read<EditorPageController>();
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await pageController.confirmDelete(
      title: t.editor.editorAlternateGreetings.deleteGreetingTitle,
      message: t.editor.editorAlternateGreetings.deleteGreetingMessage,
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      final controller = _controllers.removeAt(index);
      controller.dispose();
      widget.characterCard.groupOnlyGreetings.removeAt(index);
      widget.onChanged();
    });
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final controller = _controllers.removeAt(oldIndex);
      _controllers.insert(newIndex, controller);
      _updateCard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _addGreeting,
              icon: const Icon(Icons.add),
              label: Text(t.editor.editorAlternateGreetings.addGreetingButton),
            ),
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: _onReorderItem,
          children: [
            for (int i = 0; i < _controllers.length; i++)
              Padding(
                key: ValueKey(_controllers[i]),
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFieldCard.multiLine(
                  focusNode: (i == _controllers.length - 1)
                      ? _newEntryFocusNode
                      : null,
                  controller: _controllers[i],
                  label: t.editor.editorGroupGreetings.greetingLabel(
                    index: i + 1,
                  ),
                  showTokenCount: true,
                  headerLeading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator),
                  ),
                  headerTrailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => unawaited(_removeGreeting(i)),
                    tooltip: t.editor.editorAlternateGreetings.removeTooltip,
                  ),
                  trailing: Builder(
                    builder: (_) {
                      final fieldName = 'Group Greeting ${i + 1}';
                      return AiActionTextfieldPopup(
                        currentText: () => _controllers[i].text,
                        onApply: aiPopupApply(
                          this,
                          _controllers[i],
                          fieldName,
                        ),
                        fieldName: fieldName,
                        contextCard: widget.characterCard,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
