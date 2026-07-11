import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/pages/widgets/dialog_create_group.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modal that lists existing groups and offers a "New Group" entry.
/// Returns the selected (or freshly created) [GroupFile] via [Navigator.pop],
/// or null if the user cancels.
class DialogSelectGroup extends StatefulWidget {
  const DialogSelectGroup({super.key});

  // Public entry point — `Dialog.show(ctx)` is the dialog-opening convention.
  // ignore: qcheck/prefer_widget_private_members
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
      title: t.group.dialogSelectGroup.deleteGroupTitle,
      message: t.group.dialogSelectGroup.deleteGroupMessage(
        name: group.group.name,
      ),
      confirmText: t.common.actions.delete,
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
            t.group.dialogSelectGroup.title,
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
                label: Text(t.grid.groupAppBar.newGroup),
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
                    t.group.groupGridPage.failedToLoadMessage(
                      error:
                          '${snapshot.error ?? t.group.groupGridPage.unknownErrorFallback}',
                    ),
                  ),
                );
              }
              final groups = snapshot.data ?? const [];
              if (groups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.group.dialogSelectGroup.noGroupsYetMessage,
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
      subtitle: Text(
        t.group.dialogSelectGroup.memberCountLabel(n: memberCount),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: t.common.actions.delete,
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
