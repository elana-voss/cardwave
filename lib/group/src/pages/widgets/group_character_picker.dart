import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// AppDialog that adds one or more characters to the group in a single commit.
/// Rows use the circle-icon selection pattern (radio_button_unchecked →
/// check_circle); the user taps any number, then confirms with "Add N".
class GroupCharacterPicker extends StatefulWidget {
  const GroupCharacterPicker({super.key});

  // Public entry point — `Dialog.show(ctx)` is the dialog-opening convention.
  // ignore: qcheck/prefer_widget_private_members
  static Future<void> show(BuildContext context) {
    final controller = context.read<GroupChatController>();
    return showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider<GroupChatController>.value(
        value: controller,
        child: const GroupCharacterPicker(),
      ),
    );
  }

  @override
  State<GroupCharacterPicker> createState() => _GroupCharacterPickerState();
}

class _GroupCharacterPickerState extends State<GroupCharacterPicker> {
  final TextEditingController _searchController = TextEditingController();
  bool _favoritesOnly = false;
  final Set<String> _selectedIds = {};
  List<CharacterFile>? _allCharacters;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    unawaited(_load());
  }

  Future<void> _load() async {
    // The load must finish before the mounted re-check; moving the declaration
    // inside the guard would put the await there and let setState run after a
    // later async gap.
    final all = await context.read<CharacterService>().loadAll();
    if (mounted) setState(() => _allCharacters = all);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final controller = context.watch<GroupChatController>();
    final allCharacters = _allCharacters;
    if (allCharacters == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final alreadyAdded = <String>{
      for (final c in controller.characters) c.appCardId,
    };
    final queryLower = _searchController.text.toLowerCase();

    final filtered =
        allCharacters.where((c) {
          if (alreadyAdded.contains(c.appCardId)) return false;
          if (_favoritesOnly && !c.card.cardwaveData.isFavorite) return false;
          if (queryLower.isNotEmpty &&
              !c.card.name.toLowerCase().contains(queryLower)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) =>
              a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase()),
        );

    final selectedCount = _selectedIds.length;

    return AppDialog(
      isScrollable: false,
      actions: [
        FilledButton(
          onPressed: selectedCount == 0
              ? null
              : () => _commitSelection(controller, allCharacters),
          child: Text(
            selectedCount == 0
                ? t.group.groupCharacterPicker.addButton
                : t.group.groupCharacterPicker.addWithCountButton(
                    count: selectedCount,
                  ),
          ),
        ),
      ],
      builder: (ctx, isMobile) {
        return Column(
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: AppSearchField(controller: _searchController),
                ),
                ToggleButtons(
                  isSelected: [_favoritesOnly],
                  onPressed: (_) =>
                      setState(() => _favoritesOnly = !_favoritesOnly),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 48,
                  ),
                  children: [
                    Tooltip(
                      message: t.group.groupCharacterPicker.favoritesTooltip,
                      child: const Icon(Icons.favorite, size: 18),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _emptyMessage(),
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final character = filtered[i];
                        final isSelected = _selectedIds.contains(
                          character.appCardId,
                        );
                        return _CharacterRow(
                          character: character,
                          isSelected: isSelected,
                          onTap: () => _toggle(character.appCardId),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _emptyMessage() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      return t.group.groupCharacterPicker.noMatchMessage(query: query);
    }
    if (_favoritesOnly) {
      return t.group.groupCharacterPicker.noFavoritesMessage;
    }
    return t.group.groupCharacterPicker.allAddedMessage;
  }

  void _toggle(String appCardId) {
    setState(() {
      if (!_selectedIds.add(appCardId)) _selectedIds.remove(appCardId);
    });
  }

  void _commitSelection(
    GroupChatController controller,
    List<CharacterFile> allCharacters,
  ) {
    for (final character in allCharacters) {
      if (_selectedIds.contains(character.appCardId)) {
        controller.addCharacter(character);
      }
    }
    Navigator.pop(context);
  }
}

class _CharacterRow extends StatelessWidget {
  const _CharacterRow({
    required this.character,
    required this.isSelected,
    required this.onTap,
  });
  final CharacterFile character;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = character.card.description;
    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: ImageThumbnail(file: character, width: 40),
        ),
      ),
      title: Text(
        character.card.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: description.isNotEmpty
          ? Text(description, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      selected: isSelected,
      onTap: onTap,
    );
  }
}
