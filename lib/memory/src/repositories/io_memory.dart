import 'dart:convert';
import 'dart:typed_data';

import 'package:cardwave/common/common.dart';
import 'package:cardwave_memory/cardwave_memory.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:path/path.dart' as p;

/// Reads and writes one chat's story-memory graph. The JSON file holds the
/// events and tree; the event vectors travel in a binary sidecar next to it,
/// the same split the card search uses. Layout mirrors the chat session:
/// `<chatDir>/<sessionId>/memory/graph.json` + `graph.vectors.bin`.
class IoMemory {
  const IoMemory({required this.loggingService, required this.appStorage});

  final LoggingService loggingService;
  final AppStorage appStorage;

  static const String _memoryFolder = 'memory';
  static const String _graphFile = 'graph.json';
  static const String _vectorsFile = 'graph.vectors.bin';

  /// Loads the graph for [sessionId] under [chatDirectoryPath], or an empty
  /// graph when none is saved. A graph file that fails to parse is treated as
  /// a stale cache (the whole memory graph is rebuildable from the chat): the
  /// failure is logged and an empty graph returned so extraction starts over.
  Future<MemoryGraph> loadGraph(
    String chatDirectoryPath,
    String sessionId,
  ) async {
    final graphPath = _graphPath(chatDirectoryPath, sessionId);
    if (!await appStorage.fileExists(StorageDomainEnum.cards, graphPath)) {
      return const MemoryGraph();
    }
    final MemoryGraph graph;
    try {
      final content = await appStorage.readString(
        StorageDomainEnum.cards,
        graphPath,
      );
      graph = MemoryGraph.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } on Exception catch (error, stackTrace) {
      loggingService.warning(
        'Memory graph at $graphPath unreadable; rebuilding from the chat.',
        error,
        stackTrace,
      );
      return const MemoryGraph();
    }

    final vectorsPath = _vectorsPath(chatDirectoryPath, sessionId);
    if (await appStorage.fileExists(StorageDomainEnum.cards, vectorsPath)) {
      final bytes = await appStorage.readBytes(
        StorageDomainEnum.cards,
        vectorsPath,
      );
      graph.restoreVectors(Uint8List.fromList(bytes));
    }

    // Every event needs its vector — to be retrievable and to re-encode on the
    // next save. A missing or stale sidecar leaves some null, so the graph is
    // unusable: treat it as a disposable cache and rebuild from the chat.
    if (graph.events.any((event) => event.vector == null)) {
      loggingService.warning(
        'Memory vectors at $vectorsPath missing or stale; rebuilding from the '
        'chat.',
      );
      return const MemoryGraph();
    }
    return graph;
  }

  /// Writes the graph JSON and its vector sidecar. Call only once every event
  /// in [graph] is embedded — `encodeVectors` requires it.
  Future<void> saveGraph(
    String chatDirectoryPath,
    String sessionId,
    MemoryGraph graph,
  ) async {
    final graphPath = _graphPath(chatDirectoryPath, sessionId);
    await appStorage.writeString(
      StorageDomainEnum.cards,
      graphPath,
      jsonEncode(graph.toJson()),
    );
    await appStorage.writeBytes(
      StorageDomainEnum.cards,
      _vectorsPath(chatDirectoryPath, sessionId),
      graph.encodeVectors(),
    );
  }

  String _graphPath(String chatDirectoryPath, String sessionId) =>
      p.posix.join(chatDirectoryPath, sessionId, _memoryFolder, _graphFile);

  String _vectorsPath(String chatDirectoryPath, String sessionId) =>
      p.posix.join(chatDirectoryPath, sessionId, _memoryFolder, _vectorsFile);
}
