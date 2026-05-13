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
  ];

  @override
  Widget build(BuildContext context) {
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
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('Basic'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon: Icon(Icons.chat_bubble),
                    label: Text('Greetings'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.terminal_outlined),
                    selectedIcon: Icon(Icons.terminal),
                    label: Text('Prompts'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: Text('Lorebook'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Group'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.badge_outlined),
                    selectedIcon: Icon(Icons.badge),
                    label: Text('Creator'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.data_object_outlined),
                    selectedIcon: Icon(Icons.data_object),
                    label: Text('App Data'),
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
