import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave/search/src/observability/embeddings_loggers.dart';
import 'package:cardwave/search/src/repositories/search_repository.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
import 'package:cardwave_retrieval/cardwave_retrieval.dart';
import 'package:flutter/foundation.dart';

/// Top of the search pipeline. Owns the on-device embedder and persists all
/// search data — embedding vectors, keyword (FTS) index, change hashes — to
/// the [SearchRepository]'s database, so memory stays flat regardless of
/// library size. Listens to [CharacterService] so cards added / edited /
/// removed stay in sync.
///
/// Every search-related read flows through this service: the grid controller
/// calls [rankLexical] for fast keyword-only ranking and [rank] for the full
/// keyword + meaning fusion.
class SearchService extends ChangeNotifier {
  SearchService({
    required this.repository,
    required Embedder embedder,
  }) : _embedder = embedder;

  /// Minimum best-field cosine for discovery — cards with no literal token
  /// match enter the result set only when their best-field cosine clears
  /// this bar. Calibrated against BGE-small-en-v1.5 on the example-card
  /// pool: real matches land at 0.65–0.85, baseline noise at 0.45–0.57.
  static const double _semanticThreshold = 0.6;

  /// How many cards' vectors a single semantic pass reads from the database
  /// at once. Bounds per-query memory: a vibe query over a 500K library
  /// streams the pool in chunks instead of loading every vector into RAM.
  static const int _semanticBatchSize = 1000;

  /// Above this many fully-indexed candidates, a meaning query stops scanning
  /// every candidate's vectors and switches to the approximate-nearest fast
  /// path (Windows only, when the add-on is present). Below it the full scan is
  /// already cheap. A starting guess — tune against a real large library.
  static const int _annCandidateThreshold = 2000;

  /// How many nearest chunk vectors the approximate search over-fetches before
  /// mapping back to cards and reranking exactly. Bigger = more recall, more
  /// work. A starting guess — tune against a real large library.
  static const int _annNearestChunks = 4000;

  final SearchRepository repository;
  final Embedder _embedder;

  // CharacterService and this service take each other; the loop is broken
  // by deferring the back-pointer to init() (see main.dart). Not owned here —
  // main.dart constructs and disposes it, so dispose() must leave it alone.
  // ignore: qcheck/dispose_class_fields
  late final CharacterService _characterService;

  // Field texts for cards queued via an in-app edit (save / create / clone /
  // import), so the drain skips re-reading them. Cards queued by a library
  // scan carry no entry here and are loaded on demand during the drain. One
  // small entry per queued-by-edit card, removed as each is drained.
  final Map<String, Map<CardSearchFieldEnum, String>> _pendingText = {};

  // Per-field change-detection hashes, mirrored from the database at startup
  // and kept current as fields are indexed. Tiny next to the vectors (which
  // live only in the database) and backs both change detection and the
  // sync [fieldHashesFor] readiness check.
  final Map<String, Map<CardSearchFieldEnum, String>> _hashes = {};

  // Worker removes the key on dequeue, so an edit landing mid-process
  // enqueues a fresh re-process instead of being swallowed as a duplicate.
  final Set<String> _queuedKeys = {};
  final Queue<({String cardPath, CardSearchFieldEnum field})> _queue = Queue();

  // Cards whose fields changed since their last keyword-row flush; the drain
  // loop rewrites one FTS row when the run of fields for a card ends.
  final Set<String> _dirtyPaths = {};

  // Card-level progress for the chip. _cardsInBatch grows on enqueue, resets
  // when the queue fully drains. _pendingPerCard counts each card's queued
  // entries; a card is "done" when its count drops to zero.
  final Set<String> _cardsInBatch = {};
  final Map<String, int> _pendingPerCard = {};

  bool _workerRunning = false;

  // Coalesce notify storms (thousands during cold start) to one tick per 50ms.
  bool _notifyScheduled = false;
  Timer? _notifyTimer;
  bool _disposed = false;

  // Cache the most recent query embedding so a re-rank for the same query
  // (filter change, manual sort flip) doesn't re-hit the embedder.
  String _lastEmbeddedQuery = '';
  Float32List? _lastQueryEmbedding;

