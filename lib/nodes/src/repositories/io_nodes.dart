import 'dart:convert';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/models/chat_nodes_state.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:path/path.dart' as p;

/// Reads and writes one chat's NODES session state. Layout mirrors the
/// chat session and the memory graph next door:
/// `<chatDir>/<sessionId>/nodes/state.json`.
class IoNodes {
  const IoNodes({required this.loggingService, required this.appStorage});

  final LoggingService loggingService;
  final AppStorage appStorage;

  static const String _nodesFolder = 'nodes';
  static const String _stateFile = 'state.json';

  /// Loads the state for [sessionId] under [chatDirectoryPath], or a fresh
  /// empty [ChatNodesState] when none is saved. A file that fails to parse
  /// is treated as a stale cache (the chat itself is the source of truth
  /// for replay): the failure is logged and an empty state returned so the
  /// engine starts over rather than crashing.
  Future<ChatNodesState> loadState(
    String chatDirectoryPath,
    String sessionId,
  ) async {
    final path = _statePath(chatDirectoryPath, sessionId);
    if (!await appStorage.fileExists(StorageDomainEnum.cards, path)) {
      return ChatNodesState();
    }
    try {
      final content = await appStorage.readString(
        StorageDomainEnum.cards,
        path,
      );
      return ChatNodesState.fromJson(
        jsonDecode(content) as Map<String, dynamic>,
      );
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'NODES state at $path unreadable; starting the chat fresh.',
        error,
        stackTrace,
      );
      return ChatNodesState();
    }
  }

  Future<void> saveState(
    String chatDirectoryPath,
    String sessionId,
    ChatNodesState state,
  ) => appStorage.writeString(
    StorageDomainEnum.cards,
    _statePath(chatDirectoryPath, sessionId),
    jsonEncode(state.toJson()),
  );

  String _statePath(String chatDirectoryPath, String sessionId) =>
      p.posix.join(chatDirectoryPath, sessionId, _nodesFolder, _stateFile);
}
