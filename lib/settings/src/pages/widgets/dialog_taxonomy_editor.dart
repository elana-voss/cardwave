import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tagged-union node so the tree widget can render both groups and tags.
/// Tags are leaves; groups host both child groups and direct tags.
///
/// `==` / `hashCode` are derived from [nodeId] so the tree widget's
/// expansion-state set (a `Set<T>` it queries by `contains`) treats two
/// instances wrapping the same group / tag as the same node. Without
/// this, `_childrenOf` constructs fresh `_GroupNode` instances on every
/// rebuild and the controller can't find the user's expanded sub-groups
/// in its set, so they collapse on every redraw.
@immutable
sealed class _TaxonomyNode {
  const _TaxonomyNode();
  String get nodeId;

  @override
  bool operator ==(Object other) =>
      other is _TaxonomyNode && other.nodeId == nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

class _GroupNode extends _TaxonomyNode {
  const _GroupNode(this.group);
  final TaxonomyGroup group;
  @override
  String get nodeId => 'g:${group.groupId}';
}

class _TagNode extends _TaxonomyNode {
  const _TagNode(this.tag);
  final TaxonomyTag tag;
  @override
  String get nodeId => 't:${tag.tagId}';
}

class DialogTaxonomyEditor extends StatefulWidget {
  const DialogTaxonomyEditor({super.key});

  @override
  State<DialogTaxonomyEditor> createState() => _DialogTaxonomyEditorState();
}

class _DialogTaxonomyEditorState extends State<DialogTaxonomyEditor> {
  TaxonomyEditorController? _controller;
  TreeController<_TaxonomyNode>? _treeController;

  @override
  void initState() {
    super.initState();
    _controller = TaxonomyEditorController(
      context.read<TaxonomyRepository>(),
    );
    _treeController = TreeController<_TaxonomyNode>(
      roots: _buildRoots(),
      childrenProvider: _childrenOf,
    );
  }

