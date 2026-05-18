import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer tile for the TTS voice. Reads the effective voice from the
/// layered resolver (session → character → app default, validated against
/// the resolved model's roster) and writes the user's pick to the session
/// layer. Parent is responsible for persisting the session after
/// [onChanged] fires.
class TileTtsVoice extends StatelessWidget {
  const TileTtsVoice({
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
    final ttsPreset = resolved.ttsPreset;
    if (ttsPreset == null) return const SizedBox.shrink();

    final voices = ttsPreset.model.optionsTts?.voices ?? const [];
    if (voices.isEmpty) return const SizedBox.shrink();

    final active = voices.firstWhere(
      (v) => v.id == resolved.ttsVoiceId,
      orElse: () => voices.first,
    );

    return ListTile(
      leading: const Icon(Icons.record_voice_over),
      title: const Text('Voice'),
      trailing: DrawerTrailingValue(active.label),
      onTap: () {
        unawaited(() async {
          final pickedId = await showSelectionDialog<String>(
            context: context,
            title: 'Voice',
            activeValue: active.id,
            options: [
              for (final voice in voices)
                SelectionOption(
                  value: voice.id,
                  label: voice.label,
                  subtitle: voice.tone?.isNotEmpty == true ? voice.tone : null,
                ),
            ],
          );
          if (pickedId == null) return;
          (session.configMedia ??= ConfigMediaSession()).setTtsPreset(
            ttsPreset.preset.id,
            pickedId,
            resolved.ttsLanguageCode,
          );
          onChanged();
        }());
      },
    );
  }
}