  // Completes once the saved change-hashes are read from the database. The
  // indexer awaits this before its first scan so it never re-embeds cards
  // that are already indexed.
  Future<void>? _hashesLoaded;

  Future<void> initEmbedder() => _embedder.init();

  bool get isEmbedderReady => _embedder.isReady;

  ({int done, int total}) get progress {
    final total = _cardsInBatch.length;
    final pending = _pendingPerCard.length;
    return (done: total - pending, total: total);
  }

  /// Per-field change hashes for [cardImagePath], or null when the card hasn't
  /// been ingested yet. A card is fully indexed once this holds an entry for
  /// every [CardSearchFieldEnum]; the vectors themselves live in the database
  /// and are read on demand during ranking.
  Map<CardSearchFieldEnum, String>? fieldHashesFor(String cardImagePath) {
    final hashes = _hashes[cardImagePath];
    if (hashes == null) return null;
    return Map.of(hashes);
  }

  /// Wires the back-pointer to `CharacterService` and loads change hashes from
  /// the database. Re-indexing is driven afterward by [applyLibraryDiff] (the
  /// library scan) and [queueReindex] (in-app edits). Idempotent.
  void init(CharacterService service) {
    _characterService = service;
    _hashesLoaded = _loadHashes();
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    unawaited(repository.close());
    super.dispose();
  }

  /// Called by `CharacterService` after an in-app edit (save / create / clone /
  /// import). Carries the card's field texts so the drain skips re-reading it;
  /// only fields whose hash changed are queued.
  Future<void> queueReindex(CharacterFile card) async {
    final path = card.appCardImagePath;
    final texts = {
      for (final field in CardSearchFieldEnum.values)
        field: _textOf(card.card, field),
    };
    final existing = _hashes[path] ?? const <CardSearchFieldEnum, String>{};
    var queued = false;
    for (final field in CardSearchFieldEnum.values) {
      if (UtilsHash.fnv1a64Hex(texts[field]!) != existing[field]) {
        _enqueue(path, field);
        queued = true;
      }
    }
    if (queued) {
      _pendingText[path] = texts;
      await _drainQueue();
    }
  }

  /// Applies a library scan's result: drops removed cards from the index and
  /// queues every changed card for re-indexing. Changed cards are loaded on
  /// demand during the drain, so this stays flat in memory at any library size.
  void applyLibraryDiff({
    required List<String> changed,
    required List<String> removed,
  }) {
    unawaited(_applyLibraryDiff(changed, removed));
  }

  Future<void> _applyLibraryDiff(
    List<String> changed,
    List<String> removed,
  ) async {
    // Wait for the saved hashes so already-indexed fields are skipped instead
    // of re-embedded.
    await _hashesLoaded;
    for (final path in removed) {
      await _removeFromIndex(path);
    }
    final changedSet = changed.toSet();
    for (final path in changed) {
      for (final field in CardSearchFieldEnum.values) {
        _enqueue(path, field);
      }
    }

    // Reconcile against the whole library. A previous run may have been closed
    // mid-index, leaving cards that are on disk (and in the light index) but
    // never finished embedding — the light scan now sees them as unchanged and
    // queues nothing, so the search index would stay permanently incomplete.
    // Queue every card that isn't fully indexed yet; fields already embedded
    // are skipped by their hash, so re-queuing a half-done card is cheap.
    final fieldCount = CardSearchFieldEnum.values.length;
    for (final path in await _characterService.allCardPaths()) {
      if (changedSet.contains(path)) continue;
      if ((_hashes[path]?.length ?? 0) < fieldCount) {
        for (final field in CardSearchFieldEnum.values) {
          _enqueue(path, field);
        }
      }
    }

    await _drainQueue();
  }

  /// Drops one card from the index (vectors, keyword row, hashes) after a
  /// delete. Safe for a card that was never indexed.
  void removeFromIndex(String cardPath) {
    unawaited(_removeFromIndex(cardPath));
  }

