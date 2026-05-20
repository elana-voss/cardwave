import 'dart:async';
import 'dart:collection';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave/search/src/observability/embeddings_loggers.dart';
import 'package:cardwave/search/src/repositories/search_repository.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Top of the search pipeline. Owns the on-device embedder, per-card
/// sidecar IO via [SearchRepository], and the in-memory keyword index.
/// Listens to [CharacterService] so cards added / edited / removed
/// stay in sync without the caller having to wire a second listener.
///
/// Every search-related read flows through this service: the grid
/// controller calls [rankLexical] for instant keyword-only ranking and
/// [rank] once it can await the full keyword + meaning fusion.
class SearchService extends ChangeNotifier {
  SearchService({
    required this.repository,
    required Embedder embedder,
  }) : _embedder = embedder;

  /// Minimum best-field cosine for discovery — cards with no literal
  /// token match enter the result set only when their best-field cosine
  /// clears this bar. Calibrated against BGE-small-en-v1.5 on the
  /// example-card pool: real matches land at 0.65–0.85, baseline noise
  /// at 0.45–0.57; 0.6 leaves a small margin above the noise floor.
  static const double _semanticThreshold = 0.6;

  // Per-field BM25F boost = source weight / 10. Dividing by 10 keeps the
  // boost in the range where BM25's saturation curve doesn't crush the gap
  // between high- and low-weighted fields (scenario at weight 1 lands at
  // 0.1 — quiet but still scored).
  static final Map<CardSearchFieldEnum, double> _bm25FieldWeights = {
    for (final f in CardSearchFieldEnum.values) f: f.weight / 10,
  };

  final SearchRepository repository;
  final Embedder _embedder;

  // CharacterService and this service take each other; the loop is broken
  // by deferring the back-pointer to init() (see main.dart).
  late final CharacterService _characterService;

  // Per-card data + a parallel CharacterFile lookup so the worker can
  // resolve a queue entry's cardPath in O(1) instead of scanning every
  // loaded card.
  final Map<String, FieldSearchData<CardSearchFieldEnum>> _byPath = {};
  final Map<String, CharacterFile> _cardsByPath = {};

  // Worker removes the key on dequeue, so an edit landing mid-process
  // enqueues a fresh re-process instead of being swallowed as a duplicate.
  final Set<String> _queuedKeys = {};
  final Queue<({String cardPath, CardSearchFieldEnum field})> _queue = Queue();

  // Cards whose in-memory state has diverged from disk; the drain loop
  // flushes one sidecar write when the run of fields for a given card ends.
  final Set<String> _dirtyPaths = {};

  // Card-level progress for the chip. _cardsInBatch grows on enqueue, resets
  // when the queue fully drains. _pendingPerCard counts each card's queued
  // entries; a card is "done" when its count drops to zero.
  final Set<String> _cardsInBatch = {};
  final Map<String, int> _pendingPerCard = {};

  bool _workerRunning = false;

  // Coalesce notify storms (8000+ during cold start) to one tick per 50ms.
  bool _notifyScheduled = false;
  Timer? _notifyTimer;

  // Built off the main thread (Isolate.run on native, chunked on web);
  // null until the first build completes. Token storage marks _bm25Dirty
  // so the rebuild loop keeps running while indexing proceeds; only one
  // build is in flight at a time.
  Bm25fIndex<CardSearchFieldEnum>? _bm25Index;
  bool _bm25Building = false;
  bool _bm25Dirty = false;
  bool _bm25Disposed = false;

  // Cache the most recent query embedding so a re-rank for the same
  // query (filter change, manual sort flip) doesn't re-hit the embedder.
  String _lastEmbeddedQuery = '';
  Float32List? _lastQueryEmbedding;

  Future<void> initEmbedder() => _embedder.init();

  bool get isEmbedderReady => _embedder.isReady;

  ({int done, int total}) get progress {
    final total = _cardsInBatch.length;
    final pending = _pendingPerCard.length;
    return (done: total - pending, total: total);
  }

