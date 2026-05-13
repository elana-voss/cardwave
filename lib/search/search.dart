// Barrel file — public API for this domain.
// Files under src/ are private to this domain (enforced by import_lint).
// Cross-domain consumers MUST import this barrel, not src/ paths.

export 'src/models/card_search_data.dart';
export 'src/models/card_search_field_enum.dart';
export 'src/observability/embeddings_loggers.dart';
export 'src/services/search_service.dart';
