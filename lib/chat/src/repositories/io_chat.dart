import 'dart:convert';

import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class IOChat {
  const IOChat({required this.loggingService, required this.appStorage});
  static const String _ttsFolder = 'tts';
  static const String _videoFolder = 'video';

  final LoggingService loggingService;
  final AppStorage appStorage;

  ChatSession _parseChatSession(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ChatSession.fromJson(json);
  }

  Future<ChatIndex> getChatIndex(
    String chatDirectoryPath, {
    VoidCallback? onRebuild,
  }) async {
    if (!await appStorage.directoryExists(
      StorageDomainEnum.cards,
      chatDirectoryPath,
    )) {
      return ChatIndex(entries: []);
    }

    final indexPath = p.posix.join(chatDirectoryPath, 'chats.index');
    try {
      if (await appStorage.fileExists(StorageDomainEnum.cards, indexPath)) {
        final content = await appStorage.readString(
          StorageDomainEnum.cards,
          indexPath,
        );
        final json = jsonDecode(content);
        return ChatIndex.fromJson(json as Map<String, dynamic>);
      }
    } on Exception catch (e) {
      loggingService.info('Index missing or corrupted, rebuilding: $e');
    }

    onRebuild?.call();
    return _rebuildIndex(chatDirectoryPath);
  }

  Future<ChatIndex> _rebuildIndex(String chatDirectoryPath) async {
    // Sessions live at <chatDir>/<sessionId>/session.json. Scan recursively
    // for all session.json files and extract the session ID from the parent
    // directory name.
    final allJsonPaths = await appStorage.listDirectory(
      StorageDomainEnum.cards,
      chatDirectoryPath,
      extensions: ['.json'],
      recursive: true,
    );
    final sessionPaths = allJsonPaths
        .where((path) => p.posix.basename(path) == 'session.json')
        .toList();

    const chunkSize = 10;
    final results = <ChatIndexEntry>[];

    for (var i = 0; i < sessionPaths.length; i += chunkSize) {
      final end = (i + chunkSize < sessionPaths.length)
          ? i + chunkSize
          : sessionPaths.length;
      final chunk = sessionPaths.sublist(i, end);

      final futures = chunk.map((filePath) async {
        try {
          final content = await appStorage.readString(
            StorageDomainEnum.cards,
            filePath,
          );
          final session = _parseChatSession(content);
          return ChatIndexEntry(
            id: session.id,
            ownerId: session.ownerId,
            name: session.name,
            lastActive: session.lastActive,
            messageCount: session.messages.length,
            isAssistant: session.isAssistant,
          );
        } on Exception catch (e, stackTrace) {
          loggingService.warning(
            'Error loading chat ${p.posix.basename(p.posix.dirname(filePath))}: $e',
            e,
            stackTrace,
          );
          return null;
        }
      });

      results.addAll((await Future.wait(futures)).whereType<ChatIndexEntry>());
    }

    results.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    final index = ChatIndex(entries: results);
    try {
      final indexPath = p.posix.join(chatDirectoryPath, 'chats.index');
      final indexString = jsonEncode(index.toJson());
      await appStorage.writeString(
        StorageDomainEnum.cards,
        indexPath,
        indexString,
      );
    } on Exception catch (e, stackTrace) {
      loggingService.warning('Error saving rebuilt index: $e', e, stackTrace);
    }

    return index;
  }

  Future<ChatSession?> getChat(String chatDirectoryPath, String chatId) async {
    final filePath = p.posix.join(chatDirectoryPath, chatId, 'session.json');
    if (await appStorage.fileExists(StorageDomainEnum.cards, filePath)) {
      try {
        final content = await appStorage.readString(
          StorageDomainEnum.cards,
          filePath,
        );
        return _parseChatSession(content);
      } on Exception catch (e) {
        loggingService.error('Error loading chat $chatId: $e');
      }
    }
    return null;
  }

  Future<ChatSession?> getLatestChat(
    String chatDirectoryPath, {
    VoidCallback? onRebuild,
    bool isAssistant = false,
  }) async {
    final index = await getChatIndex(chatDirectoryPath, onRebuild: onRebuild);
    final candidates = index.entries
        .where((e) => e.isAssistant == isAssistant)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    final latestEntry = candidates.reduce(
      (curr, next) => curr.lastActive > next.lastActive ? curr : next,
    );
    return getChat(chatDirectoryPath, latestEntry.id);
  }

  Future<void> saveChat(String chatDirectoryPath, ChatSession session) async {
    final filePath = p.posix.join(
      chatDirectoryPath,
      session.id,
      'session.json',
    );

    // Strip transient in-flight messages (still streaming, running tools,
    // generating media) so a concurrent debounced save can't persist them.
    // Dart is single-threaded; the swap is safe because `toJson()` is
    // synchronous and we restore the live list before the first await.
    final liveMessages = session.messages;
    final hasPlaceholders = liveMessages.any(
      (m) => m.waitingFor != BubbleWaitingForEnum.complete,
    );
    if (hasPlaceholders) {
      session.messages = liveMessages
          .where((m) => m.waitingFor == BubbleWaitingForEnum.complete)
          .toList(growable: false);
    }
    final jsonMap = session.toJson();
    if (hasPlaceholders) {
      session.messages = liveMessages;
    }
    final jsonString = jsonEncode(jsonMap);
    await appStorage.writeString(StorageDomainEnum.cards, filePath, jsonString);

    final indexPath = p.posix.join(chatDirectoryPath, 'chats.index');
    try {
      final index = await getChatIndex(chatDirectoryPath);
      index.entries.removeWhere((e) => e.id == session.id);
      final persistedCount = liveMessages
          .where((m) => m.waitingFor == BubbleWaitingForEnum.complete)
          .length;
      index.entries.insert(
        0,
        ChatIndexEntry(
          id: session.id,
          ownerId: session.ownerId,
          name: session.name,
          lastActive: session.lastActive,
          messageCount: persistedCount,
          isAssistant: session.isAssistant,
        ),
      );
      index.entries.sort((a, b) => b.lastActive.compareTo(a.lastActive));
      final indexContent = jsonEncode(index.toJson());
      await appStorage.writeString(
        StorageDomainEnum.cards,
        indexPath,
        indexContent,
      );
    } on Exception catch (e, stackTrace) {
      loggingService.warning('Error updating index: $e', e, stackTrace);
    }
  }

  Future<void> deleteChat(String chatDirectoryPath, String chatId) async {
    // Delete the entire session folder (session.json + generated images + thumbs).
    final sessionDir = p.posix.join(chatDirectoryPath, chatId);
    if (await appStorage.directoryExists(StorageDomainEnum.cards, sessionDir)) {
      await appStorage.deleteDirectory(StorageDomainEnum.cards, sessionDir);
    }

    final indexPath = p.posix.join(chatDirectoryPath, 'chats.index');
    try {
      final index = await getChatIndex(chatDirectoryPath);
      index.entries.removeWhere((e) => e.id == chatId);
      final indexContent = jsonEncode(index.toJson());
      await appStorage.writeString(
        StorageDomainEnum.cards,
        indexPath,
        indexContent,
      );
    } on Exception catch (e, stackTrace) {
      loggingService.warning(
        'Error updating index on delete: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> deleteAllChats(String chatDirectoryPath) async {
    if (await appStorage.directoryExists(
      StorageDomainEnum.cards,
      chatDirectoryPath,
    )) {
      await appStorage.deleteDirectory(
        StorageDomainEnum.cards,
        chatDirectoryPath,
      );
    }
  }

  Future<Uint8List?> readAudio(
    String chatDirectoryPath,
    String chatId,
    String fileName,
  ) async {
    final path = _audioPath(chatDirectoryPath, chatId, fileName);
    if (!await appStorage.fileExists(StorageDomainEnum.cards, path)) {
      return null;
    }
    try {
      final bytes = await appStorage.readBytes(StorageDomainEnum.cards, path);
      return Uint8List.fromList(bytes);
    } on Exception catch (e, st) {
      loggingService.error('IOChat.readAudio: $path', e, st);
      return null;
    }
  }

  Future<void> writeAudio(
    String chatDirectoryPath,
    String chatId,
    String fileName,
    Uint8List bytes,
  ) async {
    final path = _audioPath(chatDirectoryPath, chatId, fileName);
    await appStorage.writeBytes(StorageDomainEnum.cards, path, bytes);
    loggingService.logCache(
      'IOChat.writeAudio DONE: $path bytes=${bytes.length}',
    );
  }

  Future<void> deleteAudio(
    String chatDirectoryPath,
    String chatId,
    String fileName,
  ) async {
    final path = _audioPath(chatDirectoryPath, chatId, fileName);
    try {
      if (await appStorage.fileExists(StorageDomainEnum.cards, path)) {
        await appStorage.deleteFile(StorageDomainEnum.cards, path);
      }
    } on Exception catch (e, st) {
      loggingService.error('IOChat.deleteAudio: $path', e, st);
    }
  }

  String _audioPath(String chatDirectoryPath, String chatId, String fileName) =>
      p.posix.join(chatDirectoryPath, chatId, _ttsFolder, fileName);

  /// Writes generated video bytes under `<chatDir>/<chatId>/video/`. Returns
  /// the cards-domain-relative path so callers can persist it on the
  /// `ChatSwipe`. Best-effort directory creation — AppStorage handles that.
  Future<String> writeVideo(
    String chatDirectoryPath,
    String chatId,
    String fileName,
    Uint8List bytes,
  ) async {
    final path = p.posix.join(
      chatDirectoryPath,
      chatId,
      _videoFolder,
      fileName,
    );
    await appStorage.writeBytes(StorageDomainEnum.cards, path, bytes);
    loggingService.logCache(
      'IOChat.writeVideo DONE: $path bytes=${bytes.length}',
    );
    return path;
  }

  /// Generated images live next to the chat's JSON file (no subfolder),
  /// matching the pre-extraction layout the cards UI scans for thumbnails.
  Future<String> writeImage(
    String chatDirectoryPath,
    String chatId,
    String fileName,
    Uint8List bytes,
  ) async {
    final path = p.posix.join(chatDirectoryPath, chatId, fileName);
    await appStorage.writeBytes(StorageDomainEnum.cards, path, bytes);
    loggingService.logCache(
      'IOChat.writeImage DONE: $path bytes=${bytes.length}',
    );
    return path;
  }
}
