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

class TileVideoDuration extends StatelessWidget {
  const TileVideoDuration({
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

    final durations = videoPreset.model.optionsVideo?.durations ?? const [];
    if (durations.isEmpty) return const SizedBox.shrink();

    final active = durations.firstWhere(
      (d) => d.seconds == resolved.videoDurationSeconds,
      orElse: () => durations.first,
    );

    return ListTile(
      leading: const Icon(Icons.timer),
      title: Text(t.chat.tileVideoDuration.label),
      trailing: DrawerTrailingValue(active.label),
      onTap: () {
        unawaited(() async {
          final picked = await showSelectionDialog<int>(
            context: context,
            title: t.chat.tileVideoDuration.label,
            activeValue: active.seconds,
            options: [
              for (final d in durations)
                SelectionOption(value: d.seconds, label: d.label),
            ],
          );
          if (picked == null) return;
          (session.configMedia ??= ConfigMediaSession()).setVideoPreset(
            videoPreset.preset.id,
            resolved.videoResolutionId,
            resolved.videoAspectRatioId,
            picked,
          );
          onChanged();
        }());
      },
    );
  }
}
