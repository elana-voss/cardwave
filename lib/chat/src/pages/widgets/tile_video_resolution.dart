import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TileVideoResolution extends StatelessWidget {
  const TileVideoResolution({
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
    final videoPreset = resolved.videoPreset;
    if (videoPreset == null) return const SizedBox.shrink();

    final resolutions = videoPreset.model.optionsVideo?.resolutions ?? const [];
    if (resolutions.isEmpty) return const SizedBox.shrink();

    final active = resolutions.firstWhere(
      (r) => r.id == resolved.videoResolutionId,
      orElse: () => resolutions.first,
    );

    return ListTile(
      leading: const Icon(Icons.high_quality),
      title: const Text('Resolution'),
      trailing: DrawerTrailingValue(active.label),
      onTap: () {
        unawaited(() async {
          final picked = await showSelectionDialog<String>(
            context: context,
            title: 'Resolution',
            activeValue: active.id,
            options: [
              for (final r in resolutions)
                SelectionOption(value: r.id, label: r.label),
            ],
          );
          if (picked == null) return;
          (session.configMedia ??= ConfigMediaSession()).setVideoPreset(
            videoPreset.preset.id,
            picked,
            resolved.videoAspectRatioId,
            resolved.videoDurationSeconds,
          );
          onChanged();
        }());
      },
    );
  }
}
