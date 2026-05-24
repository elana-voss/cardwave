import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Per-field BM25 (Robertson/Zaragoza form) over an in-memory document pool.
/// Combines per-field term frequency BEFORE saturation, which avoids the
/// failure mode of "vanilla per-field BM25 then sum" — that variant
/// saturates each field independently, letting a long low-priority field
/// out-rank a short high-priority field because each saturates separately.
///
/// Generic over the field enum [F]: the caller supplies the field list and a
/// per-field boost map at build time, so the same index serves any document
/// shape (cards, story events, …).
class Bm25fIndex<F extends Enum> {
  const Bm25fIndex._({
    required List<F> fields,
    required Map<F, double> fieldWeights,
    required Map<String, Map<F, Map<String, int>>> tf,
    required Map<String, Map<F, int>> len,
    required Map<F, double> avgLen,
    required Map<String, double> idf,
    required Map<String, Set<String>> docsWithToken,
  }) : _fields = fields,
       _fieldWeights = fieldWeights,
       _tf = tf,
       _len = len,
       _avgLen = avgLen,
       _idf = idf,
       _docsWithToken = docsWithToken;

  /// BM25 saturation parameter. 1.2 is the classical default.
  static const double _k1 = 1.2;

  /// Length normalization weight. 0.75 is the classical default.
  static const double _b = 0.75;

  final List<F> _fields;
  final Map<F, double> _fieldWeights;
  final Map<String, Map<F, Map<String, int>>> _tf;
  final Map<String, Map<F, int>> _len;
  final Map<F, double> _avgLen;
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
    for (final docId in relevant) {
      final docTf = _tf[docId];
      final docLen = _len[docId];
      if (docTf == null || docLen == null) continue;
      var total = 0.0;
      for (final token in queryTokens) {
        final idf = _idf[token];
        if (idf == null || idf <= 0) continue;
        var weightedTf = 0.0;
        for (final field in _fields) {
          final fieldTf = docTf[field]?[token] ?? 0;
          if (fieldTf == 0) continue;
          final len = docLen[field] ?? 0;
          final avgLen = _avgLen[field] ?? 0;
          if (avgLen == 0) continue;
          final lengthNorm = 1 + _b * (len / avgLen - 1);
          weightedTf += _boostFor(field) * fieldTf / lengthNorm;
        }
        if (weightedTf > 0) {
          total += idf * weightedTf / (_k1 + weightedTf);
        }
      }
      if (total > 0) scores[docId] = total;
    }

    return scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Per-field boost multiplier, supplied by the caller at build time. A
  /// field absent from the map contributes no boost.
  double _boostFor(F field) => _fieldWeights[field] ?? 0;

  /// Builds the index from per-document pre-tokenized snapshots. On native,
  /// hops to a background isolate so the main thread stays free during the
  /// cold-start pass over a large pool. On web (no real isolates;
  /// `Isolate.run` throws `UnsupportedError`), runs in a chunked loop on the
  /// main thread that yields to the event loop every [_webYieldEvery]
  /// documents so the browser keeps painting.
  static Future<Bm25fIndex<F>> buildFromSnapshots<F extends Enum>(
    List<TokenSnapshot<F>> snapshots, {
    required List<F> fields,
    required Map<F, double> fieldWeights,
  }) {
    if (kIsWeb) {
      return _buildWeb<F>(snapshots, fields, fieldWeights);
    }
    // See class doc above: kIsWeb branch handles web with chunked yields;
    // this line is native-only. `compute()` would silence the lint but
    // would lose the per-chunk yields the web path depends on.
    // ignore: qcheck/prefer_compute_over_isolate_run
    return Isolate.run(() => _buildSync<F>(snapshots, fields, fieldWeights));
  }

  /// How many documents a chunk processes between event-loop yields on web.
  /// 20 keeps each chunk well under a frame budget on a desktop browser
  /// while not bloating wall-clock with too many micro-yields.
  static const int _webYieldEvery = 20;

  static Future<Bm25fIndex<F>> _buildWeb<F extends Enum>(
    List<TokenSnapshot<F>> snapshots,
    List<F> fields,
    Map<F, double> fieldWeights,
  ) async {
    final state = _BuildState<F>(fields);
    for (var i = 0; i < snapshots.length; i++) {
      if (i > 0 && i % _webYieldEvery == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      _ingestSnapshot<F>(state, snapshots[i], fields);
    }
    return _finalize<F>(state, snapshots.length, fields, fieldWeights);
  }

  static Bm25fIndex<F> _buildSync<F extends Enum>(
    List<TokenSnapshot<F>> snapshots,
    List<F> fields,
    Map<F, double> fieldWeights,
  ) {
    final state = _BuildState<F>(fields);
    for (final snap in snapshots) {
      _ingestSnapshot<F>(state, snap, fields);
    }
    return _finalize<F>(state, snapshots.length, fields, fieldWeights);
  }

  static void _ingestSnapshot<F extends Enum>(
    _BuildState<F> state,
    TokenSnapshot<F> snap,
    List<F> fields,
  ) {
    final docTf = <F, Map<String, int>>{};
    final docLen = <F, int>{};
    final tokensInDoc = <String>{};

    for (final field in fields) {
      final tokens = snap.tokensByField[field] ?? const <String>[];
      docLen[field] = tokens.length;
      state.lenSumByField[field] = state.lenSumByField[field]! + tokens.length;
      if (tokens.isEmpty) continue;
      final fieldCounts = <String, int>{};
      for (final t in tokens) {
        fieldCounts[t] = (fieldCounts[t] ?? 0) + 1;
        tokensInDoc.add(t);
        state.docsWithToken.putIfAbsent(t, () => {}).add(snap.id);
      }
      docTf[field] = fieldCounts;
    }

    for (final t in tokensInDoc) {
      state.docFreq[t] = (state.docFreq[t] ?? 0) + 1;
    }

    state.tf[snap.id] = docTf;
    state.len[snap.id] = docLen;
  }

  static Bm25fIndex<F> _finalize<F extends Enum>(
    _BuildState<F> state,
    int n,
    List<F> fields,
    Map<F, double> fieldWeights,
  ) {
    final avgLen = <F, double>{
      for (final f in fields) f: n == 0 ? 0 : state.lenSumByField[f]! / n,
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

    return Bm25fIndex<F>._(
      fields: fields,
      fieldWeights: fieldWeights,
      tf: state.tf,
      len: state.len,
      avgLen: avgLen,
      idf: idf,
      docsWithToken: state.docsWithToken,
    );
  }
}

class _BuildState<F extends Enum> {
  _BuildState(List<F> fields)
    : lenSumByField = {for (final f in fields) f: 0};

  final Map<String, Map<F, Map<String, int>>> tf = {};
  final Map<String, Map<F, int>> len = {};
  final Map<String, int> docFreq = {};
  final Map<String, Set<String>> docsWithToken = {};
  final Map<F, int> lenSumByField;
}

/// Per-document pre-tokenized snapshot fed into the index build. Holds only
/// primitives + maps so it crosses the isolate boundary cleanly. Plain
/// class (not a record) because record-in-list isolate transfer previously
/// surfaced as silent data loss in our setup.
class TokenSnapshot<F extends Enum> {
  const TokenSnapshot({required this.id, required this.tokensByField});

  final String id;
  final Map<F, List<String>> tokensByField;
}
