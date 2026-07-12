part of 'message_actions_row.dart';

class _TtsPlayButton extends StatelessWidget {
  const _TtsPlayButton({
    required this.message,
    required this.metaStyle,
    required this.isStreamingThisMessage,
    required this.chatSession,
  });
  final ChatMessage message;
  final TextStyle metaStyle;
  final bool isStreamingThisMessage;
  final ChatSession? chatSession;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final tts = context.watch<TextToSpeechController>();
    // Resolve the speaking character for this message so per-character
    // media settings (voice, preset) flow into the resolver. In 1:1 chats
    // this is always the same CharacterFile; in group chats it varies by
    // message.role / characterId. Read (not watch): an effectively-pure
    // lookup keyed on the immutable message; the button rebuilds with the
    // chat list.
    // ignore: qcheck/avoid_read_inside_build
    final controller = context.read<BaseChatViewController>();
    final character = controller.resolveCharacterFile(message);
    // Subscribe to the canSpeak boolean rather than the whole settings
    // object — bubble only rebuilds when speak-availability flips, not on
    // every unrelated settings change. Live settings are re-read inside the
    // onPressed callback below at click time.
    final canSpeak = context.select<SettingsService, bool>(
      (s) => tts.canSpeak(
        settings: s.settings,
        session: chatSession,
        character: character,
      ),
    );
    if (!canSpeak) {
      return const SizedBox.shrink();
    }

    final isThisPlaying = identical(tts.playingMessage, message);
    final showSpinner = isThisPlaying && tts.isLoading;

    // Resolve the owning chats folder via the view controller — 1:1 returns
    // the character's chats folder, group returns the group's chats folder.
    // TextToSpeechController uses this to persist MP3s.
    final chatsFolder = controller.chatsFolder;

    return IconButton(
      key: const Key('msg-tts-play'),
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      iconSize: 20,
      color: metaStyle.color,
      disabledColor: metaStyle.color?.withValues(alpha: 0.3),
      tooltip: isThisPlaying
          ? t.chat.ttsPlayButton.stopTooltip
          : t.chat.ttsPlayButton.readAloudTooltip,
      icon: showSpinner
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isThisPlaying ? Icons.stop : Icons.play_arrow),
      onPressed: isStreamingThisMessage
          ? null
          : () async {
              if (isThisPlaying) {
                await tts.stop();
                return;
              }
              try {
                await tts.play(
                  message: message,
                  settings: context.read<SettingsService>().settings,
                  chatSession: chatSession,
                  character: character,
                  chatsFolder: chatsFolder,
                );
              } on Exception catch (e) {
                final msg = e is LlmFetchException
                    ? e.userMessage
                    : t.chat.ttsPlayButton.ttsFailed;
                NavigationService().showSnackBar(msg);
              }
            },
    );
  }
}
