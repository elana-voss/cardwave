import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_memory/src/models/memory_fact.dart';
import 'package:cardwave_memory/src/models/memory_field_enum.dart';
import 'package:cardwave_memory/src/models/memory_graph.dart';
import 'package:cardwave_memory/src/models/story_event.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';

/// Retrieves the most relevant memory from one chat's [MemoryGraph], on two
/// channels:
///
/// - [retrieve] ranks the EVENTS ("what happened") with the same hybrid
///   keyword + meaning ranking the card search uses: the dense channel embeds
///   the query and scores it against each event vector; the keyword channel
///   runs BM25 over the event fields; the two ranked lists fuse by reciprocal
///   rank, then a boost lifts events naming a person or place the query
///   mentions (the embedder under-weights rare proper nouns).
/// - [retrieveFacts] looks up the FACTS ("what's true now") by entity name
///   only — facts carry no vector, so recall is a direct scan of the facts the
///   query (or the active character) names.
///
/// [embedder] is injected; this package never resolves models or reads
/// settings. The keyword index covers events only and is rebuilt via
/// [rebuildIndex] when the graph loads and after extraction commits.
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
  static const int _defaultFactTopK = 8;

  Bm25fIndex<MemoryFieldEnum>? _index;

  /// Rebuilds the keyword index from the current events. Runs on a background
  /// isolate on native and in yielding chunks on web (handled by
  /// [Bm25fIndex.buildFromSnapshots]). Call on graph load and after extraction
  /// commits new events. Facts have no index — [retrieveFacts] scans them.
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

  /// Returns the events most relevant to [query], best first. Events are
  /// append-only "what happened" records, so every event is a candidate — there
  /// is no validity filter here (current state lives on facts).
  Future<List<StoryEvent>> retrieve(String query, {int topK = _defaultTopK}) async {
    if (graph.events.isEmpty) return const [];
    final candidates = {for (final event in graph.events) event.id: event};

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
      if (event != null &&
          _anyNameToken(
            [...event.characters, ...event.locations],
            queryTokenSet,
          )) {
        return score + _properNounBoost;
      }
      return score;
    });

    final topIds = _keysByDescendingScore(fused.entries, limit: topK);
    return [for (final id in topIds) candidates[id]!];
  }

  /// Returns the current (non-superseded) facts about any entity the [query]
  /// names or that the chat is actively about ([activeSubjects], e.g. the
  /// character's name), newest first, capped at [topK]. Facts aren't embedded —
  /// recall is by entity name, a direct scan of [MemoryGraph.facts]. A fact the
  /// query never names and that isn't an active subject does not surface.
  List<MemoryFact> retrieveFacts(
    String query, {
    List<String> activeSubjects = const [],
    int topK = _defaultFactTopK,
  }) {
    final wanted = <String>{
      ...TextTokenizer.tokenize(query),
      for (final subject in activeSubjects) ...TextTokenizer.tokenize(subject),
    };
    if (wanted.isEmpty) return const [];

    final matched = <MemoryFact>[];
    // Facts append in extraction order, so the tail is newest.
    for (final fact in graph.facts.reversed) {
      if (fact.supersededAt != null) continue;
      if (_anyNameToken(fact.subjects, wanted)) matched.add(fact);
      if (matched.length >= topK) break;
    }
    return matched;
  }

  // Sorts [entries] by score, highest first, and returns their keys — all of
  // them, or the top [limit] when given.
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

  // True when any of [names], tokenized, hits a token in [wanted]. Shared by
  // the event proper-noun boost and the fact entity lookup so the two matchers
  // can't drift apart.
  static bool _anyNameToken(Iterable<String> names, Set<String> wanted) {
    for (final name in names) {
      for (final token in TextTokenizer.tokenize(name)) {
        if (wanted.contains(token)) return true;
      }
    }
    return false;
  }
}
