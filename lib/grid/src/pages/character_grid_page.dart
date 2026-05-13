import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/controllers/filter_controller.dart';
import 'package:cardwave/grid/src/pages/widgets/appbar_grid.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_filters.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:cardwave/grid/src/pages/widgets/view_empy_state.dart';
import 'package:cardwave/routing/route_create_character.dart';
import 'package:cardwave/search/search.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';

class CharacterGridPage extends StatefulWidget {
  const CharacterGridPage({super.key});

  @override
  State<CharacterGridPage> createState() => _CharacterGridPageState();
}

class _CharacterGridPageState extends State<CharacterGridPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final service = context.read<CharacterService>();
      if (service.characterFiles.isEmpty) {
        unawaited(service.loadCharacters());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FilterController(
        characterService: context.read<CharacterService>(),
        searchService: context.read<SearchService>(),
      ),
      child: Consumer<FilterController>(
        builder: (context, filterController, child) {
          final groupedFiles = filterController.groupedFiles;
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen =
                  constraints.maxWidth >= AppConstants.tabletBreakpoint;

              return AppScaffold(
                appBar: const AppBarGrid(),
                endDrawer: AppEndDrawer(
                  chatSpecificMenuBuilder: (navContext) => _GridDrawerMenu(
                    navContext: navContext,
                    outerContext: context,
                  ),
                ),
                floatingActionButton: isWideScreen
                    ? null
                    : SpeedDial(
                        key: const Key('grid-fab-speed-dial'),
                        icon: Icons.menu,
                        activeIcon: Icons.close,
                        tooltip: 'Add or Import',
                        spacing: 8,
                        spaceBetweenChildren: 4,
                        renderOverlay: false,
                        children: [
                          SpeedDialChild(
                            child: const KeyedSubtree(
                              key: Key('grid-fab-import'),
                              child: Icon(Icons.upload, size: 20),
                            ),
                            shape: const CircleBorder(),
                            label: 'Import',
                            onTap: () =>
                                CharacterImportController.runBulkImport(
                                  context.read<CharacterService>(),
                                ),
                          ),
                          SpeedDialChild(
                            child: const KeyedSubtree(
                              key: Key('grid-fab-create'),
                              child: Icon(Icons.add, size: 20),
                            ),
                            shape: const CircleBorder(),
                            label: 'Create',
                            onTap: () =>
                                RouteCreateCharacter().execute(context),
                          ),
                        ],
                      ),
                body: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: CharacterGridFilters(),
                    ),
                    Expanded(
                      child: groupedFiles.isEmpty
                          ? const ViewEmptyState()
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent:
                                        AppConstants.gridMaxCrossAxisExtent,
                                    mainAxisExtent:
                                        AppConstants.gridMainAxisExtent,
                                    crossAxisSpacing:
                                        AppConstants.gridCrossAxisSpacing,
                                    mainAxisSpacing:
                                        AppConstants.gridMainAxisSpacing,
                                  ),
                              itemCount: groupedFiles.length,
                              itemBuilder: (context, index) {
                                final stack = groupedFiles[index];
                                // Each grouped entry has at least one card.
                                // ignore: qcheck/avoid_unsafe_collection_methods
                                final first = stack.first;
                                final name = first.card.name;
                                return KeyedSubtree(
                                  // Test handle. The inner CharacterGridItem
                                  // already has a functional ValueKey on the
                                  // image path for state preservation; wrap
                                  // here so tests can find a tile by the
                                  // character's display name without
                                  // colliding with that.
                                  key: ValueKey(
                                    'grid-card-${name.isNotEmpty ? name : first.appCardImagePath}',
                                  ),
                                  child: CharacterGridItem(
                                    key: ValueKey(first.appCardImagePath),
                                    characters: stack,
                                    variantStatus: stack.length > 1
                                        ? VariantStatusEnum.original
                                        : VariantStatusEnum.none,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GridDrawerMenu extends StatelessWidget {
  const _GridDrawerMenu({required this.navContext, required this.outerContext});
  // The drawer's nested-Navigator context (to pop the drawer) and the outer
  // page context (to act after popping) — the standard "pop the drawer, then
  // act on the outer context" pattern. This is a StatelessWidget, so both are
  // fresh per construction, not stale-across-rebuilds State fields.
  // ignore: qcheck/avoid_buildcontext_in_state_field
  final BuildContext navContext;
  // ignore: qcheck/avoid_buildcontext_in_state_field
  final BuildContext outerContext;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    return IconTheme.merge(
      data: const IconThemeData(size: 20),
      child: ListTileTheme(
        data: const ListTileThemeData(dense: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top-of-drawer entry: configuration is semantically distinct
            // from grid actions below, so it sits above them under its
            // own section header. The next section's DrawerSectionHeader
            // provides the divider.
            MediaDefaultsDrawerEntry(
              subtitle: 'App',
              onTap: () {
                Navigator.of(navContext, rootNavigator: true).pop();
                unawaited(
                  DialogAiSettings.show(
                    outerContext,
                    initialTab: DialogAiSettingsTab.mediaDefaults,
                  ),
                );
              },
            ),
            const DrawerSectionHeader('Batch AI'),
            for (final action in AiActionEnum.values.where(
              (a) => a.isGlobalOnly,
            ))
              ListTile(
                key: Key('drawer-ai-action-${action.name}'),
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () {
                  Navigator.of(navContext, rootNavigator: true).pop();
                  final ai = outerContext.read<CharacterAiService>();
                  switch (action) {
                    case AiActionEnum.generatePreview:
                      unawaited(
                        AiActionController.runCharacterBatchAndShow(
                          title: 'Batch Generate Previews',
                          emptyMessage:
                              'All characters already have previews.',
                          targets: ai.charactersMissingPreview,
                          operation: ai.generateDescriptionPreview,
                          onCancel: ai.cancelAllActiveAiTasks,
                          batchLogTag: 'Bulk',
                        ),
                      );
                    case AiActionEnum.autoTag:
                      unawaited(
                        AiActionController.runCharacterBatchAndShow(
                          title: 'Batch Auto-Tag',
                          emptyMessage: 'All characters already have tags.',
                          targets: ai.charactersMissingTags,
                          operation: ai.autoTagCharacter,
                          onCancel: ai.cancelAllActiveAiTasks,
                        ),
                      );
                    default:
                      break;
                  }
                },
              ),
            if (isDesktop) ...[
              const DrawerSectionHeader('Library'),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reload characters'),
                onTap: () {
                  Navigator.of(navContext, rootNavigator: true).pop();
                  unawaited(
                    outerContext.read<CharacterService>().loadCharacters(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
