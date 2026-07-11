import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer tile that lets the user pick the image aspect ratio for the
/// active chat. Reads the effective aspect from the layered resolver
/// (session → character → app default) and writes the user's pick to
/// the session layer.
///
/// Hides itself when no image preset is assigned OR the selected image
/// model has no `optionsImage` roster (OR's chat-completions image path,
/// unknown NanoGpt models, Anthropic/Google) — users never see a
/// non-functional picker.
class TileImageAspectRatio extends StatelessWidget {
  const TileImageAspectRatio({
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

    final settings = context.watch<SettingsService>().settings;
    final resolved = resolveMedia(
      settings: settings,
      // LlmPureHelpers is an immutable stateless helper provided once —
      // `read`, not `watch`, is correct here. avoid_read_inside_build can't
      // tell the object never changes, so this hit is a false positive.
      // ignore: qcheck/avoid_read_inside_build
      pureHelpers: context.read<LlmPureHelpers>(),
      session: session,
      character: characterFile,
    );
    final imagePreset = resolved.imagePreset;
    if (imagePreset == null) return const SizedBox.shrink();

    final aspects = imagePreset.model.optionsImage?.aspectRatios ?? const [];
    if (aspects.isEmpty) return const SizedBox.shrink();

    final active = aspects.firstWhere(
      (a) => a.id == resolved.imageAspectRatioId,
      orElse: () => aspects.first,
    );

    return ListTile(
      leading: const Icon(Icons.aspect_ratio),
      title: Text(t.chat.tileImageAspectRatio.label),
      trailing: DrawerTrailingValue(active.label),
      onTap: () {
        unawaited(() async {
          final picked = await showSelectionDialog<String>(
            context: context,
            title: t.chat.tileImageAspectRatio.label,
            activeValue: active.id,
            options: [
              for (final a in aspects)
                SelectionOption(value: a.id, label: a.label),
            ],
          );
          if (picked == null) return;
          (session.configMedia ??= ConfigMediaSession()).setImagePreset(
            imagePreset.preset.id,
            picked,
          );
          onChanged();
        }());
      },
    );
  }
}
