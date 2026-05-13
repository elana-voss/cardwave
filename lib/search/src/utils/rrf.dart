/// Reciprocal Rank Fusion: combines multiple ranked lists into one
/// score per id by summing `1/(k + rank)` across each list the id
/// appears in. `k = 60` is the constant from the original paper.
/// Score-agnostic — no normalization needed between lists with
/// incompatible scales (BM25 scores vs cosine, etc.).
///
/// Empty lists contribute nothing. Calling with a single non-empty list
/// returns `1/(k + rank)` for each id (still sorts that single list
/// correctly), so callers can pass `[lexical]` when the semantic
/// ranking isn't ready yet.
Map<String, double> reciprocalRankFusion(
  List<List<String>> rankedLists, {
  int k = 60,
}) {
  final scores = <String, double>{};
  for (final list in rankedLists) {
    for (var rank = 0; rank < list.length; rank++) {
      final id = list[rank];
      scores[id] = (scores[id] ?? 0) + 1.0 / (k + rank + 1);
    }
  }
  return scores;
}