  /// Cached search data for [cardImagePath], or null when the card
  /// hasn't been ingested yet.
  FieldSearchData<CardSearchFieldEnum>? embeddingsFor(String cardImagePath) =>
      _byPath[cardImagePath];

  /// Wires the back-pointer to `CharacterService` and starts discovery.
  /// Idempotent.
  void init(CharacterService service) {
    _characterService = service;
    _characterService.addListener(_onCharacterServiceChanged);
    unawaited(_scanAndDrain());
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _bm25Disposed = true;
    _characterService.removeListener(_onCharacterServiceChanged);
    super.dispose();
  }

  /// Called by `CharacterService` after a successful PNG write. Queues
  /// only the fields whose hash changed.
  Future<void> queueReindex(CharacterFile card) async {
    // Claim the slot in case the user saves before discovery has reached
    // this card; _ingestCard's later merge keeps any sidecar data we read.
    final existing = _byPath.putIfAbsent(
      card.appCardImagePath,
      FieldSearchData<CardSearchFieldEnum>.empty,
    );
    _cardsByPath[card.appCardImagePath] = card;

    final liveHashes = _computeAllHashes(card);
    for (final field in CardSearchFieldEnum.values) {
      if (liveHashes[field] != existing.hashes[field]) {
        _enqueue(card.appCardImagePath, field);
      }
    }
    await _drainQueue();
  }

  /// Synchronous keyword-only ranking. Returns RRF scores from the
  /// lexical channel alone. Caller uses this on the keystroke path so
  /// the grid updates immediately while the meaning embedding is still
  /// in flight.
  Map<String, double> rankLexical(
    String query,
    Iterable<String> candidateIds,
  ) {
    final candidates = candidateIds.toList();
    final tokens = TextTokenizer.tokenize(query);
    final lexical = _bm25Index?.rankAll(tokens, candidates) ?? const [];
    final ids = lexical.map((e) => e.key).toList();
    final scores = ids.isEmpty
        ? <String, double>{}
        : reciprocalRankFusion([ids]);
    return _applyExactNameOverride(query, candidates, scores);
  }

  /// Full keyword + meaning ranking. Embeds the query (cached across
  /// repeats), runs the lexical channel, fuses both lists via RRF.
  /// Falls back to lexical-only when the embedder isn't ready or its
  /// call throws.
  Future<Map<String, double>> rank(
    String query,
    Iterable<String> candidateIds,
  ) async {
    final candidates = candidateIds.toList();
    final tokens = TextTokenizer.tokenize(query);
    final lexicalEntries = _bm25Index?.rankAll(tokens, candidates) ?? const [];
    final lexicalIds = lexicalEntries.map((e) => e.key).toList();
    final lexicalSet = lexicalIds.toSet();

    final queryEmbedding = await _resolveQueryEmbedding(query);

    final rankedLists = <List<String>>[];
    if (lexicalIds.isNotEmpty) rankedLists.add(lexicalIds);

    // Semantic admits cards via two paths: lexical-set membership (BM25
    // already found a literal token match) OR best-field cosine clearing
    // the discovery threshold. Cards with partial data (still mid-ingest)
    // are skipped so noisy half-vectors don't sneak in.
    if (queryEmbedding != null) {
      final semanticScores = <String, double>{};
      for (final id in candidates) {
        final data = _byPath[id];
        if (data == null) continue;
        if (data.hashes.length < CardSearchFieldEnum.values.length) continue;
        var bestCosine = 0.0;
        var orderingScore = 0.0;
        for (final field in CardSearchFieldEnum.values) {
          final chunks = data.byField[field] ?? const <Float32List>[];
          if (chunks.isEmpty) continue;
          final cos = maxCosine(queryEmbedding, chunks);
          if (cos > bestCosine) bestCosine = cos;
          orderingScore +=
              (field.weight / CardSearchFieldEnum.totalWeight) * cos;
        }
        if (lexicalSet.contains(id) || bestCosine >= _semanticThreshold) {
          semanticScores[id] = orderingScore;
        }
      }
      if (semanticScores.isNotEmpty) {
        final semanticIds = semanticScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        rankedLists.add(semanticIds.map((e) => e.key).toList());
      }
    }

    final fused = rankedLists.isEmpty
        ? <String, double>{}
        : reciprocalRankFusion(rankedLists);
    return _applyExactNameOverride(query, candidates, fused);
  }

