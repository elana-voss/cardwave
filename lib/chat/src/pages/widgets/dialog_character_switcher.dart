import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/search/search.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modal picker for switching the active character in the workspace.
///
/// Returns the selected [CharacterFile] via [Navigator.pop], or null if the
/// user cancels. The caller decides what to do with the selection (e.g. the
/// workspace route-swap performed by [WorkspaceSwitchCharacter]).
class DialogCharacterSwitcher extends StatefulWidget {
  const DialogCharacterSwitcher({
    required this.currentCharacterFile,
    super.key,
  });
  final CharacterFile currentCharacterFile;

  static Future<CharacterFile?> show(
    BuildContext context, {
    required CharacterFile currentCharacterFile,
  }) {
    return showDialog<CharacterFile>(
      context: context,
      builder: (_) => DialogCharacterSwitcher(
        currentCharacterFile: currentCharacterFile,
      ),
    );
  }

  @override
  State<DialogCharacterSwitcher> createState() =>
      _DialogCharacterSwitcherState();
}

class _DialogCharacterSwitcherState extends State<DialogCharacterSwitcher> {
  FilterController? _filterController;

  @override
  void initState() {
    super.initState();
    _filterController = FilterController(
      characterService: context.read<CharacterService>(),
      searchService: context.read<SearchService>(),
    );
  }

  @override
  void dispose() {
    _filterController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      isScrollable: false,
      builder: (context, isMobile) {
        return ListenableBuilder(
          listenable: _filterController!,
          builder: (context, _) {
            final allGroups = <String, List<CharacterFile>>{};
            for (final file
                in context.watch<CharacterService>().characterFiles) {
              (allGroups[file.appCardRootId] ??= []).add(file);
            }

            final originalIds = <String>{};
            final variantIds = <String>{};

            for (final stack in allGroups.values) {
              if (stack.length > 1) {
                final oldest = stack.reduce(
                  (a, b) =>
                      a.pngTimestampImported <= b.pngTimestampImported ? a : b,
                );
                originalIds.add(oldest.appCardImagePath);
                for (final f in stack) {
                  if (f.appCardImagePath != oldest.appCardImagePath) {
                    variantIds.add(f.appCardImagePath);
                  }
                }
              }
            }

            final filteredCharacters =
                List<CharacterFile>.of(_filterController!.filteredFiles)
                  ..sort((a, b) {
                    final aTime =
                        (a.appCardTimestampLastChatted ?? 0) >
                            (a.appCardTimestampLastSaved ?? 0)
                        ? (a.appCardTimestampLastChatted ?? 0)
                        : (a.appCardTimestampLastSaved ?? 0);
                    final bTime =
                        (b.appCardTimestampLastChatted ?? 0) >
                            (b.appCardTimestampLastSaved ?? 0)
                        ? (b.appCardTimestampLastChatted ?? 0)
                        : (b.appCardTimestampLastSaved ?? 0);
                    return bTime.compareTo(aTime);
                  });
            return Column(
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: AppSearchField(
                        controller: _filterController!.searchController,
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [
                        _filterController!.filterFavorites,
                        _filterController!.prioritizeRecent,
                      ],
                      onPressed: (index) {
                        if (index == 0) {
                          _filterController!.toggleFilterFavorites();
                        } else {
                          _filterController!.togglePrioritizeRecent();
                        }
                      },
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      constraints: const BoxConstraints(
                        minHeight: 40,
                        minWidth: 48,
                      ),
                      children: const [
                        Tooltip(
                          message: 'Favorites',
                          child: Icon(Icons.favorite, size: 18),
                        ),
                        Tooltip(
                          message: 'Recent Chats',
                          child: Icon(Icons.history, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredCharacters.length,
                    itemBuilder: (context, index) {
                      final file = filteredCharacters[index];
                      return _CharacterSwitcherItem(
                        characterFile: file,
                        isSelected:
                            file.appCardImagePath ==
                            widget.currentCharacterFile.appCardImagePath,
                        isOriginalVariant: originalIds.contains(
                          file.appCardImagePath,
                        ),
                        isVariant: variantIds.contains(file.appCardImagePath),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CharacterSwitcherItem extends StatelessWidget {
  const _CharacterSwitcherItem({
    required this.characterFile,
    required this.isSelected,
    required this.isOriginalVariant,
    required this.isVariant,
  });
  final CharacterFile characterFile;
  final bool isSelected;
  final bool isOriginalVariant;
  final bool isVariant;

  @override
  Widget build(BuildContext context) {
    final lastActivity =
        (characterFile.appCardTimestampLastChatted ?? 0) >
            (characterFile.appCardTimestampLastSaved ?? 0)
        ? (characterFile.appCardTimestampLastChatted ?? 0)
        : (characterFile.appCardTimestampLastSaved ?? 0);

    Widget? trailingBadge;
    if (isOriginalVariant) {
      trailingBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Text(
          'ORIGINAL',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (isVariant) {
      trailingBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Text(
          'VARIANT',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: ImageThumbnail(file: characterFile, width: 40),
        ),
      ),
      title: Text(
        characterFile.card.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Last active: ${lastActivity == 0 ? "Never" : UtilsApp.timeAgo(lastActivity)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailingBadge,
      selected: isSelected,
      onTap: () => Navigator.pop(context, characterFile),
    );
  }
}
