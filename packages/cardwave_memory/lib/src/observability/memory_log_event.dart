/// Sealed family of memory-domain log payloads carried as `LogRecord.object`.
/// The app subscribes to `Logger.root.onRecord` and dispatches on the runtime
/// type, the same way it handles the LLM and embeddings domains.
sealed class MemoryLogEvent {
  const MemoryLogEvent();
}

/// Plain diagnostic message — mirrors info/debug/warning/error.
class MemoryDiagnosticEvent extends MemoryLogEvent {
  const MemoryDiagnosticEvent({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.dataContext,
  });

  final MemoryDiagnosticLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? dataContext;
}

enum MemoryDiagnosticLevel { info, debug, warning, error }
