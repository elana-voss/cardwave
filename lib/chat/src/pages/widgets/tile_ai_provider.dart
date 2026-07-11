import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/routing/route_edit_preset.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TileAiProvider extends StatelessWidget {
  const TileAiProvider({
    required this.chatSession,
    required this.characterFile,
    required this.onChanged,
    super.key,
  });
  final ChatSession? chatSession;
  final CharacterFile? characterFile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (chatSession == null) return const SizedBox.shrink();

    final profiles = context.watch<SettingsService>().settings.providerConfigs;
    if (profiles.isEmpty) return const SizedBox.shrink();

    // LlmPureHelpers is an immutable stateless helper provided once —
    // `read`, not `watch`, is correct here. avoid_read_inside_build can't
    // tell the object never changes, so this hit is a false positive.
    // ignore: qcheck/avoid_read_inside_build
    final pureHelpers = context.read<LlmPureHelpers>();
    final textCapablePresets = pureHelpers.getValidPresetsForDomain(
      LlmProviderDomainEnum.chat,
      profiles,
    );
    if (textCapablePresets.isEmpty) return const SizedBox.shrink();

    final activePresetId = chatSession!.modelPresetId;
    final activePresetEntry = textCapablePresets
        .where((entry) => entry.config.id == activePresetId)
        .firstOrNull;
    final hasValidActivePreset = activePresetEntry != null;
    final errorColor = Theme.of(context).colorScheme.error;

    return ListTile(
      leading: Icon(
        hasValidActivePreset ? Icons.smart_toy : Icons.error_outline,
        color: hasValidActivePreset ? null : errorColor,
      ),
      title: Text(t.chat.tileAiProvider.modelLabel),
      trailing: hasValidActivePreset
          ? DrawerTrailingValue(
              activePresetEntry.config.name,
              suffix: InkWell(
                onTap: () {
                  unawaited(() async {
                    Navigator.of(context, rootNavigator: true).pop();
                    await RouteEditPreset().execute(context, activePresetId);
                    onChanged();
                  }());
                },
                child: const Icon(Icons.settings, size: 18),
              ),
            )
          : Text(
              t.chat.tileAiProvider.invalidLabel,
              style: TextStyle(color: errorColor),
            ),
      onTap: () {
        final chatService = context.read<ChatService>();
        Navigator.of(context, rootNavigator: true).pop();
        unawaited(() async {
          final pickedId = await DialogPresetPicker.show(
            context: context,
            title: Text(
              t.chat.tileAiProvider.chooseModelTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            validPresets: textCapablePresets,
            activePresetId: activePresetId,
          );
          if (pickedId == null) return;
          chatSession!.modelPresetId = pickedId;
          if (characterFile != null) {
            await chatService.updateChat(characterFile!, chatSession!);
          }
          onChanged();
        }());
      },
    );
  }
}
