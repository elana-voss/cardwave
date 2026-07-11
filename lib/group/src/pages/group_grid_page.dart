import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/pages/widgets/dialog_create_group.dart';
import 'package:cardwave/group/src/pages/widgets/group_grid_item.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/routing/app_router_args_group_chat.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';

class GroupGridPage extends StatefulWidget {
  const GroupGridPage({super.key});

  @override
  State<GroupGridPage> createState() => _GroupGridPageState();
}

class _GroupGridPageState extends State<GroupGridPage> {
  late Future<List<GroupFile>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _groupsFuture = context.read<GroupFileService>().listGroups();
  }

  Future<void> _createGroup() async {
    final created = await DialogCreateGroup.show(context);
    if (created == null || !mounted) return;
    await _openGroup(created.id);
  }

  Future<void> _openGroup(String groupId) async {
    await Navigator.of(context).pushNamed(
      AppRoutesEnum.groupChat.name,
      arguments: AppRouterArgsGroupChat(groupId),
    );
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            constraints.maxWidth >= AppConstants.tabletBreakpoint;

        return AppScaffold(
          appBar: AppBarGroupGrid(onCreateGroup: _createGroup),
          endDrawer: const AppEndDrawer(),
          floatingActionButton: isWideScreen
              ? null
              : SpeedDial(
                  key: const Key('group-new-fab'),
                  icon: Icons.add,
                  tooltip: t.grid.groupAppBar.newGroup,
                  onPress: _createGroup,
                ),
          body: FutureBuilder<List<GroupFile>>(
            future: _groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      t.group.groupGridPage.failedToLoadMessage(
                        error:
                            '${snapshot.error ?? t.group.groupGridPage.unknownErrorFallback}',
                      ),
                    ),
                  ),
                );
              }
              final groups = snapshot.data ?? const <GroupFile>[];
              if (groups.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t.group.groupGridPage.noGroupsYetMessage),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: AppConstants.gridMaxCrossAxisExtent,
                  mainAxisExtent: AppConstants.gridMainAxisExtent,
                  crossAxisSpacing: AppConstants.gridCrossAxisSpacing,
                  mainAxisSpacing: AppConstants.gridMainAxisSpacing,
                ),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return GroupGridItem(
                    key: ValueKey(group.id),
                    group: group,
                    onTap: () => _openGroup(group.id),
                    onChanged: () {
                      if (mounted) setState(_reload);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
