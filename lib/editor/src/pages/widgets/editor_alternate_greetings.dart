import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorAlternateGreetings extends StatefulWidget {
  const EditorAlternateGreetings({
    required this.characterCard,
    required this.onChanged,
    super.key,
  });
  final CharacterCardV3 characterCard;
  final VoidCallback onChanged;

  @override
  State<EditorAlternateGreetings> createState() =>
      EditorAlternateGreetingsState();
}

class EditorAlternateGreetingsState extends State<EditorAlternateGreetings> {
  final List<TextEditingController> _controllers = [];
  FocusNode? _newEntryFocusNode;

  @override
  void initState() {
    super.initState();

    final firstMesController = TextEditingController(
      text: widget.characterCard.firstMes,
    );
    firstMesController.onTextChanged(_updateCard);
    _controllers.add(firstMesController);

    for (final greeting in widget.characterCard.alternateGreetings) {
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
    if (_controllers.isNotEmpty) {
      widget.characterCard.firstMes = _controllers.first.text;
      widget.characterCard.alternateGreetings = _controllers
          .skip(1)
          .map((c) => c.text)
          .toList();
    } else {
      widget.characterCard.firstMes = '';
      widget.characterCard.alternateGreetings = [];
    }
    widget.onChanged();
  }

  void _addGreeting() {
    setState(() {
      _newEntryFocusNode = FocusNode();
      final controller = TextEditingController();
      controller.onTextChanged(_updateCard);
      _controllers.add(controller);
      _updateCard();
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
      title: 'Delete Greeting',
      message: 'Are you sure you want to delete this greeting?',
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      final controller = _controllers.removeAt(index);
      controller.dispose();
      _updateCard();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _addGreeting,
              icon: const Icon(Icons.add),
              label: const Text('Add Greeting'),
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
                  label: i == 0
                      ? 'Primary Greeting (first_mes)'
                      : 'Alternate Greeting #$i',
                  showTokenCount: true,
                  headerLeading: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_indicator),
                  ),
                  headerTrailing: i > 0
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => unawaited(_removeGreeting(i)),
                          tooltip: 'Remove',
                        )
                      : null,
                  trailing: Builder(
                    builder: (_) {
                      final fieldName = i == 0
                          ? 'Primary Greeting (first_mes)'
                          : 'Alternate Greeting #$i';
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
