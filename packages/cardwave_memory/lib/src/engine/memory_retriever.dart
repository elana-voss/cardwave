import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/src/models/memory_field_enum.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_memory/src/models/tree_level_enum.dart';
import 'package:cardwave_memory/src/models/tree_node.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// Retrieves the events most relevant to a query from one chat's
/// [MemoryGraph], the same hybrid keyword + meaning ranking the card search
/// uses: the dense channel embeds the query and scores it against each event
/// vector; the keyword channel runs BM25 over the event fields; the two ranked
/// lists fuse by reciprocal rank. A separate boost lifts events naming a person
/// or place the query mentions, since the embedder under-weights rare proper
/// nouns. Validity filtering, the relevance cutoff, top-k, and one-hop link
/// expansion all run as named steps — an event leaves the result only because
/// a named filter removed it, never because an error was swallowed.
///
/// [embedder] is injected; this package never resolves models or reads
/// settings. The keyword index is rebuilt via [rebuildIndex] when the graph
/// loads and after each scene commits.
class MemoryRetriever {
  MemoryRetriever({required this.embedder, required this.graph});

  final Embedder embedder;
  final MemoryGraph graph;

  // All fields weigh the same in the keyword index — importance lives on the
  // event, not on which field a token sits in.
  static final Map<MemoryFieldEnum, double> _uniformFieldWeights = {
    for (final field in MemoryFieldEnum.values) field: 1.0,
  };

  // Lowest query-to-event cosine that still counts as relevant, the BGE-small
  // figure carried over from the card search. An event below this is kept only
  // if the keyword channel matched it; pure-meaning matches under it are cut.
  static const double _relevanceCutoff = 0.6;

  // Added to the fused score of an event that names a person or place the
  // query mentions. Sits comfortably above the ~0.033 ceiling a two-channel
  // reciprocal-rank score can reach, so an exact name or place hit reliably
  // surfaces — the embedder under-weights rare proper nouns, which is the whole
  // reason this boost exists. Applied after fusion; it is not a field weight.
  static const double _properNounBoost = 0.1;

  static const int _defaultTopK = 12;

  Bm25fIndex<MemoryFieldEnum>? _index;

  /// Rebuilds the keyword index from the current events. Runs on a background
  /// isolate on native and in yielding chunks on web (handled by
  /// [Bm25fIndex.buildFromSnapshots]). Call on graph load and after a scene
  /// commits new events.
  Future<void> rebuildIndex() async {
    final snapshots = _collectSnapshots();
    if (snapshots.isEmpty) {
      _index = null;
      return;
    }
    _index = await Bm25fIndex.buildFromSnapshots(
      snapshots,
      fields: MemoryFieldEnum.values,
      fieldWeights: _uniformFieldWeights,
    );
  }

  /// Returns the events most relevant to [query], best first, followed by the
  /// events one link away from them. [retrospective] keeps facts that are no
  /// longer current (superseded or past their validity window) for
  /// "remember when…" questions; by default they are filtered out.
  Future<List<StoryEvent>> retrieve(
    String query, {
    int topK = _defaultTopK,
    bool retrospective = false,
  }) async {
    final candidates = <String, StoryEvent>{};
    for (final event in graph.events) {
      if (retrospective || _isCurrent(event)) candidates[event.id] = event;
    }
    if (candidates.isEmpty) return const [];

    final queryTokens = TextTokenizer.tokenize(query);
    final queryVector = await embedder.embedOne(query, task: EmbedTaskEnum.query);

    final lexicalEntries =
        _index?.rankAll(queryTokens, candidates.keys) ?? const [];
    final lexicalIds = [for (final entry in lexicalEntries) entry.key];

    // Meaning channel: only events at or above the relevance cutoff. Events
    // below it can still ride in on a keyword match through the channel above.
    final semanticEntries = <MapEntry<String, double>>[];
    for (final event in candidates.values) {
      final vector = event.vector;
      if (vector == null) continue;
      final cosine = maxCosine(queryVector, [vector]);
      if (cosine >= _relevanceCutoff) {
        semanticEntries.add(MapEntry(event.id, cosine));
      }
    }
    final semanticIds = _keysByDescendingScore(semanticEntries);

    final rankedLists = <List<String>>[];
    if (lexicalIds.isNotEmpty) rankedLists.add(lexicalIds);
    if (semanticIds.isNotEmpty) rankedLists.add(semanticIds);
    if (rankedLists.isEmpty) return const [];

    final fused = reciprocalRankFusion(rankedLists);

    final queryTokenSet = queryTokens.toSet();
    fused.updateAll((id, score) {
      final event = candidates[id];
      if (event != null && _namesAQueryEntity(event, queryTokenSet)) {
        return score + _properNounBoost;
      }
      return score;
    });

    final topIds = _keysByDescendingScore(fused.entries, limit: topK);

    // ids in [fused] are candidate ids by construction, so these lookups hold.
    final selected = topIds.toSet();
    final result = <StoryEvent>[for (final id in topIds) candidates[id]!];
    for (final id in topIds) {
      for (final linkedId in candidates[id]!.linkedEventIds) {
        if (!selected.add(linkedId)) continue;
        // Unlike the candidate ids above, a linked id may point at an event
        // dropped by the validity filter (or a dangling link), so it is not
        // guaranteed present.
        final linked = candidates[linkedId];
        if (linked != null) result.add(linked);
      }
    }
    return result;
  }

