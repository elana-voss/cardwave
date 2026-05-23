import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/editor/src/pages/widgets/lorebook_entry_editor_page.dart';
import 'package:cardwave/editor/src/pages/widgets/lorebook_entry_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LorebookEditorWidget extends StatefulWidget {
  const LorebookEditorWidget({
    required this.isAdvancedMode,
    required this.onAdvancedModeToggled,
    required this.onChanged,
    super.key,
    this.characterFile,
  });
  final CharacterFile? characterFile;
  final bool isAdvancedMode;
  final ValueChanged<bool> onAdvancedModeToggled;
  final VoidCallback onChanged;

  @override
  State<LorebookEditorWidget> createState() => LorebookEditorWidgetState();
}

class LorebookEditorWidgetState extends State<LorebookEditorWidget> {
  static const int _defaultProbability = 100;
  static const int _defaultDepth = 4;
  static const int _defaultGroupWeight = 100;
  static const int _defaultScanDepth = 4;
  static const int _defaultPosition = 0;
  static const int _defaultInsertionOrder = 100;

  /// `widget.characterFile` unwrapped — valid only when it's non-null. The
  /// editor only opens with a card; `_addEntry` guards explicitly, and the
  /// list-tile callbacks (`_deleteEntry` / `_onReorder` / `_openEntryEditor`)
  /// can only fire when entries are shown, which requires a non-null card.
  CharacterFile get _file => widget.characterFile!;

  /// The card's lorebook unwrapped — valid only when `_file.card.lorebook
  /// != null`, i.e. inside `_addEntry`'s else-branch (after the
  /// create-if-missing check) and in the list-tile callbacks (which only
  /// fire when there are entries to act on).
  Lorebook get _lorebook => _file.card.lorebook!;

  void _addEntry() {
    if (widget.characterFile == null) return;

    final entry = LorebookEntry();
    entry.id = DateTime.now()
        .millisecondsSinceEpoch; // Ensures Timed Effects function correctly
    entry.enabled = true;
    entry.selective = true;
    entry.constant = false;
    entry.useProbability = true;
    entry.insertionOrder = _defaultInsertionOrder;
    entry.keys = [];
    entry.secondaryKeys = [];
    entry.content = '';
    entry.comment = 'New Entry';
    entry.extensions = LorebookEntryExtensions(
      probability: _defaultProbability,
      depth: _defaultDepth,
      groupWeight: _defaultGroupWeight,
      scanDepth: _defaultScanDepth,
      position: _defaultPosition,
    );

    setState(() {
      if (_file.card.lorebook == null) {
        _file.card.lorebook = Lorebook(entries: [entry]);
      } else {
        _lorebook.entries.add(entry);
      }
    });
    widget.onChanged();
  }

  Future<void> _deleteEntry(int index) async {
    final controller = context.read<EditorPageController>();
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await controller.confirmDelete(
      title: 'Delete Entry',
      message: 'Are you sure you want to delete this entry?',
      confirmColor: errorColor,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _lorebook.entries.removeAt(index);
      widget.onChanged();
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final entries = _lorebook.entries;
      final item = entries.removeAt(oldIndex);
      entries.insert(newIndex, item);
    });
    widget.onChanged();
  }

  void _openEntryEditor(LorebookEntry entry) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) {
            return LorebookEntryEditorPage(
              entry: entry,
              contextCard: _file.card,
              isAdvancedMode: widget.isAdvancedMode,
              onAdvancedModeToggled: widget.onAdvancedModeToggled,
              onChanged: () {
                setState(() {});
                widget.onChanged();
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lorebook = widget.characterFile?.card.lorebook;
    final entries = lorebook?.entries;
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true, // Crucial: Removes extra vertical whitespace
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        checkboxTheme: theme.checkboxTheme.copyWith(
          visualDensity: VisualDensity.compact,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        ),
        chipTheme: theme.chipTheme.copyWith(showCheckmark: false),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const Key('lorebook-add-entry'),
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Entry'),
                  ),
                ),
              ],
            ),
          ),
          if (entries == null || entries.isEmpty)
            const Center(child: Text('No lorebook entries found.'))
          else
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: entries.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return LorebookEntryListTile(
                    key: ValueKey(identityHashCode(entry)),
                    entry: entry,
                    index: index,
                    onDelete: () => unawaited(_deleteEntry(index)),
                    onTap: () => _openEntryEditor(entry),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