  @override
  void dispose() {
    _treeController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  List<_TaxonomyNode> _buildRoots() =>
      _controller!.getRootGroups().map(_GroupNode.new).toList();

  Iterable<_TaxonomyNode> _childrenOf(_TaxonomyNode node) {
    return switch (node) {
      _GroupNode(:final group) => [
        ..._controller!.getChildGroups(group.groupId).map(_GroupNode.new),
        ..._controller!.getTagsInGroup(group.groupId).map(_TagNode.new),
      ],
      _TagNode() => const [],
    };
  }

  /// Replaces the controller's `roots` and triggers a rebuild. Wrapped in
  /// `setState` so the dialog's surrounding chrome (save-status label,
  /// header) rebuilds too.
  void _refreshTree() {
    setState(() {
      _treeController!.roots = _buildRoots();
      _treeController!.rebuild();
    });
  }

  /// Drag-drop handler. Two valid shapes:
  /// - dragging a tag onto a group → tag moves into that group.
  /// - dragging a group onto another group → reparent (cycle-checked).
  /// All other combinations (tag → tag, group → tag) are no-ops.
  Future<void> _onNodeDropped(
    TreeDragAndDropDetails<_TaxonomyNode> details,
  ) async {
    final dragged = details.draggedNode;
    final target = details.targetNode;

    switch ((dragged, target)) {
      case (_TagNode(:final tag), _GroupNode(:final group)):
        final error = await _controller!.moveTag(tag.tagId, group.groupId);
        if (error != null) {
          _toast(error);
          return;
        }
        _treeController!.expand(target);
        _refreshTree();
      case (_GroupNode(:final group), _GroupNode(group: final destGroup)):
        if (group.groupId == destGroup.groupId) return;
        final error = await _controller!.moveGroup(
          group.groupId,
          destGroup.groupId,
        );
        if (error != null) {
          _toast(error);
          return;
        }
        _treeController!.expand(target);
        _refreshTree();
      default:
        return;
    }
  }

  void _toast(String message) {
    NavigationService().showSnackBar(message);
  }

  Future<void> _showAddGroupDialog({String? parentGroupId}) async {
    final result = await showDialog<_GroupFormResult>(
      context: context,
      builder: (_) => const _GroupFormDialog(initial: null),
    );
    if (result == null || !mounted) return;
    final error = await _controller!.addGroup(
      groupId: result.groupId,
      name: result.name,
      groupExplain: result.groupExplain,
      parentGroupId: parentGroupId,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    if (parentGroupId != null) {
      final parent = _controller!.getGroup(parentGroupId);
      if (parent != null) _treeController!.expand(_GroupNode(parent));
    }
    _refreshTree();
  }

  Future<void> _showEditGroupDialog(TaxonomyGroup group) async {
    final result = await showDialog<_GroupFormResult>(
      context: context,
      builder: (_) => _GroupFormDialog(initial: group),
    );
    if (result == null || !mounted) return;
    final error = await _controller!.updateGroup(
      oldGroupId: group.groupId,
      newGroupId: result.groupId,
      name: result.name,
      groupExplain: result.groupExplain,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    _refreshTree();
  }

  Future<void> _confirmDeleteGroup(TaxonomyGroup group) async {
    final descendantCount =
        _controller!.getChildGroups(group.groupId).length +
        _controller!.getTagsInGroup(group.groupId).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          descendantCount == 0
              ? 'Delete "${group.name}"?'
              : 'Delete "${group.name}" and all $descendantCount '
                    'item(s) inside it? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await _controller!.deleteGroup(group.groupId);
    if (error != null) {
      _toast(error);
      return;
    }
    _refreshTree();
  }

  Future<void> _showAddTagDialog(String groupId) async {
    final result = await showDialog<_TagFormResult>(
      context: context,
      builder: (_) => _TagFormDialog(
        initial: null,
        defaultGroupId: groupId,
        controller: _controller!,
      ),
    );
    if (result == null || !mounted) return;
    final error = await _controller!.addTag(
      tagId: result.tagId,
      tagName: result.tagName,
      tagExplain: result.tagExplain,
      synonyms: result.synonyms,
      groupId: result.groupId,
      isExclusive: result.isExclusive,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    final parent = _controller!.getGroup(result.groupId);
    if (parent != null) _treeController!.expand(_GroupNode(parent));
    _refreshTree();
  }

  Future<void> _showEditTagDialog(TaxonomyTag tag) async {
    final result = await showDialog<_TagFormResult>(
      context: context,
      builder: (_) => _TagFormDialog(
        initial: tag,
        defaultGroupId: tag.groupId,
        controller: _controller!,
      ),
    );
    if (result == null || !mounted) return;
    final error = await _controller!.updateTag(
      oldTagId: tag.tagId,
      newTagId: result.tagId,
      tagName: result.tagName,
      tagExplain: result.tagExplain,
      synonyms: result.synonyms,
      groupId: result.groupId,
      isExclusive: result.isExclusive,
    );
    if (error != null) {
      _toast(error);
      return;
    }
    _refreshTree();
  }

  Future<void> _confirmDeleteTag(TaxonomyTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text('Delete "${tag.tagName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await _controller!.deleteTag(tag.tagId);
    if (error != null) {
      _toast(error);
      return;
    }
    _refreshTree();
  }

  Future<void> _openDataFolder() async {
    final filePath = _controller!.getSavedFilePath();
    if (filePath == null) {
      _toast('Saved-file location is not exposed on this platform.');
      return;
    }
    // Open the parent directory in the OS file manager. Pointing
    // launchUrl at the JSON file itself opens it in a text editor (the
    // OS handler for .json) — the dev wants the folder so they can copy
    // the file into `assets/tags/` to ship.
    final dir = p.dirname(filePath);
    final ok = await launchUrl(Uri.file(dir));
    if (!ok) _toast('Could not open data folder.');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      isScrollable: false,
      forceMobile: true,
      builder: (context, isMobile) {
        final colors = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header laid out in two rows so the helper text never has
            // to share a horizontal track with the title + toolbar +
            // save indicator. On a narrow phone the previous single-row
            // layout squeezed the helper text into a ~80px column that
            // wrapped over 7 lines, pushing the toolbar buttons up.
            // Single `SizedBox(8)`; other pairs in the Row are flush
            // and would gain an unwanted gap.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Taxonomy Editor',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('taxonomy-add-root-group'),
                  tooltip: 'Add Root Group',
                  icon: const Icon(Icons.add),
                  onPressed: _showAddGroupDialog,
                ),
                IconButton(
                  tooltip: 'Open Data Folder',
                  icon: const Icon(Icons.folder_open),
                  onPressed: _openDataFolder,
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: _controller!,
                  builder: (_, _) => _SaveStatusText(controller: _controller!),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Drag tags between groups, drag groups to reparent. '
              'Edits save automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.outline,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: AnimatedTreeView<_TaxonomyNode>(
                treeController: _treeController!,
                nodeBuilder: (context, entry) => _NodeRow(
                  entry: entry,
                  treeController: _treeController!,
                  onDropped: _onNodeDropped,
                  onAddSubGroup: (id) => _showAddGroupDialog(parentGroupId: id),
                  onAddTag: _showAddTagDialog,
                  onEditGroup: _showEditGroupDialog,
                  onDeleteGroup: _confirmDeleteGroup,
                  onEditTag: _showEditTagDialog,
                  onDeleteTag: _confirmDeleteTag,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders the editor's "saved at HH:MM:SS" / "save failed" status. Pure
/// reader of the controller — no timer, no polling. Rebuilds via the
/// `ListenableBuilder` upstream when the controller fires after a save.
class _SaveStatusText extends StatelessWidget {
  const _SaveStatusText({required this.controller});
  final TaxonomyEditorController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasError = controller.lastSaveError != null;
    final saved = controller.lastSavedAt;
    final text = hasError
        ? 'Save failed — see logs'
        : saved == null
        ? 'No edits yet'
        : 'Saved at ${_formatTime(saved)}';
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: hasError ? colors.error : colors.outline,
        fontWeight: hasError ? FontWeight.w600 : null,
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.entry,
    required this.treeController,
    required this.onDropped,
    required this.onAddSubGroup,
    required this.onAddTag,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onEditTag,
    required this.onDeleteTag,
  });

  final TreeEntry<_TaxonomyNode> entry;
  final TreeController<_TaxonomyNode> treeController;
  final Future<void> Function(TreeDragAndDropDetails<_TaxonomyNode>) onDropped;
  final void Function(String parentGroupId) onAddSubGroup;
  final void Function(String groupId) onAddTag;
  final void Function(TaxonomyGroup) onEditGroup;
  final void Function(TaxonomyGroup) onDeleteGroup;
  final void Function(TaxonomyTag) onEditTag;
  final void Function(TaxonomyTag) onDeleteTag;

  @override
  Widget build(BuildContext context) {
    return TreeDragTarget<_TaxonomyNode>(
      node: entry.node,
      onNodeAccepted: onDropped,
      builder: (context, details) {
        final isAccepting = details != null;
        return TreeDraggable<_TaxonomyNode>(
          node: entry.node,
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: _buildRow(context, isAccepting: false),
          ),
          // Compact chip-style feedback. Reusing the full row would put
          // `Expanded` children inside the Overlay (which gives unbounded
          // width), so the row would fail to lay out and Flutter would
          // log a RenderFlex error.
          feedback: _DragFeedbackChip(node: entry.node),
          child: _buildRow(context, isAccepting: isAccepting),
        );
      },
    );
  }

  // The row-content builder of _NodeRow, called twice with different
  // `isAccepting`; extracting just moves _NodeRow's 9 callback fields + 2
  // fields onto a 12-param widget — no boundary gain.
  // ignore: qcheck/avoid_returning_widgets
  Widget _buildRow(BuildContext context, {required bool isAccepting}) {
    final colors = Theme.of(context).colorScheme;
    final node = entry.node;

    return TreeIndentation(
      entry: entry,
      child: Container(
        decoration: BoxDecoration(
          color: isAccepting
              ? colors.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: switch (node) {
          _GroupNode(:final group) => _GroupRowBody(
            group: group,
            entry: entry,
            treeController: treeController,
            onAddSubGroup: () => onAddSubGroup(group.groupId),
            onAddTag: () => onAddTag(group.groupId),
            onEdit: () => onEditGroup(group),
            onDelete: () => onDeleteGroup(group),
          ),
          _TagNode(:final tag) => _TagRowBody(
            tag: tag,
            onEdit: () => onEditTag(tag),
            onDelete: () => onDeleteTag(tag),
          ),
        },
      ),
    );
  }
}

class _GroupRowBody extends StatelessWidget {
  const _GroupRowBody({
    required this.group,
    required this.entry,
    required this.treeController,
    required this.onAddSubGroup,
    required this.onAddTag,
    required this.onEdit,
    required this.onDelete,
  });

  final TaxonomyGroup group;
  final TreeEntry<_TaxonomyNode> entry;
  final TreeController<_TaxonomyNode> treeController;
  final VoidCallback onAddSubGroup;
  final VoidCallback onAddTag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Single `SizedBox(6)` among 4 `_CompactIcon` siblings that are
    // otherwise flush; `spacing:` would gap all of them.
    return Row(
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          icon: Icon(
            entry.isExpanded ? Icons.expand_more : Icons.chevron_right,
          ),
          onPressed: () => treeController.toggleExpansion(entry.node),
        ),
        Icon(Icons.folder, size: 18, color: colors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            group.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _CompactIcon(
          tooltip: 'Add sub-group',
          icon: Icons.create_new_folder_outlined,
          onPressed: onAddSubGroup,
        ),
        _CompactIcon(
          tooltip: 'Add tag',
          icon: Icons.label_outline,
          onPressed: onAddTag,
        ),
        _CompactIcon(
          tooltip: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        _CompactIcon(
          tooltip: 'Delete',
          icon: Icons.delete_outline,
          color: colors.error,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _TagRowBody extends StatelessWidget {
  const _TagRowBody({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final TaxonomyTag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Plain `Text` widgets (not a single `RichText`) so widget-test
    // finders like `find.text('Character')` can see the name without a
    // `findRichText: true` workaround that would still fail because the
    // rich text's combined plain-text isn't equal to just the name.
    return Row(
      children: [
        const SizedBox(width: 28),
        Icon(Icons.label, size: 16, color: colors.outline),
        const SizedBox(width: 6),
        Flexible(
          child: Text(tag.tagName, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            tag.tagId,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: colors.outline,
            ),
          ),
        ),
        if (tag.isExclusive) ...[
          const SizedBox(width: 8),
          Text(
            'EXCLUSIVE',
            style: TextStyle(
              fontSize: 11,
              color: colors.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        _CompactIcon(
          tooltip: 'Edit',
          icon: Icons.edit_outlined,
          onPressed: onEdit,
        ),
        _CompactIcon(
          tooltip: 'Delete',
          icon: Icons.delete_outline,
          color: colors.error,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Small floating chip rendered under the cursor while a node is being
/// dragged. Deliberately uses `MainAxisSize.min` and no `Expanded`
/// children — the drag overlay supplies unbounded width, so a row built
/// with `Expanded` (like the in-tree row) would crash with a RenderFlex
/// "non-zero flex but incoming width constraints are unbounded" error.
class _DragFeedbackChip extends StatelessWidget {
  const _DragFeedbackChip({required this.node});
  final _TaxonomyNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label) = switch (node) {
      _GroupNode(:final group) => (Icons.folder, group.name),
      _TagNode(:final tag) => (Icons.label, tag.tagName),
    };
    return Material(
      elevation: 4,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CompactIcon extends StatelessWidget {
  const _CompactIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      splashRadius: 18,
    );
  }
}

class _GroupFormResult {
  const _GroupFormResult({
    required this.groupId,
    required this.name,
    required this.groupExplain,
  });
  final String groupId;
  final String name;
  final String groupExplain;
}

class _GroupFormDialog extends StatefulWidget {
  const _GroupFormDialog({required this.initial});
  final TaxonomyGroup? initial;

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  TextEditingController? _idController;
  TextEditingController? _nameController;
  TextEditingController? _explainController;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: widget.initial?.groupId ?? 'new_group',
    );
    _nameController = TextEditingController(
      text: widget.initial?.name ?? 'New Group',
    );
    _explainController = TextEditingController(
      text: widget.initial?.groupExplain ?? '',
    );
  }

  @override
  void dispose() {
    _idController?.dispose();
    _nameController?.dispose();
    _explainController?.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _idController!.text.trim();
    final name = _nameController!.text.trim();
    if (id.isEmpty || name.isEmpty) return;
    Navigator.pop(
      context,
      _GroupFormResult(
        groupId: id,
        name: name,
        groupExplain: _explainController!.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New Group' : 'Edit Group'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Group ID',
                hintText: 'e.g. body_features',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
              autofocus: widget.initial != null,
            ),
            TextField(
              controller: _explainController,
              decoration: const InputDecoration(
                labelText: 'Explanation (for the LLM)',
                hintText: 'What does this group cover?',
              ),
              minLines: 2,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _TagFormResult {
  const _TagFormResult({
    required this.tagId,
    required this.tagName,
    required this.tagExplain,
    required this.synonyms,
    required this.groupId,
    required this.isExclusive,
  });
  final String tagId;
  final String tagName;
  final String tagExplain;
  final List<String> synonyms;
  final String groupId;
  final bool isExclusive;
}

class _TagFormDialog extends StatefulWidget {
  const _TagFormDialog({
    required this.initial,
    required this.defaultGroupId,
    required this.controller,
  });
  final TaxonomyTag? initial;
  final String defaultGroupId;
  final TaxonomyEditorController controller;

  @override
  State<_TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends State<_TagFormDialog> {
  TextEditingController? _idController;
  TextEditingController? _nameController;
  TextEditingController? _explainController;
  TextEditingController? _synonymsController;
  late String _groupId;
  late bool _isExclusive;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _idController = TextEditingController(text: t?.tagId ?? 'new_tag');
    _nameController = TextEditingController(text: t?.tagName ?? 'New Tag');
    _explainController = TextEditingController(text: t?.tagExplain ?? '');
    _synonymsController = TextEditingController(
      text: (t?.synonyms ?? const []).join(', '),
    );
    _groupId = t?.groupId ?? widget.defaultGroupId;
    _isExclusive = t?.isExclusive ?? false;
  }

  @override
  void dispose() {
    _idController?.dispose();
    _nameController?.dispose();
    _explainController?.dispose();
    _synonymsController?.dispose();
    super.dispose();
  }

  Future<void> _pickGroup() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) =>
          _GroupPickerDialog(controller: widget.controller, current: _groupId),
    );
    if (picked != null) setState(() => _groupId = picked);
  }

  void _submit() {
    final id = _idController!.text.trim();
    final name = _nameController!.text.trim();
    if (id.isEmpty || name.isEmpty) return;
    final synonyms = _synonymsController!.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.pop(
      context,
      _TagFormResult(
        tagId: id,
        tagName: name,
        tagExplain: _explainController!.text.trim(),
        synonyms: synonyms,
        groupId: _groupId,
        isExclusive: _isExclusive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.controller.getGroup(_groupId)?.name ?? '(unknown)';
    return AlertDialog(
      title: Text(widget.initial == null ? 'New Tag' : 'Edit Tag'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Tag ID',
                  hintText: 'e.g. fmt_character',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _explainController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _synonymsController,
                decoration: const InputDecoration(
                  labelText: 'Synonyms',
                  hintText: 'comma separated',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Group'),
                subtitle: Text(groupName),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickGroup,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exclusive within group'),
                subtitle: const Text(
                  "Tags marked exclusive form the group's pick-one set.",
                ),
                value: _isExclusive,
                onChanged: (v) => setState(() => _isExclusive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _GroupPickerDialog extends StatelessWidget {
  const _GroupPickerDialog({required this.controller, required this.current});
  final TaxonomyEditorController controller;
  final String current;

  /// Walks the group tree depth-first into a flat list of indented tiles.
  /// Lifted out of `build` so the recursion isn't a nested function (the
  /// project's CLAUDE.md bans nested methods).
  void _collectTiles(
    BuildContext context,
    List<Widget> tiles,
    TaxonomyGroup group,
    int depth,
  ) {
    tiles.add(
      ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
        title: Text(group.name),
        subtitle: Text(
          group.groupId,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
        trailing: group.groupId == current
            ? const Icon(Icons.check_circle)
            : null,
        onTap: () => Navigator.pop(context, group.groupId),
      ),
    );
    for (final child in controller.getChildGroups(group.groupId)) {
      _collectTiles(context, tiles, child, depth + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (final root in controller.getRootGroups()) {
      _collectTiles(context, tiles, root, 0);
    }
    return AlertDialog(
      title: const Text('Pick a group'),
      content: SizedBox(
        width: 360,
        height: 480,
        child: ListView(children: tiles),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
