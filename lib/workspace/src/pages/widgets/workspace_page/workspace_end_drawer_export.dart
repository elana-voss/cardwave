part of '../../workspace_page.dart';

class _WorkspaceEndDrawerExport extends StatelessWidget {
  const _WorkspaceEndDrawerExport({
    required this.activeCharacterFile,
    required this.characterService,
  });
  final CharacterFile activeCharacterFile;
  final CharacterService characterService;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.workspace.workspaceEndDrawerExport.sectionHeader),
        ListTile(
          leading: const Icon(Icons.image),
          title: Text(t.workspace.workspaceEndDrawerExport.exportPngTitle),
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(() async {
              try {
                await characterService.exportAsPng(activeCharacterFile);
              } on Exception catch (e, st) {
                LoggingService().error('PNG export failed', e, st);
                NavigationService().showSnackBar(
                  AppConstants.exportFailedMessage,
                );
              }
            }());
          },
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: Text(t.workspace.workspaceEndDrawerExport.exportJsonV3Title),
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(() async {
              try {
                await characterService.exportAsJson(activeCharacterFile);
              } on Exception catch (e, st) {
                LoggingService().error('JSON V3 export failed', e, st);
                NavigationService().showSnackBar(
                  AppConstants.exportFailedMessage,
                );
              }
            }());
          },
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: Text(t.workspace.workspaceEndDrawerExport.exportJsonV2Title),
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(() async {
              try {
                await characterService.exportAsJson(
                  activeCharacterFile,
                  asV2: true,
                );
              } on Exception catch (e, st) {
                LoggingService().error('JSON V2 export failed', e, st);
                NavigationService().showSnackBar(
                  AppConstants.exportFailedMessage,
                );
              }
            }());
          },
        ),
      ],
    );
  }
}
