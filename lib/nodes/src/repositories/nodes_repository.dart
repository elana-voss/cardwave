import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/nodes/src/models/chat_nodes_state.dart';
import 'package:cardwave/nodes/src/repositories/io_nodes.dart';
import 'package:cardwave_storage/cardwave_storage.dart';

/// Loads and saves a chat's NODES session state, resolving the on-disk
/// location from the owning character the same way [MemoryRepository]
/// does for the story-memory graph.
class NodesRepository {
  NodesRepository({required this.loggingService, required this.appStorage})
    : _io = IoNodes(loggingService: loggingService, appStorage: appStorage);

  final LoggingService loggingService;
  final AppStorage appStorage;
  final IoNodes _io;

  Future<ChatNodesState> loadState(CharacterFile file, String sessionId) =>
      _io.loadState(file.appCardChatsFolder, sessionId);

  Future<void> saveState(
    CharacterFile file,
    String sessionId,
    ChatNodesState state,
  ) => _io.saveState(file.appCardChatsFolder, sessionId, state);
}