  Future<void> _removeFromIndex(String path) async {
    _hashes.remove(path);
    _pendingText.remove(path);
    _cardsInBatch.remove(path);
    _pendingPerCard.remove(path);
    _dirtyPaths.remove(path);
    for (final field in CardSearchFieldEnum.values) {
      _queuedKeys.remove(_queueKey(path, field));
    }
    _queue.removeWhere((entry) => entry.cardPath == path);
    try {
      await repository.removeCard(path);
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Could not remove $path from index: $e',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Keyword-only ranking. Returns RRF scores from the lexical channel
  /// alone. The grid uses this on the keystroke path so results update
  /// quickly while the meaning embedding is still in flight. Async because
  /// the keyword index is an FTS query (a worker query on web).
  Future<Map<String, double>> rankLexical(
    String query,
    Iterable<String> candidateIds,
  ) async {
    final candidates = candidateIds.toSet();
    final tokens = TextTokenizer.tokenize(query);
    final ordered = await _lexicalPaths(tokens);
    final ids = [
      for (final path in ordered)
        if (candidates.contains(path)) path,
    ];
    final scores = ids.isEmpty
        ? <String, double>{}
        : reciprocalRankFusion([ids]);
    return _applyExactNameOverride(query, candidates, scores);
  }

  /// Full keyword + meaning ranking. Runs the lexical channel, embeds the
  /// query (cached across repeats), scores the meaning channel by exact
  /// cosine over the candidates' stored vectors, and fuses both via RRF.
  Future<Map<String, double>> rank(
    String query,
    Iterable<String> candidateIds,
  ) async {
    final candidates = candidateIds.toSet();
    final tokens = TextTokenizer.tokenize(query);
    final lexicalOrdered = await _lexicalPaths(tokens);
    final lexicalIds = [
      for (final path in lexicalOrdered)
        if (candidates.contains(path)) path,
    ];
    final lexicalSet = lexicalIds.toSet();

    final queryEmbedding = await _resolveQueryEmbedding(query);

    final rankedLists = <List<String>>[];
    if (lexicalIds.isNotEmpty) rankedLists.add(lexicalIds);

    if (queryEmbedding != null) {
      final semanticScores = await _semanticScores(
        queryEmbedding,
        candidates,
        lexicalSet,
      );
      if (semanticScores.isNotEmpty) {
        final semanticIds = semanticScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        rankedLists.add([for (final e in semanticIds) e.key]);
      }
    }

    final fused = rankedLists.isEmpty
        ? <String, double>{}
        : reciprocalRankFusion(rankedLists);
    return _applyExactNameOverride(query, candidates, fused);
  }

  Future<List<String>> _lexicalPaths(List<String> tokens) async {
    try {
      return await repository.rankLexicalPaths(tokens);
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Keyword query failed: $e',
          error: e,
          stackTrace: st,
        ),
      );
      return const [];
    }
  }

  // Admits a card via two paths: lexical-set membership (a literal token
  // match) OR best-field cosine clearing the discovery threshold. Only
  // fully-indexed cards are scored, so noisy half-vectors can't sneak in.
  // Candidates are read from the database in batches to bound memory.
  Future<Map<String, double>> _semanticScores(
    Float32List queryEmbedding,
    Set<String> candidates,
    Set<String> lexicalSet,
  ) async {
    final fieldCount = CardSearchFieldEnum.values.length;
    final ready = [
      for (final path in candidates)
        if ((_hashes[path]?.length ?? 0) == fieldCount) path,
    ];

    final scanList = await _narrowByAnn(queryEmbedding, ready, lexicalSet);

    final scores = <String, double>{};
    for (var start = 0; start < scanList.length; start += _semanticBatchSize) {
      final end = math.min(start + _semanticBatchSize, scanList.length);
      final Map<String, FieldVectors> batch;
      try {
        batch = await repository.vectorsForPaths(scanList.sublist(start, end));
      } on Exception catch (e, st) {
        searchLogger.warning(
          EmbeddingsDiagnosticEvent(
            level: EmbeddingsDiagnosticLevel.warning,
            message: '[Search] Vector read failed: $e',
            error: e,
            stackTrace: st,
          ),
        );
        continue;
      }
      for (final entry in batch.entries) {
        var bestCosine = 0.0;
        var orderingScore = 0.0;
        for (final field in CardSearchFieldEnum.values) {
          final chunks = entry.value[field];
          if (chunks == null || chunks.isEmpty) continue;
          final cos = maxCosine(queryEmbedding, chunks);
          if (cos > bestCosine) bestCosine = cos;
          orderingScore +=
              (field.weight / CardSearchFieldEnum.totalWeight) * cos;
        }
        if (lexicalSet.contains(entry.key) || bestCosine >= _semanticThreshold) {
          scores[entry.key] = orderingScore;
        }
      }
    }
    return scores;
  }

