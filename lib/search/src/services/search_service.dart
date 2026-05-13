import 'dart:async';
import 'dart:collection';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/search/src/models/card_search_data.dart';
import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:cardwave/search/src/observability/embeddings_loggers.dart';
import 'package:cardwave/search/src/repositories/search_repository.dart';
import 'package:cardwave/search/src/utils/bm25f_index.dart';
import 'package:cardwave/search/src/utils/cosine.dart';
import 'package:cardwave/search/src/utils/rrf.dart';
import 'package:cardwave/search/src/utils/text_tokenizer.dart';
import 'package:cardwave_embeddings/cardwave_embeddings.dart';
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

  final SearchRepository repository;
  final Embedder _embedder;

  // CharacterService and this service take each other; the loop is broken
  // by deferring the back-pointer to init() (see main.dart).
  late final CharacterService _characterService;

  // Per-card data + a parallel CharacterFile lookup so the worker can
  // resolve a queue entry's cardPath in O(1) instead of scanning every
  // loaded card.
  final Map<String, CardSearchData> _byPath = {};
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
  Bm25fIndex? _bm25Index;
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
  CardSearchData? embeddingsFor(String cardImagePath) => _byPath[cardImagePath];

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
      CardSearchData.empty,
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
    final tokens = TextTokenizer.tokenize(query);
    final lexical = _bm25Index?.rankAll(tokens, candidateIds) ?? const [];
    if (lexical.isEmpty) return const {};
    final ids = lexical.map((e) => e.key).toList();
    return reciprocalRankFusion([ids]);
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

    final queryEmbedding = await _resolveQueryEmbedding(query);

    final rankedLists = <List<String>>[];
    if (lexicalIds.isNotEmpty) rankedLists.add(lexicalIds);

    if (queryEmbedding != null) {
      final semanticScores = <String, double>{};
      for (final id in candidates) {
        final data = _byPath[id];
        if (data == null) continue;
        final allChunks = data.byField.values
            .expand((chunks) => chunks)
            .toList();
        if (allChunks.isEmpty) continue;
        final score = maxCosine(queryEmbedding, allChunks);
        if (score > 0) semanticScores[id] = score;
      }
      if (semanticScores.isNotEmpty) {
        final semanticIds = semanticScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        rankedLists.add(semanticIds.map((e) => e.key).toList());
      }
    }

    if (rankedLists.isEmpty) return const {};
    return reciprocalRankFusion(rankedLists);
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
      _byPath[card.appCardImagePath] = CardSearchData.empty();
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
        final Bm25fIndex fresh;
        try {
          fresh = await Bm25fIndex.buildFromSnapshots(snapshots);
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

  List<CardTokenSnapshot> _collectBm25Snapshots() {
    final snapshots = <CardTokenSnapshot>[];
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
        CardTokenSnapshot(id: entry.key, tokensByField: tokensByField),
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
