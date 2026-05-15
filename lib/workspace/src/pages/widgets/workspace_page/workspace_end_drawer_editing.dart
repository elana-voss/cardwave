part of '../../workspace_page.dart';

class _WorkspaceEndDrawerEditing extends StatelessWidget {
  const _WorkspaceEndDrawerEditing({required this.onApplyCleaner});
  final void Function(String Function(String))? onApplyCleaner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Editing'),
        ListTile(
          leading: const Icon(Icons.cleaning_services),
          title: const Text('Content Cleaner'),
          onTap: () async {
            Navigator.of(context, rootNavigator: true).pop();
            if (onApplyCleaner != null) {
              await NavigationService().showContentCleanerDialog(
                onApply: onApplyCleaner!,
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.find_replace),
          title: const Text('Find & Replace'),
          onTap: () async {
            Navigator.of(context, rootNavigator: true).pop();
            if (onApplyCleaner != null) {
              await NavigationService().showFindReplaceDialog(
                onApply: onApplyCleaner!,
              );
            }
          },
        ),
      ],
    );
  }
}
