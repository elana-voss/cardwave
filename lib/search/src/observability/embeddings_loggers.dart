import 'package:logging/logging.dart';

/// App-side search-pipeline logger. Call sites emit a typed
/// `EmbeddingsDiagnosticEvent` (from `cardwave_embeddings`) as the
/// `LogRecord.object`.
final Logger searchLogger = Logger('cardwave.search.indexer');
