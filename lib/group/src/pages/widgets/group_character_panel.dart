import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:cardwave/group/src/pages/widgets/group_character_picker.dart';
import 'package:cardwave/group/src/pages/widgets/group_character_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Left panel: lists participating characters with mute and talkativeness info.
class GroupCharacterPanel extends StatelessWidget {
  const GroupCharacterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupChatController>();
    final characters = controller.characters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Padding(
        //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        //   child: Text(
        //     'Characters',
        //     style: Theme.of(context).textTheme.titleSmall?.copyWith(
        //       color: Theme.of(context).colorScheme.onSurfaceVariant,
        //     ),
        //   ),
        // ),
        // Padding(
        //   padding: const EdgeInsets.all(12),
        //   child: FilledButton.tonalIcon(
        //     onPressed: () => GroupCharacterPicker.show(context),
        //     icon: const Icon(Icons.add, size: 18),
        //     label: const Text('Add Character'),
        //   ),
        // ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('group-add-character-drawer'),
              onPressed: () => GroupCharacterPicker.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Character'),
            ),
          ),
        ),
        Expanded(
          child: characters.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No characters yet.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView(
                  // padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: characters
                      .map((e) => GroupCharacterTile(character: e))
                      .toList(),
                ),
        ),
      ],
    );
  }
}
