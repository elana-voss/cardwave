import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/repositories/io_chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ChatRepository {
  ChatRepository({required this.loggingService, required this.appStorage})
    : _ioChat = IOChat(loggingService: loggingService, appStorage: appStorage);
  final LoggingService loggingService;
  final AppStorage appStorage;
  final IOChat _ioChat;

  Future<ChatIndex> getChatsForCharacter(
    CharacterFile file, {
    VoidCallback? onRebuild,
  }) {
    return _ioChat.getChatIndex(file.appCardChatsFolder, onRebuild: onRebuild);
  }

  Future<ChatSession?> getChat(CharacterFile file, String chatId) {
    return _ioChat.getChat(file.appCardChatsFolder, chatId);
  }

  Future<ChatSession?> getLatestChatForCharacter(
    CharacterFile file, {
    VoidCallback? onRebuild,
    bool isAssistant = false,
  }) {
    return _ioChat.getLatestChat(
      file.appCardChatsFolder,
      isAssistant: isAssistant,
      onRebuild: onRebuild,
    );
  }

  Future<void> saveChat(CharacterFile file, ChatSession session) async {
    try {
      await _ioChat.saveChat(file.appCardChatsFolder, session);
    } catch (e, st) {
      loggingService.error(
        'ChatRepository.saveChat: failed file="${file.card.name}" '
        'chatId=${session.id}',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<void> deleteChat(CharacterFile file, String chatId) async {
    await _ioChat.deleteChat(file.appCardChatsFolder, chatId);
  }

  Future<void> deleteAllChatsForCharacter(CharacterFile file) async {
    await _ioChat.deleteAllChats(file.appCardChatsFolder);
  }

  /// Audio cache methods take a [chatsFolder] string rather than a
  /// [CharacterFile] so they work for both 1:1 (character's chats folder) and
  /// group (group's chats folder) without branching on ownership. Callers
  /// resolve the folder via `BaseChatViewController.chatsFolder`.
  Future<Uint8List?> loadMessageAudio(
    String chatsFolder,
    ChatSession session,
    ChatMessage message,
    ConfigTts config,
  ) {
    final fileName = _audioFileName(message.timestamp, message.content, config);
    loggingService.logCache(
      'ChatRepository.loadMessageAudio: dir="$chatsFolder/${session.id}/tts" file="$fileName"',
    );
    return _ioChat.readAudio(chatsFolder, session.id, fileName);
  }

  Future<void> saveMessageAudio(
    String chatsFolder,
    ChatSession session,
    ChatMessage message,
    ConfigTts config,
    Uint8List bytes,
  ) async {
    final fileName = _audioFileName(message.timestamp, message.content, config);
    loggingService.logCache(
      'ChatRepository.saveMessageAudio: dir="$chatsFolder/${session.id}/tts" file="$fileName" bytes=${bytes.length}',
    );
    await _ioChat.writeAudio(
      chatsFolder,
      session.id,
      fileName,
      bytes,
    );
  }

  Future<void> deleteMessageAudio(
    String chatsFolder,
    ChatSession session,
    int messageTimestamp,
    String previousContent,
    ConfigTts config,
  ) async {
    final fileName = _audioFileName(messageTimestamp, previousContent, config);
    loggingService.logCache(
      'ChatRepository.deleteMessageAudio: dir="$chatsFolder/${session.id}/tts" file="$fileName"',
    );
    await _ioChat.deleteAudio(chatsFolder, session.id, fileName);
  }

  /// Writes generated video bytes and returns the cards-domain-relative
  /// path; caller stores it on `ChatSwipe.videoPath`. Filename bakes in the
  /// message timestamp + swipe index + config hash so regenerating a swipe
  /// with different params lands on a new file and leaves old ones on disk.
  /// Persists a generated image and its `.thumb.png` sidecar to the session's
  /// directory and returns the cards-domain-relative path of the main file.
  /// The thumbnail is always PNG (per [UtilsImage.thumbnailPathFor]) so JPEG
  /// originals are decoded and re-encoded by [UtilsImage.generateThumbnailBytes]
  /// the same way PNG originals are.
  Future<String> saveMessageImage({
    required String chatDirectoryPath,
    required String sessionId,
    required Uint8List bytes,
  }) async {
    final uuid = UtilsId.generateId('img');
    final fileName = '$uuid${UtilsImage.detectExtension(bytes)}';
    final relativePath = await _ioChat.writeImage(
      chatDirectoryPath,
      sessionId,
      fileName,
      bytes,
    );

    final thumbBytes = await UtilsImage.generateThumbnailBytes(bytes);
    if (thumbBytes != null) {
      await _ioChat.writeImage(
        chatDirectoryPath,
        sessionId,
        p.posix.basename(UtilsImage.thumbnailPathFor(relativePath)),
        thumbBytes,
      );
    }

    return relativePath;
  }

  Future<String> saveMessageVideo(
    CharacterFile file,
    ChatSession session,
    ChatMessage message,
    ConfigVideo config,
    Uint8List bytes,
  ) {
    final hash = UtilsHash.fnv1a64Hex(
      '${config.resolutionId}|${config.aspectRatioId}|'
      '${config.durationSeconds}|${message.content}',
    );
    final fileName = 'vid_${message.timestamp}_${message.swipeIndex}_$hash.mp4';
    return _ioChat.writeVideo(
      file.appCardChatsFolder,
      session.id,
      fileName,
      bytes,
    );
  }

  Future<void> deleteAllMessageAudio(
    String chatsFolder,
    ChatSession session,
    ChatMessage message,
    ConfigTts config,
  ) async {
    for (final swipe in message.swipes) {
      final fileName = _audioFileName(message.timestamp, swipe.content, config);
      loggingService.logCache(
        'ChatRepository.deleteAllMessageAudio: dir="$chatsFolder/${session.id}/tts" file="$fileName"',
      );
      await _ioChat.deleteAudio(chatsFolder, session.id, fileName);
    }
  }

  /// Cache file name `{timestamp}_{hash8}.mp3`. Timestamp is stable across
  /// edits; the hash bakes in voice + language + cleaned text so any of
  /// those changing yields a different filename (old MP3s stay on disk).
  String _audioFileName(int timestamp, String content, ConfigTts config) {
    final hash = UtilsHash.fnv1a64Hex(
      '${config.voiceId}|${config.languageCode}|${UtilsApp.cleanForTts(content)}',
    );
    return '${timestamp}_$hash.mp3';
  }
}
