import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/pages/widgets/tile_ai_provider.dart'
    show TileAiProvider;
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer tile for the image-generation preset (model) for this chat.
/// Mirrors [TileAiProvider]. User's pick writes to the session layer,
/// overriding the character and app-default layers. Hides itself when no
/// image-capable preset is configured.
class TileImagePreset extends StatelessWidget {
  const TileImagePreset({
    required this.chatSession,
    required this.onChanged,
    super.key,
    this.characterFile,
  });
  final ChatSession? chatSession;
  final CharacterFile? characterFile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final session = chatSession;
    if (session == null) return const SizedBox.shrink();

    final profiles = context.watch<SettingsService>().settings.providerConfigs;
    if (profiles.isEmpty) return const SizedBox.shrink();

    // LlmPureHelpers is an immutable stateless helper provided once —
    // `read`, not `watch`, is correct here. avoid_read_inside_build can't
    // tell the object never changes, so this hit is a false positive.
    // ignore: qcheck/avoid_read_inside_build
    final pureHelpers = context.read<LlmPureHelpers>();
    final validPresets = pureHelpers.getValidPresetsForDomain(
      LlmProviderDomainEnum.image,
      profiles,
    );
    if (validPresets.isEmpty) return const SizedBox.shrink();

    final settings = context.watch<SettingsService>().settings;
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: pureHelpers,
      session: session,
      character: characterFile,
    );
    final activePresetId = resolved.imagePreset?.preset.id;
    final activeEntry = activePresetId == null
        ? null
        : validPresets.where((e) => e.config.id == activePresetId).firstOrNull;

    return ListTile(
      leading: const Icon(Icons.image_outlined),
      title: const Text('Image Model'),
      trailing: DrawerTrailingValue(
        activeEntry == null ? 'Tap to choose' : activeEntry.config.name,
      ),
      onTap: () async {
        // Capture before the async gap so we don't reach into `context`
        // after it may have been unmounted.
        final llm = pureHelpers;
        Navigator.of(context, rootNavigator: true).pop();
        final pickedId = await DialogPresetPicker.show(
          context: context,
          title: Text(
            'Choose an image model',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          validPresets: validPresets,
          activePresetId: activePresetId,
        );
        if (pickedId == null) return;
        final newPreset = llm.resolvePresetOrNull(
          configId: pickedId,
          providers: profiles,
        );
        if (newPreset == null) return;
        (session.configMedia ??= ConfigMediaSession()).setImagePreset(
          pickedId,
          firstImageAspectRatioId(newPreset.model),
        );
        onChanged();
      },
    );
  }
}
