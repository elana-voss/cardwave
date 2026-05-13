import 'dart:convert';

class UtilsLlm {
  static final Map<String, int> _tokenCache = {};

  static const int _maxCacheEntries = 100;

  // Paired: stripThinkTags and extractThinkContent must agree on what counts
  // as a tag, so they share one regex. Handles both <think> and <thinking>
  // because open-weights models (R1, QwQ, Hermes, Kimi) emit either.
  static final RegExp _thinkTagRegex = RegExp(
    r'<think(?:ing)?\s*>([\s\S]*?)<\/think(?:ing)?\s*>',
    caseSensitive: false,
  );

  static bool _hasThinkTag(String raw) =>
      raw.contains('<think') || raw.contains('<THINK');

  static String stripThinkTags(String raw) {
    if (raw.isEmpty || !_hasThinkTag(raw)) return raw;
    return raw.replaceAll(_thinkTagRegex, '').trim();
  }

  static String? extractThinkContent(String raw) {
    if (raw.isEmpty || !_hasThinkTag(raw)) return null;
    final matches = _thinkTagRegex.allMatches(raw);
    if (matches.isEmpty) return null;
    final joined = matches
        .map((m) => m.group(1)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    return joined.isEmpty ? null : joined;
  }

  // Rough heuristic: ~4 characters per token. Good enough for UI budgeting
  // until a real tokenizer is wired in. Known to over-estimate for CJK text
  // and under-estimate for code.
  static const double _charsPerToken = 4;

  static void warmUp() {/* no-op until a real tokenizer is wired in */}

  /// Best-effort extraction of a short, user-readable error string from an
  /// arbitrary thrown object. Unwraps common OpenAI-compatible JSON error
  /// envelopes (`{"error":{"message":"..."}}`) and falls back to a cleaned
  /// `toString()` — collapses pathologically long bodies to a generic
  /// message so the snackbar never shows a dump.
  static String extractUserFriendlyError(Object error) {
    final rawError = error.toString();

    if (rawError.contains('guardrail') || rawError.contains('data policy')) {
      return 'This model is blocked by your OpenRouter privacy settings. '
          'Pick a different model, or adjust your policy at '
          'https://openrouter.ai/settings/privacy';
    }

    try {
      final startIndex = rawError.indexOf('{');
      final endIndex = rawError.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
        final jsonString = rawError.substring(startIndex, endIndex + 1);
        final decoded = jsonDecode(jsonString);
        if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
          final errorData = decoded['error'];
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            return errorData['message'].toString();
          }
        }
      }
    } on Exception {
      // Body was not JSON — fall through to string-cleanup path.
    }

    final cleanedError = rawError.replaceFirst(
      RegExp(r'^(Exception|Error):\s*'),
      '',
    );
    if (cleanedError.length > 150) {
      return 'Service temporarily unavailable or returned an invalid response.';
    }
    return cleanedError;
  }

  static Future<int> countTokens(String text) async {
    if (text.isEmpty) return 0;

    final cached = _tokenCache[text];
    if (cached != null) return cached;

    await Future.delayed(Duration.zero);

    final count = (text.length / _charsPerToken).ceil();

    if (_tokenCache.length >= _maxCacheEntries) {
      // Guarded by the length check above; `_maxCacheEntries` is positive.
      // ignore: qcheck/avoid_unsafe_collection_methods
      _tokenCache.remove(_tokenCache.keys.first);
    }
    _tokenCache[text] = count;
    return count;
  }
}
