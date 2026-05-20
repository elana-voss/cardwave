import 'dart:typed_data';

/// Dot product — equals cosine when both vectors are L2-normalized
/// (which our BGE-small embedder produces).
double cosineNormalized(Float32List a, Float32List b) {
  assert(a.length == b.length, 'cosine vectors must be the same length');
  var sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    // `b` is the same length as `a` (asserted above).
    // ignore: qcheck/avoid_unsafe_collection_methods
    sum += a[i] * b[i];
  }
  return sum;
}

/// Highest cosine across [chunks], clamped to [0, 1]. Empty list returns 0.
double maxCosine(Float32List query, List<Float32List> chunks) {
  if (chunks.isEmpty) return 0;
  var best = 0.0;
  for (final chunk in chunks) {
    final c = cosineNormalized(query, chunk);
    if (c > best) best = c;
  }
  return best;
}
