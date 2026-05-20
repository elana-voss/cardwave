import 'package:cardwave_memory/src/engine/memory_extractor.dart';
import 'package:cardwave_memory/src/engine/scene_verdict.dart';
import 'package:cardwave_memory/src/engine/staging_buffer.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/memory_message.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/models/tree_level_enum.dart';
import 'package:cardwave_memory/src/models/tree_node.dart';
import 'package:cardwave_memory/src/utils/memory_id.dart';

/// What [MemoryEngine.reconcile] changed: the committed nodes it dropped as
/// stale and the message position to re-extract from. [recomputeFromIndex] is
/// -1 when nothing changed.
class ReconcileResult {
  const ReconcileResult({
    required this.dirtyNodeIds,
    required this.recomputeFromIndex,
  });

  final List<String> dirtyNodeIds;
  final int recomputeFromIndex;
}

/// Drives extraction over a chat: turns each message into events exactly once,
/// holds provisional events in a [StagingBuffer], and commits a scene into
/// [graph] when the extractor reports a boundary. Chapter/part grouping lives
/// in `ChapterGrouper`; persistence is Phase 5.
class MemoryEngine {
  MemoryEngine({required this.extractor, this.batchSize = 8, this.contextSize = 2});

  final MemoryExtractor extractor;

  /// How many new messages to extract per call, and how many already-extracted
  /// messages to show before them as background so a scene spanning the seam is
  /// understood. The background messages are never re-extracted.
  final int batchSize;
  final int contextSize;

  // The graph wraps these growable lists so the engine appends events and
  // nodes in place; `graph.events` and these are the same references. Phase 5
  // loads/saves the graph.
  final List<StoryEvent> _events = [];
  final List<TreeNode> _nodes = [];
  final List<String> _roots = [];
  late final MemoryGraph graph = MemoryGraph(
    events: _events,
    nodes: _nodes,
    roots: _roots,
  );
  final StagingBuffer staging = StagingBuffer();

  // messageId -> content hash. Insertion order is the processing order (Dart
  // preserves it), so reconcile finds the earliest changed message by walking
  // _processedHashes.keys and recomputes the tree from there.
  final Map<String, String> _processedHashes = {};

  // Messages [0, _extractedThrough) have already been turned into events.
  int _extractedThrough = 0;

  /// Walks [messages] from where extraction left off, taking [batchSize] new
  /// messages at a time and showing the preceding [contextSize] as background,
  /// extracting and committing as it goes. Each message is extracted once.
  Future<void> processMessages(List<MemoryMessage> messages) async {
    while (_extractedThrough < messages.length) {
      final newStart = _extractedThrough;
      final contextStart = newStart > contextSize ? newStart - contextSize : 0;
      final end = newStart + batchSize < messages.length
          ? newStart + batchSize
          : messages.length;
      await ingestWindow(
        messages.sublist(contextStart, end),
        contextCount: newStart - contextStart,
      );
      _extractedThrough = end;
    }
  }

  /// Extracts one window — the first [contextCount] messages are background,
  /// the rest are new — stages the resulting events as provisional, and commits
  /// a scene when the extractor reports an end-cut.
  Future<void> ingestWindow(
    List<MemoryMessage> window, {
    int contextCount = 0,
  }) async {
    for (final message in window.skip(contextCount)) {
      _processedHashes[message.id] = _hashText(message.text);
    }

    final result = await extractor.extract(window, contextCount: contextCount);
    for (final event in result.events) {
      staging.add(event);
    }

    final verdict = result.verdict;
    if (verdict is SceneEndsAt) _commitScene(verdict);
  }

  void _commitScene(SceneEndsAt verdict) {
    final sceneEvents = staging.drainThrough(verdict.messageId);
    if (sceneEvents.isEmpty) return;
    final messageIds = <String>[];
    for (final event in sceneEvents) {
      messageIds.addAll(event.messageIds);
    }
    graph.events.addAll(sceneEvents);
    graph.nodes.add(
      TreeNode(
        id: newSceneId(),
        level: TreeLevelEnum.scene,
        messageIds: messageIds,
        summary: verdict.summary,
        eventIds: [for (final event in sceneEvents) event.id],
      ),
    );
  }

  /// Detects messages that were deleted or whose text changed since they were
  /// processed, drops every committed node that depends on a message at or
  /// after the earliest change, and rewinds extraction so the next pass
  /// re-extracts from there.
  ReconcileResult reconcile(List<MemoryMessage> current) {
    final currentById = {for (final message in current) message.id: message};

    var earliest = -1;
    var position = 0;
    for (final id in _processedHashes.keys) {
      final message = currentById[id];
      if (message == null || _hashText(message.text) != _processedHashes[id]) {
        earliest = position;
        break;
      }
      position++;
    }
    if (earliest == -1) {
      return const ReconcileResult(dirtyNodeIds: [], recomputeFromIndex: -1);
    }

    final affected = _processedHashes.keys.skip(earliest).toSet();
    final dirtyNodeIds = <String>[];
    final dirtyEventIds = <String>{};
    final survivingNodes = <TreeNode>[];
    for (final node in graph.nodes) {
      if (node.messageIds.any(affected.contains)) {
        dirtyNodeIds.add(node.id);
        dirtyEventIds.addAll(node.eventIds);
      } else {
        survivingNodes.add(node);
      }
    }

    graph.events.removeWhere((event) => dirtyEventIds.contains(event.id));
    graph.nodes
      ..clear()
      ..addAll(survivingNodes);

    final keptHashes = {
      for (final id in _processedHashes.keys.take(earliest))
        id: _processedHashes[id]!,
    };
    _processedHashes
      ..clear()
      ..addAll(keptHashes);
    staging.clear();
    _extractedThrough = earliest;

    return ReconcileResult(
      dirtyNodeIds: dirtyNodeIds,
      recomputeFromIndex: earliest,
    );
  }

  // Change-detection hash for reconcile. Fine while the graph lives only in
  // memory: within a single run text.hashCode is consistent. It is NOT safe to
  // persist — Dart does not guarantee hashCode is the same across runs, and the
  // native and web builds use different algorithms, so a hash written to disk
  // can't be relied on to match on reload. Before Phase 5 persists hashes,
  // switch to a defined, cross-platform-stable hash.
  static String _hashText(String text) => text.hashCode.toRadixString(16);
}
