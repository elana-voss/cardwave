import 'package:cardwave_memory/src/engine/memory_extractor.dart';
import 'package:cardwave_memory/src/models/memory_fact.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/memory_message.dart';
import 'package:cardwave_memory/src/models/story_event.dart';

/// What [MemoryEngine.reconcile] changed: the message position to re-extract
/// from. [recomputeFromIndex] is -1 when nothing changed.
class ReconcileResult {
  const ReconcileResult({required this.recomputeFromIndex});

  final int recomputeFromIndex;
}

/// Drives extraction over a chat: turns each new window of messages into events
/// and facts exactly once and commits them straight into [graph] — no scenes,
/// no staging, no provisional hold. The app layer loads and saves the graph.
class MemoryEngine {
  MemoryEngine({
    required this.extractor,
    this.batchSize = 8,
    this.contextSize = 2,
  });

  final MemoryExtractor extractor;

  /// How many new messages to extract per call, and how many already-extracted
  /// messages to show before them as background so the model has continuity.
  /// The background messages are never re-extracted.
  final int batchSize;
  final int contextSize;

  // The graph wraps these growable lists so the engine appends in place;
  // `graph.events`/`graph.facts` and these are the same references. The app
  // layer loads and saves the graph.
  final List<StoryEvent> _events = [];
  final List<MemoryFact> _facts = [];
  late final MemoryGraph graph = MemoryGraph(events: _events, facts: _facts);

  // messageId -> content hash. Insertion order is the processing order (Dart
  // preserves it), so reconcile finds the earliest changed message by walking
  // _processedHashes.keys and re-extracts from there.
  final Map<String, String> _processedHashes = {};

  // Messages [0, _extractedThrough) have already been turned into memory.
  int _extractedThrough = 0;

  /// Seeds the engine from a [loaded] graph and the chat's [currentMessages].
  /// The per-message bookkeeping reconcile relies on — the processed-message
  /// hashes and the extracted-through mark — is not part of the saved graph, so
  /// it is rebuilt here: a message counts as already extracted exactly when a
  /// committed event or fact cites it, and extraction resumes after the last
  /// such message.
  void loadGraph(MemoryGraph loaded, List<MemoryMessage> currentMessages) {
    _events
      ..clear()
      ..addAll(loaded.events);
    _facts
      ..clear()
      ..addAll(loaded.facts);

    final extractedMessageIds = <String>{
      for (final event in _events) ...event.messageIds,
      for (final fact in _facts) ...fact.messageIds,
    };
    _processedHashes.clear();
    var extractedThrough = 0;
    for (final message in currentMessages) {
      if (!extractedMessageIds.contains(message.id)) break;
      _processedHashes[message.id] = _hashText(message.text);
      extractedThrough++;
    }
    _extractedThrough = extractedThrough;
  }

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
  /// the rest are new — and commits its events and facts straight into the
  /// graph. New facts that the model marked as overriding a known fact retire
  /// that fact in place.
  Future<void> ingestWindow(
    List<MemoryMessage> window, {
    int contextCount = 0,
  }) async {
    for (final message in window.skip(contextCount)) {
      _processedHashes[message.id] = _hashText(message.text);
    }

    final candidateFacts = _candidateFacts(window);
    final result = await extractor.extract(
      window,
      contextCount: contextCount,
      candidateFacts: candidateFacts,
    );

    _events.addAll(result.events);
    _facts.addAll(result.facts);

    final now = DateTime.now().millisecondsSinceEpoch;
    result.supersedes.forEach((supersededId, newId) {
      for (final fact in _facts) {
        if (fact.id == supersededId) {
          fact.supersededAt = now;
          fact.supersededBy = newId;
          break;
        }
      }
    });
  }

  // An existing, still-current fact is a candidate for this window when one of
  // its subject names appears in the window text — a cheap local match so the
  // model can flag which known facts the new messages make false, with no extra
  // call. Subjects are stored lower-cased, so the haystack is too.
  List<MemoryFact> _candidateFacts(List<MemoryMessage> window) {
    final haystack = [for (final message in window) message.text]
        .join('\n')
        .toLowerCase();
    return [
      for (final fact in _facts)
        if (fact.supersededAt == null &&
            fact.subjects.any(haystack.contains))
          fact,
    ];
  }

  /// Detects messages that were deleted or whose text changed since they were
  /// processed, drops every event and fact that depends on a message at or
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
    if (earliest == -1) return const ReconcileResult(recomputeFromIndex: -1);

    final affected = _processedHashes.keys.skip(earliest).toSet();

    final droppedFactIds = <String>{};
    _facts.removeWhere((fact) {
      if (!fact.messageIds.any(affected.contains)) return false;
      droppedFactIds.add(fact.id);
      return true;
    });
    _events.removeWhere((event) => event.messageIds.any(affected.contains));

    // A fact a now-dropped fact had superseded is no longer contradicted, so
    // revive it instead of leaving it hidden forever.
    for (final fact in _facts) {
      if (fact.supersededBy != null &&
          droppedFactIds.contains(fact.supersededBy)) {
        fact.supersededAt = null;
        fact.supersededBy = null;
      }
    }

    final keptHashes = {
      for (final id in _processedHashes.keys.take(earliest))
        id: _processedHashes[id]!,
    };
    _processedHashes
      ..clear()
      ..addAll(keptHashes);
    _extractedThrough = earliest;

    return ReconcileResult(recomputeFromIndex: earliest);
  }

  // Change-detection hash for reconcile. Rebuilt from the chat's messages on
  // every load ([loadGraph]) and never written to disk, so it only needs to be
  // consistent within one run — which text.hashCode is. It is deliberately not
  // persisted: hashCode isn't stable across runs or between native and web,
  // which is exactly why the hashes are recomputed on load.
  static String _hashText(String text) => text.hashCode.toRadixString(16);
}
