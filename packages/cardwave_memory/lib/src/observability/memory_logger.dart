import 'package:cardwave_memory/src/observability/memory_log_event.dart';
import 'package:logging/logging.dart';

/// Package-wide logger. Each record carries a [MemoryLogEvent] as its
/// `LogRecord.object`, which the app routes to its on-screen log. The name sits
/// under the `cardwave.` namespace the app's log router forwards; a plain
/// `cardwave_memory` would be filtered out.
final Logger _logger = Logger('cardwave.memory');

/// A one-line note about what memory just did (extracted, retired, dropped).
void logMemoryInfo(String message) => _logger.info(
  MemoryDiagnosticEvent(level: MemoryDiagnosticLevel.info, message: message),
);

/// A memory step that failed or produced unusable output; the turn continues.
void logMemoryWarning(
  String message, [
  Object? error,
  StackTrace? stackTrace,
]) => _logger.warning(
  MemoryDiagnosticEvent(
    level: MemoryDiagnosticLevel.warning,
    message: message,
    error: error,
    stackTrace: stackTrace,
  ),
);
