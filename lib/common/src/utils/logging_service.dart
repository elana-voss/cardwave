import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum LogLevelEnum {
  info,
  debug,
  warning,
  error,
  llm,
  cache
  ;

  // Deliberately exposes an UPPERCASE constant name. Derived from
  // `toString()` because the built-in `Enum.name` getter is shadowed by
  // this very getter, so `name` here can't reference it.
  // ignore: qcheck/avoid_default_tostring
  String get name => toString().split('.').last.toUpperCase();

  Color get color {
    switch (this) {
      case LogLevelEnum.info:
        return Colors.green;
      case LogLevelEnum.debug:
        return Colors.blue;
      case LogLevelEnum.warning:
        return Colors.orange;
      case LogLevelEnum.error:
        return Colors.red;
      case LogLevelEnum.llm:
        return Colors.purpleAccent;
      case LogLevelEnum.cache:
        return Colors.cyan;
    }
  }

  String get ansiColor {
    switch (this) {
      case LogLevelEnum.info:
        return '\x1B[32m'; // Green
      case LogLevelEnum.debug:
        return '\x1B[34m'; // Blue
      case LogLevelEnum.warning:
        return '\x1B[33m'; // Yellow
      case LogLevelEnum.error:
        return '\x1B[31m'; // Red
      case LogLevelEnum.llm:
        return '\x1B[35m'; // Magenta
      case LogLevelEnum.cache:
        return '\x1B[36m'; // Cyan
    }
  }
}

class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.dataContext,
  }) : timestamp = DateTime.now();
  final DateTime timestamp;
  final LogLevelEnum level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  /// For easier debugging
  final String? dataContext;
}

class LoggingService {
  factory LoggingService() {
    return _instance;
  }

  LoggingService._internal();
  static final LoggingService _instance = LoggingService._internal();

  static const int _maxLogs = 1000;

  // Bearer stops at the first non-token char so it doesn't swallow the
  // trailing `}` of a headers-map log line.
  static final RegExp _bearerRegex = RegExp(
    r'(Authorization:\s*Bearer\s+)([A-Za-z0-9\-\._~+/=]+)',
    caseSensitive: false,
  );
  static final RegExp _xApiKeyRegex = RegExp(
    r'(x-api-key:\s*)([a-zA-Z0-9\-\._]+)',
    caseSensitive: false,
  );
  static final RegExp _xaiKeyRegex = RegExp(r'xai-[a-zA-Z0-9\-\_]+');
  static final RegExp _openAiKeyRegex = RegExp('sk-[a-zA-Z0-9]{20,}');
  static final RegExp _anthropicKeyRegex = RegExp(r'sk-ant-[a-zA-Z0-9\-\_]+');
  final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier([]);

  void _addLog(LogEntry entry) {
    if (kDebugMode) {
      final time = entry.timestamp
          .toIso8601String()
          .split('T')
          .last
          .substring(0, 12);
      final msg = entry.message;
      final err = entry.error != null ? '\nError: ${entry.error}' : '';
      final stack = entry.stackTrace != null ? '\n${entry.stackTrace}' : '';
      final dataContext = entry.dataContext != null
          ? '\n${entry.dataContext}'
          : '';

      debugPrint(
        '${entry.level.ansiColor}[$time] [${entry.level.name}] $msg$err$stack$dataContext\x1B[0m',
      );
    }

    final currentLogs = List<LogEntry>.of(logsNotifier.value);
    currentLogs.add(entry);
    if (currentLogs.length > _maxLogs) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogs);
    }
    logsNotifier.value = currentLogs;
  }

  /// Logs a generic message
  void log(String message) {
    info(message);
  }

  /// Logs an info message (e.g. process started)
  void info(String message) {
    _addLog(LogEntry(level: LogLevelEnum.info, message: _sanitize(message)));
  }

  /// Logs a debug message
  void debug(String message) {
    _addLog(LogEntry(level: LogLevelEnum.debug, message: _sanitize(message)));
  }

  /// Logs a warning
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _addLog(
      LogEntry(
        level: LogLevelEnum.warning,
        message: _sanitize(message),
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  /// Logs an error with optional exception and stack trace
  void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    String? dataContext,
  ]) {
    _addLog(
      LogEntry(
        level: LogLevelEnum.error,
        message: _sanitize(message),
        error: error,
        stackTrace: stackTrace,
        dataContext: dataContext,
      ),
    );
  }

  /// Logs an LLM request/response specifically
  void logLlm(String title, String content) {
    _addLog(
      LogEntry(level: LogLevelEnum.llm, message: _sanitize('$title\n$content')),
    );
  }

  /// Logs a cache read/write event (kept on its own level so read/write
  /// traces can be filtered or isolated from general info noise).
  void logCache(String message) {
    _addLog(LogEntry(level: LogLevelEnum.cache, message: _sanitize(message)));
  }

  /// Sanitizes sensitive information from logs
  String _sanitize(String input) {
    return input
        .replaceAll(_bearerRegex, r'$1[REDACTED]')
        .replaceAll(_xApiKeyRegex, r'$1[REDACTED]')
        .replaceAll(_xaiKeyRegex, '[REDACTED_XAI_KEY]')
        .replaceAll(_openAiKeyRegex, '[REDACTED_OPENAI_KEY]')
        .replaceAll(_anthropicKeyRegex, '[REDACTED_ANTHROPIC_KEY]');
  }

  /// Sets up global error handling to capture unhandled exceptions
  void captureUnhandledErrors() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      error('Flutter Error', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (exception, stack) {
      error('Async Error', exception, stack);
      return true;
    };
  }
}
