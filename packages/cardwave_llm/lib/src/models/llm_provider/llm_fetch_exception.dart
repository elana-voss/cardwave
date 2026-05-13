part of '../llm_provider.dart';

class LlmFetchException implements Exception {
  const LlmFetchException({
    required this.provider,
    required this.providerLabel,
    required this.message,
    this.statusCode,
    this.cause,
  });
  final LLMProviderEnum provider;
  final String providerLabel;
  final int? statusCode;
  final String message;
  final Object? cause;

  String get userMessage {
    final parsed = _parseProviderMessage(message);
    final code = statusCode;
    if (code == null) {
      return parsed ??
          'Could not reach $providerLabel. Check your internet connection.';
    }
    if (parsed != null) return '$providerLabel: $parsed';
    if (code == 401 || code == 403) {
      return 'Invalid API key for $providerLabel. '
          'Check your credentials in the provider settings.';
    }
    if (code == 429) {
      return '$providerLabel rate limit reached. Please wait a moment and try again.';
    }
    if (code >= 400 && code < 500) {
      return '$providerLabel rejected the request (HTTP $code). '
          'This usually means the API key or request is invalid.';
    }
    if (code >= 500) {
      return '$providerLabel is temporarily unavailable (HTTP $code). '
          'Please try again in a moment.';
    }
    return '$providerLabel returned an unexpected response (HTTP $code).';
  }

  /// Providers return structured JSON error bodies like
  /// `{"error":{"message":"..."}}` (OpenAI / OpenRouter / NanoGpt) or
  /// `{"message":"..."}`. Pull the human-readable string so the snackbar
  /// shows "No endpoints available matching your guardrail restrictions…"
  /// instead of a JSON blob. Returns null when the body isn't JSON or
  /// carries no readable message.
  static String? _parseProviderMessage(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on Exception {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final err = decoded['error'];
    if (err is Map<String, dynamic>) {
      final m = err['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    if (err is String && err.isNotEmpty) return err;
    final topMessage = decoded['message'];
    if (topMessage is String && topMessage.isNotEmpty) return topMessage;
    return null;
  }

  bool get canRetry {
    final code = statusCode;
    if (code == null) return true;
    if (code == 429) return true;
    if (code >= 400 && code < 500) return false;
    return true;
  }

  @override
  String toString() =>
      'LlmFetchException(${provider.name}, status=$statusCode, $message)';
}
