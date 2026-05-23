import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/pages/widgets/dialog_create_group.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modal that lists existing groups and offers a "New Group" entry.
/// Returns the selected (or freshly created) [GroupFile] via [Navigator.pop],
/// or null if the user cancels.
class DialogSelectGroup extends StatefulWidget {
  const DialogSelectGroup({super.key});

  static Future<GroupFile?> show(BuildContext context) {
    final groupFileService = context.read<GroupFileService>();
    return showDialog<GroupFile>(
      context: context,
      builder: (_) => ChangeNotifierProvider<GroupFileService>.value(
        value: groupFileService,
        child: const DialogSelectGroup(),
      ),
    );
  }

  @override
  State<DialogSelectGroup> createState() => _DialogSelectGroupState();
}

class _DialogSelectGroupState extends State<DialogSelectGroup> {
  late Future<List<GroupFile>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _groupsFuture = context.read<GroupFileService>().listGroups();
  }

  Future<void> _createNew() async {
    final created = await DialogCreateGroup.show(context);
    if (created == null || !mounted) return;
    Navigator.of(context).pop(created);
  }

  Future<void> _confirmDelete(GroupFile group) async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete group?',
      message:
          '"${group.group.name}" and all of its chat sessions will be '
          'permanently removed.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;
    await context.read<GroupFileService>().deleteGroup(group.id);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      // Single `SizedBox(8)`; an adjacent `FutureBuilder` has 0 gap
      // that would become 8 if `spacing:` were applied.
      // ignore: qcheck/prefer_spacing
      builder: (context, isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Groups',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _createNew,
                icon: const Icon(Icons.add),
                label: const Text('New group'),
              ),
            ),
          ),
          FutureBuilder<List<GroupFile>>(
            future: _groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Failed to load groups:\n${snapshot.error ?? 'unknown error'}',
                  ),
                );
              }
              final groups = snapshot.data ?? const [];
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No groups yet. Tap "New group" to create one.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final group in groups)
                    _GroupRow(
                      group: group,
                      onTap: () => Navigator.of(context).pop(group),
                      onDelete: () => _confirmDelete(group),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });
  final GroupFile group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final memberCount = group.group.memberAppCardIds.length;
    return ListTile(
      leading: const Icon(Icons.group),
      title: Text(group.group.name),
      subtitle: Text(memberCount == 1 ? '1 member' : '$memberCount members'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
