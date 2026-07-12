part of '../../workspace_page.dart';

class _WorkspaceEndDrawerEditing extends StatelessWidget {
  const _WorkspaceEndDrawerEditing({required this.onApplyCleaner});
  final void Function(String Function(String))? onApplyCleaner;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.workspace.workspaceEndDrawerEditing.sectionHeader),
        ListTile(
          leading: const Icon(Icons.cleaning_services),
          title: Text(t.editor.dialogContentCleaner.title),
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            if (onApplyCleaner != null) {
              unawaited(
                NavigationService().showContentCleanerDialog(
                  onApply: onApplyCleaner!,
                ),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.find_replace),
          title: Text(t.editor.findReplaceDialog.title),
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            if (onApplyCleaner != null) {
              unawaited(
                NavigationService().showFindReplaceDialog(
                  onApply: onApplyCleaner!,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