  /// Boosts an exact-name match to the top of the fused score map. Fires
  /// only when exactly one candidate's card name equals the trimmed query
  /// case-insensitively — multi-match (variants) and zero-match cases are
  /// no-ops. The override inserts even when the card wasn't otherwise
  /// scored, so the display-time gate still keeps it visible.
  Map<String, double> _applyExactNameOverride(
    String query,
    Iterable<String> candidates,
    Map<String, double> scores,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return scores;
    String? singleMatch;
    var matchCount = 0;
    for (final id in candidates) {
      final card = _cardsByPath[id];
      if (card == null) continue;
      if (card.card.name.trim().toLowerCase() != normalized) continue;
      singleMatch = id;
      matchCount++;
      if (matchCount > 1) return scores;
    }
    if (matchCount != 1 || singleMatch == null) return scores;
    var maxScore = 0.0;
    for (final v in scores.values) {
      if (v > maxScore) maxScore = v;
    }
    final result = Map<String, double>.of(scores);
    result[singleMatch] = maxScore + 1.0;
    return result;
  }

  Future<Float32List?> _resolveQueryEmbedding(String query) async {
    if (query == _lastEmbeddedQuery && _lastQueryEmbedding != null) {
      return _lastQueryEmbedding;
    }
    if (!_embedder.isReady) return null;
    try {
      final fresh = await _embedder.embedOne(
        query,
        task: EmbedTaskEnum.query,
      );
      _lastQueryEmbedding = fresh;
      _lastEmbeddedQuery = query;
      return fresh;
    } on EmbeddingsException {
      return null;
    }
  }

  void _onCharacterServiceChanged() {
    unawaited(_scanAndDrain());
  }

  Future<void> _scanAndDrain() async {
    await _scanForChanges();
    await _drainQueue();
  }

  Future<void> _scanForChanges() async {
    final cards = _characterService.characterFiles;
    final livePaths = {for (final c in cards) c.appCardImagePath};

    final dropped = _byPath.keys.toSet().difference(livePaths);
    if (dropped.isNotEmpty) {
      for (final path in dropped) {
        _byPath.remove(path);
        _cardsByPath.remove(path);
        _cardsInBatch.remove(path);
        _pendingPerCard.remove(path);
        _dirtyPaths.remove(path);
        for (final field in CardSearchFieldEnum.values) {
          _queuedKeys.remove(_queueKey(path, field));
        }
      }
      _queue.removeWhere((entry) => dropped.contains(entry.cardPath));
      _scheduleBm25Rebuild();
    }

    for (final card in cards) {
      // Claim the slot synchronously before any await so concurrent
      // _scanForChanges invocations don't double-ingest the same card.
      if (_byPath.containsKey(card.appCardImagePath)) continue;
      _byPath[card.appCardImagePath] = FieldSearchData<CardSearchFieldEnum>.empty();
      _cardsByPath[card.appCardImagePath] = card;
      await _ingestCard(card);
    }
  }

  Future<void> _ingestCard(CharacterFile card) async {
    final loaded = await repository.read(_sidecarPathFor(card));
    final existing = _byPath[card.appCardImagePath]!;
    if (loaded != null) {
      // Merge instead of overwrite — queueReindex could have populated
      // some fields during the sidecar await; keep its work.
      var mergedTokens = false;
      for (final field in CardSearchFieldEnum.values) {
        if (existing.hashes.containsKey(field)) continue;
        final loadedHash = loaded.hashes[field];
        final loadedChunks = loaded.byField[field];
        final loadedTokens = loaded.tokens[field];
        if (loadedHash != null) existing.hashes[field] = loadedHash;
        if (loadedChunks != null) existing.byField[field] = loadedChunks;
        if (loadedTokens != null) {
          existing.tokens[field] = loadedTokens;
          mergedTokens = true;
        }
      }
      if (mergedTokens) _scheduleBm25Rebuild();
    }
    final liveHashes = _computeAllHashes(card);
    for (final field in CardSearchFieldEnum.values) {
      if (existing.hashes[field] != liveHashes[field]) {
        _enqueue(card.appCardImagePath, field);
      }
    }
  }

