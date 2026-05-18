import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer tile for the TTS language. Reads the effective language from
/// the layered resolver (session → character → app default) and writes
/// the user's pick to the session layer. Parent is responsible for
/// persisting the session after [onChanged] fires.
class TileTtsLanguage extends StatelessWidget {
  const TileTtsLanguage({
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

    final languages = ttsPreset.model.optionsTts?.languages ?? const [];
    if (languages.isEmpty) return const SizedBox.shrink();

    final active = languages.firstWhere(
      (l) => l.code == resolved.ttsLanguageCode,
      orElse: () => languages.first,
    );

    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('Language'),
      trailing: DrawerTrailingValue(active.label),
      onTap: () {
        unawaited(() async {
          final pickedCode = await showSelectionDialog<String>(
            context: context,
            title: 'Language',
            activeValue: active.code,
            options: [
              for (final lang in languages)
                SelectionOption(
                  value: lang.code,
                  label: lang.label,
                  subtitle: lang.code,
                ),
            ],
          );
          if (pickedCode == null) return;
          (session.configMedia ??= ConfigMediaSession()).setTtsPreset(
            ttsPreset.preset.id,
            resolved.ttsVoiceId,
            pickedCode,
          );
          onChanged();
        }());
      },
    );
  }
}
