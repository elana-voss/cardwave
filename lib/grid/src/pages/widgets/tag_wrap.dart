import 'package:flutter/material.dart';

/// A `Wrap` of [FilterChip]s, one per tag (label = `"tag (count)"`).
/// Selection state is owned by the parent: [currentSelection] is read
/// only, and toggling a chip calls [onToggle] with the tag and its new
/// selected state.
class TagWrap extends StatelessWidget {
  const TagWrap({
    required this.tags,
    required this.currentSelection,
    required this.onToggle,
    super.key,
  });
  final List<MapEntry<String, int>> tags;
  final Set<String> currentSelection;
  final void Function(String tag, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((e) {
        return FilterChip(
          label: Text('${e.key} (${e.value})'),
          selected: currentSelection.contains(e.key),
          onSelected: (selected) => onToggle(e.key, selected),
        );
      }).toList(),
    );
  }
}
