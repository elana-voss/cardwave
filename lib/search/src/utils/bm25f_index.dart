import 'dart:isolate';
import 'dart:math' as math;

import 'package:cardwave/search/src/models/card_search_field_enum.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Per-field BM25 (Robertson/Zaragoza form) over the in-memory card pool.
/// Combines per-field term frequency BEFORE saturation, which avoids the
/// failure mode of "vanilla per-field BM25 then sum" — that variant
/// saturates each field independently, letting a strong scenario hit
/// out-rank a name hit because each field saturates separately.
class Bm25fIndex {
  const Bm25fIndex._({
    required Map<String, Map<CardSearchFieldEnum, Map<String, int>>> tf,
    required Map<String, Map<CardSearchFieldEnum, int>> len,
    required Map<CardSearchFieldEnum, double> avgLen,
    required Map<String, double> idf,
    required Map<String, Set<String>> docsWithToken,
  }) : _tf = tf,
       _len = len,
       _avgLen = avgLen,
       _idf = idf,
       _docsWithToken = docsWithToken;

  /// BM25 saturation parameter. 1.2 is the classical default.
  static const double _k1 = 1.2;

  /// Length normalization weight. 0.75 is the classical default.
  static const double _b = 0.75;

  final Map<String, Map<CardSearchFieldEnum, Map<String, int>>> _tf;
  final Map<String, Map<CardSearchFieldEnum, int>> _len;
  final Map<CardSearchFieldEnum, double> _avgLen;
  final Map<String, double> _idf;
  final Map<String, Set<String>> _docsWithToken;

