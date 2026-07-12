part of '../../workspace_page.dart';

class _WorkspaceEndDrawerAi extends StatelessWidget {
  const _WorkspaceEndDrawerAi({required this.onGlobalAiAction});
  final ValueChanged<AiActionEnum> onGlobalAiAction;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.workspace.workspaceEndDrawerAi.sectionHeader),
        for (final action in AiActionEnum.values)
          ListTile(
            leading: Icon(action.icon),
            title: Text(action.label),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              onGlobalAiAction(action);
            },
          ),
      ],
    );
  }
}
