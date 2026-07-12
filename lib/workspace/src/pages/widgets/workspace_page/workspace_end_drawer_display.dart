part of '../../workspace_page.dart';

class _WorkspaceEndDrawerDisplay extends StatelessWidget {
  const _WorkspaceEndDrawerDisplay({required this.settingsService});
  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final settings = settingsService.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.workspace.workspaceEndDrawerDisplay.sectionHeader),
        DrawerSwitchTile(
          leading: const Icon(Icons.image),
          title: Text(t.workspace.workspaceEndDrawerDisplay.showCharacterImageTitle),
          subtitle: Text(t.workspace.workspaceEndDrawerDisplay.wideScreenOnlySubtitle),
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