  /// Score every candidate that contains at least one query token,
  /// returning entries in descending-score order. Zero-score candidates
  /// are dropped (they don't contain any query token in any field).
  List<MapEntry<String, double>> rankAll(
    List<String> queryTokens,
    Iterable<String> candidateIds,
  ) {
    if (queryTokens.isEmpty) return const [];
    final candidates = candidateIds.toSet();
    if (candidates.isEmpty) return const [];

    final relevant = <String>{};
    for (final token in queryTokens) {
      final docs = _docsWithToken[token];
      if (docs == null) continue;
      for (final doc in docs) {
        if (candidates.contains(doc)) relevant.add(doc);
      }
    }
    if (relevant.isEmpty) return const [];

    final scores = <String, double>{};
    for (final cardId in relevant) {
      final cardTf = _tf[cardId];
      final cardLen = _len[cardId];
      if (cardTf == null || cardLen == null) continue;
      var total = 0.0;
      for (final token in queryTokens) {
        final idf = _idf[token];
        if (idf == null || idf <= 0) continue;
        var weightedTf = 0.0;
        for (final field in CardSearchFieldEnum.values) {
          final fieldTf = cardTf[field]?[token] ?? 0;
          if (fieldTf == 0) continue;
          final len = cardLen[field] ?? 0;
          final avgLen = _avgLen[field] ?? 0;
          if (avgLen == 0) continue;
          final lengthNorm = 1 + _b * (len / avgLen - 1);
          weightedTf += _boostFor(field) * fieldTf / lengthNorm;
        }
        if (weightedTf > 0) {
          total += idf * weightedTf / (_k1 + weightedTf);
        }
      }
      if (total > 0) scores[cardId] = total;
    }

    return scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Per-field boost. Source `weight` divided by 10 keeps the boost in
  /// the range where BM25's saturation curve doesn't crush the gap
  /// between high- and low-weighted fields. Scenario (weight 1) lands at
  /// 0.1 — quiet but still scored.
  static double _boostFor(CardSearchFieldEnum field) => field.weight / 10;

  /// Builds the index from per-card pre-tokenized snapshots. On native,
  /// hops to a background isolate so the main thread stays free during
  /// the cold-start ~40 s pass over a large library. On web (no real
  /// isolates; `Isolate.run` throws `UnsupportedError`), runs in a
  /// chunked loop on the main thread that yields to the event loop
  /// every [_webYieldEvery] cards so the browser keeps painting.
  static Future<Bm25fIndex> buildFromSnapshots(
    List<CardTokenSnapshot> snapshots,
  ) {
    if (kIsWeb) {
      return _buildWeb(snapshots);
    }
    return Isolate.run(() => _buildSync(snapshots));
  }

  /// How many cards a chunk processes between event-loop yields on web.
  /// 20 keeps each chunk well under a frame budget on a desktop browser
  /// while not bloating wall-clock with too many micro-yields.
  static const int _webYieldEvery = 20;

  static Future<Bm25fIndex> _buildWeb(
    List<CardTokenSnapshot> snapshots,
  ) async {
    final state = _BuildState();
    for (var i = 0; i < snapshots.length; i++) {
      if (i > 0 && i % _webYieldEvery == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      _ingestSnapshot(state, snapshots[i]);
    }
    return _finalize(state, snapshots.length);
  }

  static Bm25fIndex _buildSync(List<CardTokenSnapshot> snapshots) {
    final state = _BuildState();
    for (final snap in snapshots) {
      _ingestSnapshot(state, snap);
    }
    return _finalize(state, snapshots.length);
  }

  static void _ingestSnapshot(_BuildState state, CardTokenSnapshot snap) {
    final cardTf = <CardSearchFieldEnum, Map<String, int>>{};
    final cardLen = <CardSearchFieldEnum, int>{};
    final tokensInDoc = <String>{};

    for (final field in CardSearchFieldEnum.values) {
      final tokens = snap.tokensByField[field] ?? const <String>[];
      cardLen[field] = tokens.length;
      state.lenSumByField[field] = state.lenSumByField[field]! + tokens.length;
      if (tokens.isEmpty) continue;
      final fieldCounts = <String, int>{};
      for (final t in tokens) {
        fieldCounts[t] = (fieldCounts[t] ?? 0) + 1;
        tokensInDoc.add(t);
        state.docsWithToken.putIfAbsent(t, () => {}).add(snap.id);
      }
      cardTf[field] = fieldCounts;
    }

    for (final t in tokensInDoc) {
      state.docFreq[t] = (state.docFreq[t] ?? 0) + 1;
    }

    state.tf[snap.id] = cardTf;
    state.len[snap.id] = cardLen;
  }

  static Bm25fIndex _finalize(_BuildState state, int n) {
    final avgLen = <CardSearchFieldEnum, double>{
      for (final f in CardSearchFieldEnum.values)
        f: n == 0 ? 0 : state.lenSumByField[f]! / n,
    };

    // Lucene-style IDF: log(1 + (N - n_t + 0.5) / (n_t + 0.5)). Always
    // positive, even for small corpora where the bare Robertson form
    // hits 0 (e.g. N=2 with n_t=1 → log(1)=0, dropping the token from
    // ranking). Modern BM25 implementations (Lucene, Elasticsearch) use
    // this variant for exactly that reason.
    final idf = <String, double>{};
    for (final entry in state.docFreq.entries) {
      idf[entry.key] = math.log(
        1 + (n - entry.value + 0.5) / (entry.value + 0.5),
      );
    }

    return Bm25fIndex._(
      tf: state.tf,
      len: state.len,
      avgLen: avgLen,
      idf: idf,
      docsWithToken: state.docsWithToken,
    );
  }
}

class _BuildState {
  final Map<String, Map<CardSearchFieldEnum, Map<String, int>>> tf = {};
  final Map<String, Map<CardSearchFieldEnum, int>> len = {};
  final Map<String, int> docFreq = {};
  final Map<String, Set<String>> docsWithToken = {};
  final Map<CardSearchFieldEnum, int> lenSumByField = {
    for (final f in CardSearchFieldEnum.values) f: 0,
  };
}

/// Per-card pre-tokenized snapshot fed into the index build. Holds only
/// primitives + maps so it crosses the isolate boundary cleanly. Plain
/// class (not a record) because record-in-list isolate transfer
/// previously surfaced as silent data loss in our setup.
class CardTokenSnapshot {
  const CardTokenSnapshot({required this.id, required this.tokensByField});

  final String id;
  final Map<CardSearchFieldEnum, List<String>> tokensByField;
}
