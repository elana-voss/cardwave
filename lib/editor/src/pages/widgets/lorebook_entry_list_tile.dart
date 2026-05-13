import 'package:cardwave/character/character.dart';
import 'package:flutter/material.dart';

class LorebookEntryListTile extends StatelessWidget {
  const LorebookEntryListTile({
    required this.entry,
    required this.index,
    required this.onDelete,
    required this.onTap,
    super.key,
  });
  final LorebookEntry entry;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (entry.comment?.isNotEmpty == true)
        ? entry.comment!
        : 'Untitled Entry';
    final keys = entry.keys.join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_indicator),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          keys.isNotEmpty ? keys : 'No keywords',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
          tooltip: 'Delete Entry',
        ),
        onTap: onTap,
      ),
    );
  }
}
