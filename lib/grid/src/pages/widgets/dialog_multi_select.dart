import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class DialogMultiSelect extends StatefulWidget {
  const DialogMultiSelect({
    required this.title,
    required this.items,
    required this.selectedItems,
    super.key,
    this.dynamicItemsCallback,
  });
  final String title;
  final Map<String, int> items;
  final Set<String> selectedItems;
  final Future<Map<String, int>> Function(Set<String>)? dynamicItemsCallback;

  @override
  State<DialogMultiSelect> createState() => _DialogMultiSelectState();
}

class _DialogMultiSelectState extends State<DialogMultiSelect> {
  static const _initialDisplayLimit = 200;
  static const _displayLimitIncrement = 200;

  final TextEditingController _searchController = TextEditingController();
  late final Map<String, String> _lowerCaseKeys;

  late Set<String> _currentSelection;
  late List<MapEntry<String, int>> _sortedItems;
  int _displayLimit = _initialDisplayLimit;

  @override
  void initState() {
    super.initState();
    _lowerCaseKeys = Map.fromEntries(
      widget.items.keys.map((k) => MapEntry(k, k.toLowerCase())),
    );
    _currentSelection = Set<String>.of(widget.selectedItems);

    // Sort order is anchored to widget.items so chips don't leap around as the
    // user toggles selection; counts refresh via the (async) callback.
    _sortedItems = _getSortedItems(widget.items);

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _displayLimit = _initialDisplayLimit);
  }

  List<MapEntry<String, int>> _getSortedItems(Map<String, int> itemsMap) {
    return widget.items.keys.map((key) {
      return MapEntry(key, itemsMap[key] ?? 0);
    }).toList()..sort((a, b) {
      final countCompare = (widget.items[b.key] ?? 0).compareTo(
        widget.items[a.key] ?? 0,
      );
      if (countCompare != 0) return countCompare;
      return _lowerCaseKeys[a.key]!.compareTo(_lowerCaseKeys[b.key]!);
    });
  }

  void _toggleSelection(String key, bool selected) {
    setState(() {
      if (selected) {
        _currentSelection.add(key);
      } else {
        _currentSelection.remove(key);
      }
    });
    unawaited(_refreshDynamicCounts());
  }

  void _clearSelection() {
    setState(() {
      _searchController.clear();
      _displayLimit = _initialDisplayLimit;
      _currentSelection = {};
    });
    unawaited(_refreshDynamicCounts());
  }

  Future<void> _refreshDynamicCounts() async {
    final callback = widget.dynamicItemsCallback;
    if (callback == null) return;
    final items = await callback(_currentSelection);
    if (!mounted) return;
    setState(() => _sortedItems = _getSortedItems(items));
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final theme = Theme.of(context);
    return AppDialog(
      isScrollable: false,
      actions: [
        TextButton(
          onPressed: _currentSelection.isEmpty ? null : _clearSelection,
          child: Text(t.grid.dialogActions.clearAll),
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentSelection),
          child: Text(t.grid.dialogActions.apply),
        ),
      ],
      // Non-uniform: `SizedBox(16)` and conditional `SizedBox(12)`;
      // single `spacing:` can't express both.
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          AppSearchField(controller: _searchController),
          if (_currentSelection.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final item in _currentSelection)
                    InputChip(
                      label: Text(item),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      side: BorderSide.none,
                      onPressed: () => _toggleSelection(item, false),
                      onDeleted: () => _toggleSelection(item, false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 16),
          Expanded(child: _buildItemsArea(theme)),
        ],
      ),
    );
  }

  // Reads and writes the dialog's search/selection/display-limit state via
  // setState; a widget would need 6+ params including write-back callbacks.
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildItemsArea(ThemeData theme) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          t.grid.multiSelectDialog.nothingToShow,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final query = _searchController.text.toLowerCase();
    final filtered = _sortedItems
        .where((entry) => _lowerCaseKeys[entry.key]!.contains(query))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          t.grid.multiSelectDialog.noMatches,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final hasMore = filtered.length > _displayLimit;
    final displayItems = filtered.take(_displayLimit);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in displayItems)
                FilterChip(
                  showCheckmark: false,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Text(entry.key),
                      Container(
                        width: 34,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${entry.value}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  selected: _currentSelection.contains(entry.key),
                  onSelected:
                      (entry.value == 0 &&
                          !_currentSelection.contains(entry.key))
                      ? null
                      : (selected) => _toggleSelection(entry.key, selected),
                ),
            ],
          ),
          if (hasMore) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(
                () => _displayLimit += _displayLimitIncrement,
              ),
              child: Text(t.grid.multiSelectDialog.showMore),
            ),
          ],
        ],
      ),
    );
  }
}
