import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/repositories/chat_repository.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';

/// Owns the audio player, the currently-playing-message tracker, and the
/// disk cache for synthesized speech. Drives playback by calling the
/// (pure) [TextToSpeechService] for bytes and routing them to the player.
///
/// Cache key is hashed from voice + language + content; that's why edit
/// and delete paths must call [invalidateOnEdit] / [invalidateOnDelete]
/// with the same resolution context [play] used.
class TextToSpeechController extends ChangeNotifier {
  TextToSpeechController({
    required TextToSpeechService ttsService,
    required LlmPureHelpers pureHelpers,
    required ChatRepository chatRepository,
  }) : _ttsService = ttsService,
       _pureHelpers = pureHelpers,
       _chatRepository = chatRepository {
    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      _playingMessage = null;
      _isLoading = false;
      notifyListeners();
    });
  }

  final TextToSpeechService _ttsService;
  final LlmPureHelpers _pureHelpers;
  final ChatRepository _chatRepository;
  final AudioPlayer _player = AudioPlayer();
  // `late final` is required here: it's assigned in the constructor body
  // (it references `_player`, so it can't go in the initializer list), and a
  // plain `final` field can't be assigned in the body.
  // ignore: qcheck/avoid_unnecessary_late_fields
  late final StreamSubscription<void> _playerCompleteSubscription;
  ChatMessage? _playingMessage;
  bool _isLoading = false;

  ChatMessage? get playingMessage => _playingMessage;
  bool get isLoading => _isLoading;

  /// True when a TTS preset resolves for the given session + character
  /// context and the resolved model has a populated voice roster (meaning
  /// `populateTtsVoices` has run). UI gates the play button on this —
  /// provider-agnostic. Both [session] and [character] are optional so the
  /// gate works for group chats (character varies per message) and for
  /// app-level checks.
  bool canSpeak({
    required AppSettings settings,
    ChatSession? session,
    CharacterFile? character,
  }) {
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: _pureHelpers,
      session: session,
      character: character,
    );
    return resolved.ttsPreset != null;
  }

  /// Synthesize-or-replay for [message]. When [chatsFolder] and
  /// [chatSession] are provided the result is persisted under
  /// `<chatsFolder>/<session.id>/tts/`; subsequent plays of the same message
  /// + content hit disk instead of the API. Pass both as null for one-offs
  /// that shouldn't be cached.
  Future<void> play({
    required ChatMessage message,
    required AppSettings settings,
    String? chatsFolder,
    ChatSession? chatSession,
    CharacterFile? character,
  }) async {
    await stop();
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: _pureHelpers,
      session: chatSession,
      character: character,
    );
    final ttsPreset = resolved.ttsPreset;
    if (ttsPreset == null) return;

    final config = resolved.toTtsConfig();

    _playingMessage = message;
    _isLoading = true;
    notifyListeners();
    try {
      final cached = chatsFolder != null && chatSession != null
          ? await _chatRepository.loadMessageAudio(
              chatsFolder,
              chatSession,
              message,
              config,
            )
          : null;
      final Uint8List bytes;
      if (cached != null) {
        bytes = cached;
      } else {
        bytes = await _ttsService.synthesize(
          provider: ttsPreset.provider,
          modelId: ttsPreset.model.id,
          text: message.content,
          voiceId: config.voiceId,
          languageCode: config.languageCode,
        );
        if (chatsFolder != null && chatSession != null) {
          // Cache write is best-effort: a disk-full / permission error must
          // not prevent playback of bytes the user already paid to synthesize.
          try {
            await _chatRepository.saveMessageAudio(
              chatsFolder,
              chatSession,
              message,
              config,
              bytes,
            );
          } on Exception catch (e) {
            ttsLogger.warning(
              LlmCacheEvent(
                message:
                    'TextToSpeechController: WRITE FAILED '
                    'msgTs=${message.timestamp} err=$e',
              ),
            );
          }
        }
      }
      if (!identical(_playingMessage, message)) return;
      _isLoading = false;
      notifyListeners();
      await _player.play(BytesSource(bytes));
    } catch (_) {
      _playingMessage = null;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_playingMessage == null) return;
    _playingMessage = null;
    _isLoading = false;
    await _player.stop();
    notifyListeners();
  }

  /// Settings test button: synthesize + play a fixed phrase for an arbitrary
  /// provider config. Stops any in-progress chat-bubble playback first.
  Future<void> testSpeakFor({
    required LlmProviderConfig provider,
    required String modelId,
    required String text,
    required String voiceId,
    required String languageCode,
  }) async {
    await stop();
    final bytes = await _ttsService.synthesize(
      provider: provider,
      modelId: modelId,
      text: text,
      voiceId: voiceId,
      languageCode: languageCode,
    );
    await _player.play(BytesSource(bytes));
  }

  /// Called from the chat controller's edit path with the **previous**
  /// content so any cached audio for the stale text is removed. Needs the
  /// same resolution context [play] uses so the cache key (hashed from
  /// voice + language) matches the one that wrote the file.
  Future<void> invalidateOnEdit({
    required String chatsFolder,
    required ChatSession chatSession,
    required int messageTimestamp,
    required String previousContent,
    required AppSettings settings,
    CharacterFile? character,
  }) async {
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: _pureHelpers,
      session: chatSession,
      character: character,
    );
    if (resolved.ttsPreset == null) return;
    final config = resolved.toTtsConfig();
    await _chatRepository.deleteMessageAudio(
      chatsFolder,
      chatSession,
      messageTimestamp,
      previousContent,
      config,
    );
  }

  /// Called from the chat controller's delete path — drops every swipe's
  /// cached audio for the message.
  Future<void> invalidateOnDelete({
    required String chatsFolder,
    required ChatSession chatSession,
    required ChatMessage message,
    required AppSettings settings,
    CharacterFile? character,
  }) async {
    final resolved = resolveMedia(
      settings: settings,
      pureHelpers: _pureHelpers,
      session: chatSession,
      character: character,
    );
    if (resolved.ttsPreset == null) return;
    final config = resolved.toTtsConfig();
    await _chatRepository.deleteAllMessageAudio(
      chatsFolder,
      chatSession,
      message,
      config,
    );
  }

  @override
  void dispose() {
    unawaited(_playerCompleteSubscription.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }
}
