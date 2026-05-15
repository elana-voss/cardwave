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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Export'),
        ListTile(
          leading: const Icon(Icons.image),
          title: const Text('Export as PNG (V2/V3)'),
          onTap: () async {
            Navigator.of(context, rootNavigator: true).pop();
            try {
              await characterService.exportAsPng(activeCharacterFile);
            } on Exception catch (e, st) {
              LoggingService().error('PNG export failed', e, st);
              NavigationService().showSnackBar(
                AppConstants.exportFailedMessage,
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: const Text('Export as JSON (V3)'),
          onTap: () async {
            Navigator.of(context, rootNavigator: true).pop();
            try {
              await characterService.exportAsJson(activeCharacterFile);
            } on Exception catch (e, st) {
              LoggingService().error('JSON V3 export failed', e, st);
              NavigationService().showSnackBar(
                AppConstants.exportFailedMessage,
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.data_object),
          title: const Text('Export as JSON (V2)'),
          onTap: () async {
            Navigator.of(context, rootNavigator: true).pop();
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
          },
        ),
      ],
    );
  }
}
