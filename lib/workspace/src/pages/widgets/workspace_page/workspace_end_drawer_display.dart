part of '../../workspace_page.dart';

class _WorkspaceEndDrawerDisplay extends StatelessWidget {
  const _WorkspaceEndDrawerDisplay({required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final settings = settingsService.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Display'),
        DrawerSwitchTile(
          leading: const Icon(Icons.image),
          title: const Text('Show Character Image'),
          subtitle: const Text('Wide-screen editor only'),
          value: settings.editorImageVisible,
          onChanged: (value) {
            settings.editorImageVisible = value;
            unawaited(settingsService.saveSettings());
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
    );
  }
}
