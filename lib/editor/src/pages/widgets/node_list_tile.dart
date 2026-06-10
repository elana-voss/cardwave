import 'package:cardwave/editor/src/pages/widgets/tag_chip.dart';
import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter/material.dart';

/// One row in the authored-nodes list. Mirrors `LorebookEntryListTile`:
/// tap opens the per-node editor, trailing icon deletes (parent does
/// the confirm), leading drag handle reorders.
///
/// The row shows the node's id, its type and scope as small chips, a
/// short preview of the predicate text, and a spawn badge when the
/// node has child nodes.
class NodeListTile extends StatelessWidget {
  const NodeListTile({
    required this.node,
    required this.index,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Node node;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Predicate text rendered next to the chips, truncated to keep the
  /// row a single line on narrow screens.
  static const int _predicatePreviewMax = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spawnCount = node.spawnIds.length;
    return ListTile(
      key: ValueKey(identityHashCode(node)),
      leading: ReorderableDragStartListener(
        index: index,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.drag_handle),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              node.displayLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TagChip(label: node.type.name),
          const SizedBox(width: 4),
          TagChip(label: node.scope.name),
          if (spawnCount > 0) ...[
            const SizedBox(width: 4),
            TagChip(label: 'spawns: $spawnCount'),
          ],
        ],
      ),
      subtitle: Text(
        _previewPredicate(node.predicate),
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }

  static String _previewPredicate(String predicate) {
    final trimmed = predicate.trim();
    if (trimmed.length <= _predicatePreviewMax) return trimmed;
    return '${trimmed.substring(0, _predicatePreviewMax - 1)}…';
  }
}

