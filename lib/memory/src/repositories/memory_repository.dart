import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/memory/src/repositories/io_memory.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:cardwave_storage/cardwave_storage.dart';

/// Loads and saves a chat's story-memory graph, resolving the on-disk
/// location from the owning character the same way [ChatRepository] does for
/// chat sessions.
class MemoryRepository {
  MemoryRepository({required this.loggingService, required this.appStorage})
    : _io = IoMemory(loggingService: loggingService, appStorage: appStorage);

  final LoggingService loggingService;
  final AppStorage appStorage;
  final IoMemory _io;

  Future<MemoryGraph> loadGraph(CharacterFile file, String sessionId) =>
      _io.loadGraph(file.appCardChatsFolder, sessionId);

  Future<void> saveGraph(
    CharacterFile file,
    String sessionId,
    MemoryGraph graph,
  ) => _io.saveGraph(file.appCardChatsFolder, sessionId, graph);
}