  // Narrows a large candidate pool to the approximate-nearest cards so a
  // meaning query reads a few hundred cards' vectors instead of every
  // candidate's. Literal keyword matches are always kept, so they still get a
  // meaning score. Small or already-filtered pools, and platforms without the
  // add-on, keep the full exact scan unchanged. Skipping the rest is the whole
  // point of the fast path; the kept cards are still reranked exactly upstream.
  Future<List<String>> _narrowByAnn(
    Float32List queryEmbedding,
    List<String> ready,
    Set<String> lexicalSet,
  ) async {
    if (ready.length <= _annCandidateThreshold) {
      LoggingService().info(
        '[SEARCH-VEC] ANN skipped: ${ready.length} candidates ≤ threshold $_annCandidateThreshold',
      );
      return ready;
    }
    if (!await repository.vecAvailable()) {
      LoggingService().info(
        '[SEARCH-VEC] ANN skipped: add-on not available (${ready.length} candidates, brute-force scan)',
      );
      return ready;
    }
    final nearest = await repository.annNearestPaths(
      queryEmbedding,
      _annNearestChunks,
    );
    final narrowed = [
      for (final path in ready)
        if (nearest.contains(path) || lexicalSet.contains(path)) path,
    ];
    LoggingService().info(
      '[SEARCH-VEC] ANN narrowed ${ready.length} → ${narrowed.length} candidates '
      '(kept ${lexicalSet.length} lexical hits, fetched ${nearest.length} ANN results)',
    );
    return narrowed;
  }

  /// Boosts an exact-name match to the top of the fused score map. Fires
  /// only when exactly one candidate's card name equals the trimmed query
  /// case-insensitively — multi-match (variants) and zero-match cases are
  /// no-ops. Inserts even when the card wasn't otherwise scored, so the
  /// display-time gate still keeps it visible.
  Future<Map<String, double>> _applyExactNameOverride(
    String query,
    Set<String> candidates,
    Map<String, double> scores,
  ) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return scores;

