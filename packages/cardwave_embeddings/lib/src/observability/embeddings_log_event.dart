/// Sealed family of embeddings-domain log payloads carried as
/// `LogRecord.object`. App-side listeners subscribe to `Logger.root.onRecord`
/// and dispatch on the runtime type.
sealed class EmbeddingsLogEvent {
  const EmbeddingsLogEvent();
}

/// Plain diagnostic message — mirrors info/debug/warning/error.
class EmbeddingsDiagnosticEvent extends EmbeddingsLogEvent {
  const EmbeddingsDiagnosticEvent({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.dataContext,
  });

  final EmbeddingsDiagnosticLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? dataContext;
}

enum EmbeddingsDiagnosticLevel { info, debug, warning, error }
