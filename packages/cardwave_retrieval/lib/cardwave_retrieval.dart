// Top-level barrel — public API for the cardwave_retrieval package.
// Files under src/ are private to this package (enforced by import_lint).
// Cross-package consumers MUST import this barrel, not src/ paths.

export 'src/models/vector_sidecar_codec.dart';
export 'src/utils/bm25f_index.dart';
export 'src/utils/cosine.dart';
export 'src/utils/rrf.dart';
export 'src/utils/text_tokenizer.dart';
