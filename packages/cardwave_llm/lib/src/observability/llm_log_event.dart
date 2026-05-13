/// Sealed family of LLM-domain log payloads carried as `LogRecord.object`.
sealed class LlmLogEvent {
  const LlmLogEvent();
}

/// Category labels for structured trace events. The bridge wraps each in
/// `[LABEL]` to match today's `LoggingService.logLlm` title format.
enum LlmEventCategoryEnum {
  tts('TTS'),
  imageGen('IMAGE-GEN'),
  video('VIDEO'),
  models('MODELS'),
  runner('RUNNER'),
  toolCall('TOOL-CALL')
  ;

  const LlmEventCategoryEnum(this.label);
  final String label;
}

/// Structured trace event — mirrors today's `LoggingService.logLlm(title, body)`.
class LlmStructuredEvent extends LlmLogEvent {
  const LlmStructuredEvent({
    required this.category,
    required this.title,
    required this.body,
    this.providerEnumName,
    this.modelId,
    this.latencyMs,
  });

  final LlmEventCategoryEnum category;
  final String title;
  final String body;
  final String? providerEnumName;
  final String? modelId;
  final int? latencyMs;
}

/// Plain diagnostic message — mirrors info/debug/warning/error.
class LlmDiagnosticEvent extends LlmLogEvent {
  const LlmDiagnosticEvent({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.dataContext,
  });

  final LlmDiagnosticLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? dataContext;
}

enum LlmDiagnosticLevel { info, debug, warning, error }

/// Cache trace event — mirrors `LoggingService.logCache(message)`.
class LlmCacheEvent extends LlmLogEvent {
  const LlmCacheEvent({required this.message});
  final String message;
}
