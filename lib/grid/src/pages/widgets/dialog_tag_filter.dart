import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/pages/widgets/tag_wrap.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class DialogTagFilter extends StatefulWidget {
  const DialogTagFilter({
    required this.availableTags,
    required this.selectedTags,
    super.key,
  });
  final Map<String, int> availableTags;
  final Set<String> selectedTags;

  @override
  State<DialogTagFilter> createState() => _DialogTagFilterState();
}

class _DialogTagFilterState extends State<DialogTagFilter> {
  late Set<String> _currentSelection;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelection = Set<String>.of(widget.selectedTags);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final query = _searchController.text.toLowerCase();
    final filteredTags = widget.availableTags.entries.where((e) {
      return e.key.contains(query);
    }).toList();

    filteredTags.sort((a, b) {
      final aSelected = _currentSelection.contains(a.key);
      final bSelected = _currentSelection.contains(b.key);
      if (aSelected != bSelected) return aSelected ? -1 : 1;

      final countCmp = b.value.compareTo(a.value);
      if (countCmp != 0) return countCmp;
      return a.key.compareTo(b.key);
    });

    return AppDialog(
      isScrollable: false,
      actions: [
        TextButton(
          onPressed: _currentSelection.isEmpty
              ? null
              : () => setState(() => _currentSelection.clear()),
          child: Text(t.grid.dialogActions.clearAll),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context, _currentSelection),
          child: Text(t.grid.dialogActions.apply),
        ),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            t.grid.tagFilterDialog.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          AppSearchField(
            controller: _searchController,
            hintText: t.grid.tagFilterDialog.searchHint,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: TagWrap(
                tags: filteredTags,
                currentSelection: _currentSelection,
                onToggle: (tag, selected) {
                  setState(() {
                    if (selected) {
                      _currentSelection.add(tag);
                    } else {
                      _currentSelection.remove(tag);
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
