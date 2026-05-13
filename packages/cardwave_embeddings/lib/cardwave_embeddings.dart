// Top-level barrel — public API for the cardwave_embeddings package.
// Files under src/ are private to this package (enforced by import_lint).
// Cross-package consumers MUST import this barrel, not src/ paths.

export 'src/dispatcher/cardwave_embeddings_module.dart';
export 'src/engine/embedder.dart';
export 'src/models/embed_task_enum.dart';
export 'src/models/embeddings_exception.dart';
export 'src/observability/embeddings_log_event.dart';
export 'src/utils/embedder_constants.dart'
    show embeddingsDim, embeddingsModelFilename, embeddingsModelId;