  /// Returns the [level] nodes whose summary best matches [query], for
  /// arc-level questions ("what's the story so far"). Ranks on summary text
  /// only, so it returns the coarse summaries rather than per-turn event text.
  /// [level] is meant to be part or chapter.
  List<TreeNode> retrieveArcSummaries(
    String query, {
    required TreeLevelEnum level,
    int topK = _defaultTopK,
  }) {
    final queryTokens = TextTokenizer.tokenize(query).toSet();
    if (queryTokens.isEmpty) return const [];
    final scored = <MapEntry<TreeNode, int>>[];
    for (final node in graph.nodes) {
      if (node.level != level) continue;
      final overlap = TextTokenizer.tokenize(
        node.summary,
      ).toSet().intersection(queryTokens).length;
      if (overlap > 0) scored.add(MapEntry(node, overlap));
    }
    return _keysByDescendingScore(scored, limit: topK);
  }

  // Sorts [entries] by score, highest first, and returns their keys — all of
  // them, or the top [limit] when given. Shared by the id rankings and the
  // arc-summary ranking.
  static List<K> _keysByDescendingScore<K>(
    Iterable<MapEntry<K, num>> entries, {
    int? limit,
  }) {
    final sorted = entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = limit == null ? sorted : sorted.take(limit);
    return [for (final entry in top) entry.key];
  }

  List<TokenSnapshot<MemoryFieldEnum>> _collectSnapshots() {
    final snapshots = <TokenSnapshot<MemoryFieldEnum>>[];
    for (final event in graph.events) {
      final tokensByField = <MemoryFieldEnum, List<String>>{};
      for (final field in MemoryFieldEnum.values) {
        final tokens = <String>[];
        for (final value in _fieldValues(event, field)) {
          tokens.addAll(TextTokenizer.tokenize(value));
        }
        if (tokens.isNotEmpty) tokensByField[field] = tokens;
      }
      if (tokensByField.isEmpty) continue;
      snapshots.add(TokenSnapshot(id: event.id, tokensByField: tokensByField));
    }
    return snapshots;
  }

  static List<String> _fieldValues(StoryEvent event, MemoryFieldEnum field) {
    switch (field) {
      case MemoryFieldEnum.text:
        return [event.text];
      case MemoryFieldEnum.characters:
        return event.characters;
      case MemoryFieldEnum.locations:
        return event.locations;
      case MemoryFieldEnum.items:
        return event.items;
      case MemoryFieldEnum.concepts:
        return event.concepts;
      case MemoryFieldEnum.keywords:
        return event.keywords;
    }
  }

  static bool _namesAQueryEntity(StoryEvent event, Set<String> queryTokens) {
    for (final value in [...event.characters, ...event.locations]) {
      for (final token in TextTokenizer.tokenize(value)) {
        if (queryTokens.contains(token)) return true;
      }
    }
    return false;
  }

  // An event leaves default retrieval once a later event supersedes it
  // (supersededAt) or its validity window is marked closed (validUntil). The
  // opening side (validFrom, a fact not yet true) is deliberately not checked:
  // judging it would need a story-time clock the retriever isn't given.
  // Retrospective queries skip the whole check.
  static bool _isCurrent(StoryEvent event) =>
      event.supersededAt == null && event.validUntil == null;
}