  void _enqueue(String cardPath, CardSearchFieldEnum field) {
    if (!_queuedKeys.add(_queueKey(cardPath, field))) return;
    _queue.add((cardPath: cardPath, field: field));
    _cardsInBatch.add(cardPath);
    _pendingPerCard[cardPath] = (_pendingPerCard[cardPath] ?? 0) + 1;
    _scheduleNotify();
  }

  Future<void> _drainQueue() async {
    if (_workerRunning) return;
    if (_queue.isEmpty) return;
    _workerRunning = true;
    _scheduleNotify();
    searchLogger.info(
      EmbeddingsDiagnosticEvent(
        level: EmbeddingsDiagnosticLevel.info,
        message: '[Search] Indexer starting: ${_cardsInBatch.length} cards.',
      ),
    );
    final cardTimer = Stopwatch();
    String? activeCardPath;
    try {
      while (_queue.isNotEmpty) {
        final entry = _queue.removeFirst();
        if (entry.cardPath != activeCardPath) {
          activeCardPath = entry.cardPath;
          cardTimer
            ..reset()
            ..start();
        }
        _queuedKeys.remove(_queueKey(entry.cardPath, entry.field));
        final changed = await _processOneField(entry);
        if (changed) _dirtyPaths.add(entry.cardPath);

        // Decrement pending count; remove when this card has no more queued.
        final remaining = (_pendingPerCard[entry.cardPath] ?? 1) - 1;
        if (remaining > 0) {
          _pendingPerCard[entry.cardPath] = remaining;
        } else {
          _pendingPerCard.remove(entry.cardPath);
        }

        // Flush one write per card when the contiguous run of that card's
        // fields ends (interleaved enqueues are written separately).
        final isLastForThisCard =
            _queue.isEmpty || _queue.first.cardPath != entry.cardPath;
        if (isLastForThisCard) {
          if (_dirtyPaths.remove(entry.cardPath)) {
            await _writeSidecarForPath(entry.cardPath);
            _scheduleBm25Rebuild();
          }
          cardTimer.stop();
          final prog = progress;
          searchLogger.info(
            EmbeddingsDiagnosticEvent(
              level: EmbeddingsDiagnosticLevel.info,
              message:
                  '[Search] Indexed ${entry.cardPath} '
                  '(${prog.done}/${prog.total}) in ${cardTimer.elapsedMilliseconds}ms',
            ),
          );
          activeCardPath = null;
        }

        _scheduleNotify();
      }
      // Batch complete — reset card tracking so the next session of work
      // starts at 0 / N instead of accumulating across edits.
      _cardsInBatch.clear();
      searchLogger.info(
        const EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.info,
          message: '[Search] Indexer idle.',
        ),
      );
    } finally {
      _workerRunning = false;
      _scheduleNotify();
    }
  }

  /// Returns true when the in-memory data for [entry] actually changed
  /// (caller marks the card dirty for the next sidecar write). Tokens
  /// and embeddings land together — both are derived from the same
  /// source text and live as one unit per field.
  Future<bool> _processOneField(
    ({String cardPath, CardSearchFieldEnum field}) entry,
  ) async {
    final card = _cardsByPath[entry.cardPath];
    if (card == null) return false;

    final text = _textOf(card.card, entry.field);
    final newHash = UtilsHash.fnv1a64Hex(text);

    final stored = _byPath[entry.cardPath]!;
    if (stored.hashes[entry.field] == newHash) return false;

    final tokens = TextTokenizer.tokenize(text);

    final chunks = await _embedder.chunkByTokens(text);

    List<Float32List> vectors;
    if (chunks.isEmpty) {
      vectors = const [];
    } else {
      try {
        vectors = await _embedder.embed(
          chunks,
          task: EmbedTaskEnum.passage,
        );
      } on EmbeddingsException catch (e, st) {
        searchLogger.warning(
          EmbeddingsDiagnosticEvent(
            level: EmbeddingsDiagnosticLevel.warning,
            message:
                '[Search] Embed failed for ${entry.field.name} on ${entry.cardPath}: $e',
            error: e,
            stackTrace: st,
          ),
        );
        return false;
      }
    }

    stored.byField[entry.field] = vectors;
    stored.tokens[entry.field] = tokens;
    stored.hashes[entry.field] = newHash;
    return true;
  }

  Future<void> _writeSidecarForPath(String cardPath) async {
    final data = _byPath[cardPath];
    final card = _cardsByPath[cardPath];
    if (data == null || card == null) return;
    await repository.write(_sidecarPathFor(card), data);
  }

  /// Marks the keyword index dirty. If a build is already running, lets
  /// it finish — the loop re-checks the dirty flag and starts another
  /// build if needed. This way one build is in flight at a time, but
  /// the index never falls more than one build behind the latest data.
  /// Builds run in an isolate (native) or in yielding chunks (web), so
  /// the main thread stays interactive during cold-start indexing.
  void _scheduleBm25Rebuild() {
    _bm25Dirty = true;
    if (_bm25Building) return;
    unawaited(_runBm25RebuildLoop());
  }

  Future<void> _runBm25RebuildLoop() async {
    _bm25Building = true;
    try {
      while (_bm25Dirty && !_bm25Disposed) {
        _bm25Dirty = false;
        final snapshots = _collectBm25Snapshots();
        if (snapshots.isEmpty) continue;
        final Bm25fIndex<CardSearchFieldEnum> fresh;
        try {
          fresh = await Bm25fIndex.buildFromSnapshots(
            snapshots,
            fields: CardSearchFieldEnum.values,
            fieldWeights: _bm25FieldWeights,
          );
        } on Object catch (e, st) {
          searchLogger.severe(
            EmbeddingsDiagnosticEvent(
              level: EmbeddingsDiagnosticLevel.error,
              message: '[Search] Index build failed: $e',
              error: e,
              stackTrace: st,
            ),
          );
          continue;
        }
        if (_bm25Disposed) return;
        _bm25Index = fresh;
        _scheduleNotify();
      }
    } finally {
      _bm25Building = false;
    }
  }

  List<TokenSnapshot<CardSearchFieldEnum>> _collectBm25Snapshots() {
    final snapshots = <TokenSnapshot<CardSearchFieldEnum>>[];
    for (final entry in _byPath.entries) {
      final tokensByField = <CardSearchFieldEnum, List<String>>{};
      for (final field in CardSearchFieldEnum.values) {
        final tokens = entry.value.tokens[field];
        if (tokens != null && tokens.isNotEmpty) {
          tokensByField[field] = tokens;
        }
      }
      if (tokensByField.isEmpty) continue;
      snapshots.add(
        TokenSnapshot<CardSearchFieldEnum>(
          id: entry.key,
          tokensByField: tokensByField,
        ),
      );
    }
    return snapshots;
  }

  String _queueKey(String cardPath, CardSearchFieldEnum field) =>
      '$cardPath|${field.name}';

  String _sidecarPathFor(CharacterFile card) => p.posix.join(
    card.appCardCharacterFolder,
    AppConstants.embeddingsSidecarFilename,
  );

  String _textOf(CharacterCardV3 card, CardSearchFieldEnum field) {
    switch (field) {
      case CardSearchFieldEnum.name:
        return card.name;
      case CardSearchFieldEnum.tags:
        return card.tags.join(', ');
      case CardSearchFieldEnum.personality:
        return card.personality;
      case CardSearchFieldEnum.description:
        return card.description;
      case CardSearchFieldEnum.scenario:
        return card.scenario;
    }
  }

  Map<CardSearchFieldEnum, String> _computeAllHashes(CharacterFile card) => {
    for (final field in CardSearchFieldEnum.values)
      field: UtilsHash.fnv1a64Hex(_textOf(card.card, field)),
  };

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      _notifyScheduled = false;
      _notifyTimer = null;
      notifyListeners();
    });
  }
}
