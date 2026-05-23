import 'package:cardwave/character/character.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GroupCharacterTile extends StatelessWidget {
  const GroupCharacterTile({required this.character, super.key});
  final CharacterFile character;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupChatController>();
    final isMuted = controller.isMuted(character.appCardId);
    final isLastSpeaker =
        controller.lastSpeaker?.appCardId == character.appCardId;
    final isGenerating = controller.isGenerating;
    final isAuto = controller.isAutoChatActive;
    final talkativeness = character.card.cardwaveData.talkativeness;
    final scheme = Theme.of(context).colorScheme;

    final highlight = isLastSpeaker ? scheme.secondaryContainer : null;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: highlight,
        collapsedBackgroundColor: highlight,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          character.card.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: IconButton(
          key: const Key('group-character-speak'),
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Make this character speak',
          onPressed: (isGenerating || isAuto || isMuted)
              ? null
              : () => controller.generateReplyFor(character),
        ),
        children: [
          ListTile(
            leading: Icon(isMuted ? Icons.volume_off : Icons.volume_up),

            onTap: () => controller.toggleMute(character.appCardId),
            title: LinearProgressIndicator(
              value: talkativeness,
              minHeight: 4,
              borderRadius: BorderRadius.all(Radius.circular(2)),
              backgroundColor: scheme.surfaceContainerHighest,
              color: isMuted
                  ? scheme.onSurface.withValues(alpha: 0.2)
                  : scheme.primary,
            ),
          ),
          ListTile(
            key: const Key('group-character-remove'),
            leading: const Icon(Icons.close),
            title: const Text('Remove from chat'),
            onTap: () => controller.removeCharacter(character.appCardId),
          ),
        ],
      ),
    );
  }
}
