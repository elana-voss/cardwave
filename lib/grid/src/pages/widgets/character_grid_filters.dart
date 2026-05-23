import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/controllers/filter_controller.dart';
import 'package:cardwave/search/search.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CharacterGridFilters extends StatefulWidget {
  const CharacterGridFilters({super.key});

  @override
  State<CharacterGridFilters> createState() => _CharacterGridFiltersState();
}

class _CharacterGridFiltersState extends State<CharacterGridFilters> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FilterController>();
    final characterService = context.watch<CharacterService>();

    final hasDirectories =
        characterService.directoriesWithCharacters.isNotEmpty;

    final hasActiveDirectory =
        controller.selectedDirectory != FilterController.allDirectories;

    final hasAdvancedFilters =
        hasActiveDirectory ||
        controller.selectedCreators.isNotEmpty ||
        controller.selectedTags.isNotEmpty ||
        controller.filterFavorites ||
        controller.prioritizeRecent ||
        controller.filterHasVariants;

    return Padding(
      padding: const EdgeInsetsGeometry.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: controller.searchController,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: DropdownButtonFormField<CharacterSortOptionEnum>(
                  initialValue: controller.sortOption,
                  iconSize: 20,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  items: CharacterSortOptionEnum.values.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(
                        opt.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) controller.setSortOption(value);
                  },
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.tune,
                  size: 20,
                ),
                tooltip: _expanded ? 'Hide filters' : 'More filters',
                style: IconButton.styleFrom(
                  foregroundColor: hasAdvancedFilters
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  backgroundColor: hasAdvancedFilters
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              _CountPill(
                filteredCount: controller.filteredFiles.length,
                totalCount: characterService.characterFiles.length,
                canClear: controller.hasActiveFilters,
                onClear: controller.clearAllFilters,
              ),
            ],
          ),
          const _IndexingProgressLine(),
          if (_expanded) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasDirectories)
                  ActionChip(
                    avatar: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Folder'),
                    onPressed: controller.openDirectoryFilterDialog,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: const Text('Creator'),
                  onPressed: controller.openCreatorFilterDialog,
                ),
                ActionChip(
                  avatar: const Icon(Icons.tag, size: 16),
                  label: const Text('Tag'),
                  onPressed: controller.openTagFilterDialog,
                ),
                IconButton(
                  onPressed: controller.togglePrioritizeRecent,
                  icon: const Icon(Icons.history, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: const EdgeInsets.all(4),
                  style: IconButton.styleFrom(
                    foregroundColor: controller.prioritizeRecent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    backgroundColor: controller.prioritizeRecent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  tooltip: 'Recent',
                ),
                IconButton(
                  onPressed: controller.toggleFilterFavorites,
                  icon: Icon(
                    controller.filterFavorites
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 20,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: const EdgeInsets.all(4),
                  style: IconButton.styleFrom(
                    foregroundColor: controller.filterFavorites
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    backgroundColor: controller.filterFavorites
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  tooltip: 'Favorites',
                ),
                IconButton(
                  onPressed: controller.toggleFilterHasVariants,
                  icon: const Icon(Icons.style, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: const EdgeInsets.all(4),
                  style: IconButton.styleFrom(
                    foregroundColor: controller.filterHasVariants
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    backgroundColor: controller.filterHasVariants
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  tooltip: 'Variants',
                ),
              ],
            ),
          ],
          if (hasActiveDirectory ||
              controller.selectedCreators.isNotEmpty ||
              controller.selectedTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Wrap(
                spacing: 8,
                children: [
                  if (hasActiveDirectory)
                    InputChip(
                      avatar: const Icon(Icons.folder_open, size: 16),
                      label: Text(controller.selectedDirectory),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      side: BorderSide.none,
                      onPressed: () => controller.setDirectory(
                        FilterController.allDirectories,
                      ),
                      onDeleted: () => controller.setDirectory(
                        FilterController.allDirectories,
                      ),
                    ),
                  ...controller.selectedCreators.map((creator) {
                    void removeCreator() {
                      final newCreators = Set<String>.of(
                        controller.selectedCreators,
                      )..remove(creator);
                      controller.setCreators(newCreators);
                    }

                    return InputChip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(creator),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      side: BorderSide.none,
                      onPressed: removeCreator,
                      onDeleted: removeCreator,
                    );
                  }),
                  ...controller.selectedTags.map((tag) {
                    void removeTag() {
                      final newTags = Set<String>.of(controller.selectedTags)
                        ..remove(tag);
                      controller.setTags(newTags);
                    }

                    return InputChip(
                      avatar: const Icon(Icons.tag, size: 16),
                      label: Text(tag),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      side: BorderSide.none,
                      onPressed: removeTag,
                      onDeleted: removeTag,
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.filteredCount,
    required this.totalCount,
    required this.canClear,
    required this.onClear,
  });
  final int filteredCount;
  final int totalCount;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = canClear ? '$filteredCount / $totalCount' : '$totalCount';

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: canClear
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: canClear
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (canClear) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.close,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ],
      ),
    );

    if (!canClear) return pill;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClear,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        child: pill,
      ),
    );
  }
}

/// "Building search X / Y…" line, shown only while the embedding worker has work left.
class _IndexingProgressLine extends StatelessWidget {
  const _IndexingProgressLine();

  @override
  Widget build(BuildContext context) {
    return Selector<SearchService, ({int done, int total})>(
      selector: (_, service) => service.progress,
      builder: (context, progress, _) {
        if (progress.done >= progress.total) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Building search ${progress.done} / ${progress.total}…',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
