part of 'editor_view.dart';

class _PanelNavigationRail extends StatelessWidget {
  const _PanelNavigationRail({
    required this.selected,
    required this.onSelectionChanged,
  });
  final PanelEnum selected;
  final ValueChanged<PanelEnum> onSelectionChanged;

  static const List<PanelEnum> _panels = [
    PanelEnum.basic,
    PanelEnum.greetings,
    PanelEnum.prompts,
    PanelEnum.lorebook,
    PanelEnum.groupSettings,
    PanelEnum.creatorMetadata,
    PanelEnum.appData,
    PanelEnum.nodes,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    var selectedIndex = _panels.indexOf(selected);
    if (selectedIndex == -1) selectedIndex = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) =>
                    // NavigationRail only calls this with a valid destination index.
                    // ignore: qcheck/avoid_unsafe_collection_methods
                    onSelectionChanged(_panels[index]),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -1,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: Text(t.editor.panelLabels.basic),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.chat_bubble_outline),
                    selectedIcon: const Icon(Icons.chat_bubble),
                    label: Text(t.editor.panelLabels.greetings),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.terminal_outlined),
                    selectedIcon: const Icon(Icons.terminal),
                    label: Text(t.editor.panelLabels.prompts),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book),
                    label: Text(t.editor.panelLabels.lorebook),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.groups_outlined),
                    selectedIcon: const Icon(Icons.groups),
                    label: Text(t.editor.panelLabels.group),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.badge_outlined),
                    selectedIcon: const Icon(Icons.badge),
                    label: Text(t.editor.panelLabels.creator),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.data_object_outlined),
                    selectedIcon: const Icon(Icons.data_object),
                    label: Text(t.editor.panelLabels.appData),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.hub_outlined),
                    selectedIcon: const Icon(Icons.hub),
                    label: Text(t.editor.panelLabels.nodes),
                  ),
                ],
                // trailingAtBottom: true,
                // trailing: _TokenStatusPill(
                //   characterFile: context
                //       .watch<EditorPageController>()
                //       .characterFile,
                // ),
              ),
            ),
          ),
        );
      },
    );
  }
}
