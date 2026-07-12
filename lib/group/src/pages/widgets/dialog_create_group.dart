import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modal for creating a new group. Asks for a name, then delegates creation
/// to [GroupFileService.loadOrCreate] with a freshly generated id.
/// Returns the new [GroupFile] on success, or null if cancelled.
class DialogCreateGroup extends StatefulWidget {
  const DialogCreateGroup({super.key});

  // Public entry point — `Dialog.show(ctx)` is the dialog-opening convention.
  // ignore: qcheck/prefer_widget_private_members
  static Future<GroupFile?> show(BuildContext context) {
    return showDialog<GroupFile>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<GroupFileService>(),
        child: const DialogCreateGroup(),
      ),
    );
  }

  @override
  State<DialogCreateGroup> createState() => _DialogCreateGroupState();
}

class _DialogCreateGroupState extends State<DialogCreateGroup> {
  final _nameController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    final service = context.read<GroupFileService>();
    final id = 'group_${DateTime.now().millisecondsSinceEpoch}';
    final group = await service.loadOrCreate(id, name: name);
    if (!mounted) return;
    Navigator.of(context).pop(group);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return AlertDialog(
      title: Text(t.group.dialogCreateGroup.title),
      content: TextField(
        key: const Key('group-name-field'),
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: t.group.dialogCreateGroup.nameLabel,
          hintText: t.group.dialogCreateGroup.nameHint,
        ),
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          key: const Key('group-create-confirm'),
          onPressed: _creating ? null : _create,
          child: Text(t.grid.createCharacterDialog.createButton),
        ),
      ],
    );
  }
}