    final List<String> matches;
    try {
      matches = await repository.exactNamePaths(normalized);
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Exact-name lookup failed: $e',
          error: e,
          stackTrace: st,
        ),
      );
      return scores;
    }

    String? singleMatch;
    var matchCount = 0;
    for (final path in matches) {
      if (!candidates.contains(path)) continue;
      singleMatch = path;
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
      final fresh = await _embedder.embedOne(query, task: EmbedTaskEnum.query);
      _lastQueryEmbedding = fresh;
      _lastEmbeddedQuery = query;
      return fresh;
    } on EmbeddingsException {
      return null;
    }
  }

  Future<void> _loadHashes() async {
    try {
      final loaded = await repository.loadHashes();
      for (final entry in loaded.entries) {
        final target = _hashes.putIfAbsent(entry.key, () => {});
        for (final fieldHash in entry.value.entries) {
          target.putIfAbsent(fieldHash.key, () => fieldHash.value);
        }
      }
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Could not load change hashes: $e',
          error: e,
          stackTrace: st,
        ),
      );
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
    Map<CardSearchFieldEnum, String>? currentTexts;
    try {
      while (_queue.isNotEmpty) {
        final entry = _queue.removeFirst();
        if (entry.cardPath != activeCardPath) {
          activeCardPath = entry.cardPath;
          // Resolve the card's field texts once per card: from the in-app
          // edit cache if present, else by loading the card from disk.
          currentTexts = await _resolveTexts(entry.cardPath);
          cardTimer
            ..reset()
            ..start();
        }
        _queuedKeys.remove(_queueKey(entry.cardPath, entry.field));
        final changed = currentTexts == null
            ? false
            : await _processOneField(entry, currentTexts);
        if (changed) _dirtyPaths.add(entry.cardPath);

        final remaining = (_pendingPerCard[entry.cardPath] ?? 1) - 1;
        if (remaining > 0) {
          _pendingPerCard[entry.cardPath] = remaining;
        } else {
          _pendingPerCard.remove(entry.cardPath);
        }

        // Rewrite the keyword row once, when the contiguous run of a card's
        // fields ends.
        final isLastForThisCard =
            _queue.isEmpty || _queue.first.cardPath != entry.cardPath;
        if (isLastForThisCard) {
          if (_dirtyPaths.remove(entry.cardPath) && currentTexts != null) {
            await _flushKeywordRow(entry.cardPath, currentTexts);
          }
          cardTimer.stop();
          final prog = progress;
          searchLogger.info(
            EmbeddingsDiagnosticEvent(
              level: EmbeddingsDiagnosticLevel.info,
              message:
                  '[Search] Indexed ${entry.cardPath} '
                  '(${prog.done}/${prog.total}) in '
                  '${cardTimer.elapsedMilliseconds}ms',
            ),
          );
          activeCardPath = null;
        }

        _scheduleNotify();
      }
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

  /// Returns true when the stored vectors for [entry] actually changed, so
  /// the caller marks the card for a keyword-row rewrite. [texts] holds the
  /// card's per-field source text, resolved once per card by the drain.
  Future<bool> _processOneField(
    ({String cardPath, CardSearchFieldEnum field}) entry,
    Map<CardSearchFieldEnum, String> texts,
  ) async {
    final text = texts[entry.field] ?? '';
    final newHash = UtilsHash.fnv1a64Hex(text);
    if (_hashes[entry.cardPath]?[entry.field] == newHash) return false;

    final chunks = await _embedder.chunkByTokens(text);
    List<Float32List> vectors;
    if (chunks.isEmpty) {
      vectors = const [];
    } else {
      try {
        vectors = await _embedder.embed(chunks, task: EmbedTaskEnum.passage);
      } on EmbeddingsException catch (e, st) {
        searchLogger.warning(
          EmbeddingsDiagnosticEvent(
            level: EmbeddingsDiagnosticLevel.warning,
            message:
                '[Search] Embed failed for ${entry.field.name} on '
                '${entry.cardPath}: $e',
            error: e,
            stackTrace: st,
          ),
        );
        return false;
      }
    }

    try {
      await repository.writeField(
        entry.cardPath,
        texts[CardSearchFieldEnum.name] ?? '',
        entry.field,
        vectors,
        newHash,
      );
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message:
              '[Search] Could not store ${entry.field.name} for '
              '${entry.cardPath}: $e',
          error: e,
          stackTrace: st,
        ),
      );
      return false;
    }

    (_hashes[entry.cardPath] ??= {})[entry.field] = newHash;
    return true;
  }

  /// Resolves a card's per-field source text for indexing: from the in-app
  /// edit cache if present, otherwise by loading the card from disk. Returns
  /// null when the card can't be read (logged), so the drain skips it.
  Future<Map<CardSearchFieldEnum, String>?> _resolveTexts(String path) async {
    final pending = _pendingText.remove(path);
    if (pending != null) return pending;
    try {
      final file = await _characterService.loadFull(path);
      return {
        for (final field in CardSearchFieldEnum.values)
          field: _textOf(file.card, field),
      };
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Could not load $path for indexing: $e',
          error: e,
          stackTrace: st,
        ),
      );
      return null;
    }
  }

  Future<void> _flushKeywordRow(
    String cardPath,
    Map<CardSearchFieldEnum, String> texts,
  ) async {
    try {
      await repository.writeFts(
        cardPath,
        texts[CardSearchFieldEnum.name] ?? '',
        texts,
      );
    } on Exception catch (e, st) {
      searchLogger.warning(
        EmbeddingsDiagnosticEvent(
          level: EmbeddingsDiagnosticLevel.warning,
          message: '[Search] Could not write keyword row for $cardPath: $e',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  String _queueKey(String cardPath, CardSearchFieldEnum field) =>
      '$cardPath|${field.name}';

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

  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      _notifyScheduled = false;
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }
}
