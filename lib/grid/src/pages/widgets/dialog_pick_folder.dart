import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Folder picker dialog rendering the directory hierarchy as a fully-expanded
/// tree of compact rows. Used by the grid's folder filter.
///
/// Exempted from the CLAUDE.md "ListTile rows inside AppDialog" picker rule:
/// ListTile's ~56px row height limits a tree to 6-8 visible folders at once,
/// defeating the point of seeing structure. Compact ~32px rows fit most real
/// folder trees without scrolling.
///
/// The dialog has no "no filter" pseudo-row — the bottom-left "Clear All"
/// button is the only path to reset the filter, mirroring the Tag and Creator
/// multi-select dialogs.
class DialogPickFolder extends StatefulWidget {
  const DialogPickFolder({
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.allFoldersKey,
    super.key,
  });

  /// Map of full folder path → card count. The "no folder filter" entry
  /// (identified by [allFoldersKey]) is hidden from the row list — Clear All
  /// is the only path to that state.
  final Map<String, int> items;
  final String title;
  final String selectedItem;

  /// Map key the caller uses to mean "no folder filter" (the filter
  /// controller's `allDirectories` constant). The dialog hides the matching
  /// entry from the list and pops with this value when Clear All is tapped.
  final String allFoldersKey;

  @override
  State<DialogPickFolder> createState() => _DialogPickFolderState();
}

class _DialogPickFolderState extends State<DialogPickFolder> {
  final _searchController = TextEditingController();
  late List<MapEntry<String, int>> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = _entriesWithoutAllFolders().toList();
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterItems);
    _searchController.dispose();
    super.dispose();
  }

  Iterable<MapEntry<String, int>> _entriesWithoutAllFolders() =>
      widget.items.entries.where((e) => e.key != widget.allFoldersKey);

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredItems = _entriesWithoutAllFolders().toList());
      return;
    }
    final matchingPaths = <String>{};
    for (final entry in _entriesWithoutAllFolders()) {
      if (entry.key.toLowerCase().contains(query)) {
        matchingPaths.add(entry.key);
        var parent = p.posix.dirname(entry.key);
        while (parent != '.' && parent.isNotEmpty) {
          matchingPaths.add(parent);
          parent = p.posix.dirname(parent);
        }
      }
    }
    setState(() {
      _filteredItems = _entriesWithoutAllFolders()
          .where((e) => matchingPaths.contains(e.key))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCleared = widget.selectedItem == widget.allFoldersKey;
    return AppDialog(
      isScrollable: false,
      actions: [
        TextButton(
          onPressed: isCleared
              ? null
              : () => Navigator.of(context).pop(widget.allFoldersKey),
          child: Text(t.grid.dialogActions.clearAll),
        ),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          AppSearchField(controller: _searchController),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final entry = _filteredItems[index];
                return _FolderRow(
                  path: entry.key,
                  count: entry.value,
                  isSelected: entry.key == widget.selectedItem,
                  onTap: () => Navigator.of(context).pop(entry.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.path,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String path;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  static const _rowHeight = 32.0;
  static const _indentPerLevel = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = path.split('/');
    final depth = parts.length - 1;
    // `String.split` always returns at least one element.
    // ignore: qcheck/avoid_unsafe_collection_methods
    final displayName = parts.last;

    final isDisabled = count == 0 && !isSelected;

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: SizedBox(
          height: _rowHeight,
          child: Padding(
            padding: EdgeInsets.only(
              left: 8 + depth * _indentPerLevel,
              right: 8,
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: isDisabled
                      ? theme.disabledColor
                      : (isSelected ? theme.colorScheme.primary : null),
                ),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isDisabled
                          ? theme.disabledColor
                          : (isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : null),
                    ),
                  ),
                ),
                _CountBadge(
                  count: count,
                  isSelected: isSelected,
                  isDisabled: isDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.isSelected,
    required this.isDisabled,
  });

  final int count;
  final bool isSelected;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : (isDisabled
                  ? theme.colorScheme.surfaceContainerLow
                  : theme.colorScheme.surfaceContainerHigh),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSelected
              ? theme.colorScheme.primary
              : (isDisabled ? theme.disabledColor : null),
        ),
      ),
    );
  }
}
