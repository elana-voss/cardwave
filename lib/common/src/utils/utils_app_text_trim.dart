/// Trims incomplete trailing content from LLM replies that got cut off
/// mid-sentence or mid-paragraph.
///
/// Strategy: sentence-level trim first, paragraph-level fallback, with a
/// "don't nuke short messages" safety net — if either strategy would remove
/// too much of the original, the original is returned unchanged.
class UtilsAppTextTrim {
  /// Minimum fraction of the original length the trimmed result must retain.
  static const double _minKeepRatio = 0.4;

  /// Absolute minimum character count the trimmed result must retain.
  /// The threshold passes if the result meets EITHER the ratio OR the floor.
  static const int _minKeepChars = 120;

  /// Characters that can legitimately close a sentence. Includes roleplay
  /// dialogue/action closers (quotes, asterisks, tildes).
  static final RegExp _trailingTerminalRE = RegExp(r'''[.!?…*"”~’']\s*$''');

  static final RegExp _newlineRE = RegExp(r'\r\n|\n|\r');

  /// Known short abbreviations whose trailing `.` must NOT be treated as a
  /// sentence boundary. Matched case-insensitively on the token preceding the
  /// dot.
  static const Set<String> _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'st',
    'vs',
    'etc',
    'e.g',
    'i.e',
    'cf',
    'no',
  };

  /// Returns [text] with any incomplete trailing sentence/paragraph removed.
  /// Never returns an empty string; if the result would be empty or fall
  /// below the safety threshold, returns [text] unchanged.
  static String trim(String text) {
    if (text.isEmpty) return text;

    // Fast path — already ends cleanly, nothing to do.
    if (_trailingTerminalRE.hasMatch(text)) return text;

    final sentenceTrimmed = _trimToLastSentenceEnd(text);
    if (sentenceTrimmed != null && _passesThreshold(text, sentenceTrimmed)) {
      return sentenceTrimmed;
    }

    final paragraphTrimmed = _trimTrailingParagraphsLoop(text);
    if (paragraphTrimmed != text && _passesThreshold(text, paragraphTrimmed)) {
      return paragraphTrimmed;
    }

    return text;
  }

  /// Scans backwards for the last valid sentence-ending punctuation and
  /// returns the substring up to and including it. Returns null if no valid
  /// boundary is found.
  static String? _trimToLastSentenceEnd(String text) {
    for (var i = text.length - 1; i >= 0; i--) {
      final ch = text[i];
      if (!_isTerminalChar(ch)) continue;
      if (!_isValidBoundary(text, i)) continue;
      final cut = _extendOverClosers(text, i);
      final result = text.substring(0, cut + 1).trimRight();
      if (result.isEmpty) return null;
      return result;
    }
    return null;
  }

  static bool _isTerminalChar(String ch) =>
      ch == '.' || ch == '!' || ch == '?' || ch == '…';

  /// Checks that a terminal char at [index] is a real sentence end — not an
  /// abbreviation, not a decimal, not mid-number.
  static bool _isValidBoundary(String text, int index) {
    final ch = text[index];

    if (ch == '.') {
      // Decimal: digit on both sides.
      if (index > 0 &&
          index < text.length - 1 &&
          _isDigit(text[index - 1]) &&
          _isDigit(text[index + 1])) {
        return false;
      }
      // Abbreviation: preceding letter-run matches a known short abbr,
      // OR the next non-space char is lowercase (continuing a sentence).
      if (_isAbbreviation(text, index)) return false;
      if (_nextNonSpaceIsLowercase(text, index)) return false;
    }

    return true;
  }

  static bool _isDigit(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isAbbreviation(String text, int dotIndex) {
    var start = dotIndex - 1;
    while (start >= 0 && _isLetter(text[start])) {
      start--;
    }
    final token = text.substring(start + 1, dotIndex).toLowerCase();
    if (token.isEmpty) return false;
    return _abbreviations.contains(token);
  }

  static bool _isLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }

  static bool _nextNonSpaceIsLowercase(String text, int index) {
    for (var j = index + 1; j < text.length; j++) {
      final ch = text[j];
      if (ch == ' ' || ch == '\t') continue;
      // Skip over consecutive terminal punctuation so an ellipsis (`...`)
      // or a `?!` cluster is treated as one boundary — we want to know
      // what comes AFTER the whole run, not call the next dot a boundary.
      if (_isTerminalChar(ch)) continue;
      if (ch == '\n' || ch == '\r') return false;
      final code = ch.codeUnitAt(0);
      return code >= 0x61 && code <= 0x7A;
    }
    return false;
  }

  /// After a terminal at [index], extend forward over trailing closers
  /// (quotes, asterisks) so `she said."` cuts after the quote, not the dot.
  static int _extendOverClosers(String text, int index) {
    var i = index;
    while (i + 1 < text.length && _isCloserChar(text[i + 1])) {
      i++;
    }
    return i;
  }

  static bool _isCloserChar(String ch) =>
      ch == '"' ||
      ch == '”' ||
      ch == '’' ||
      ch == "'" ||
      ch == '*' ||
      ch == '~';

  /// Iteratively strips trailing paragraphs until the tail ends cleanly or
  /// there are no more newlines.
  static String _trimTrailingParagraphsLoop(String text) {
    var current = text;
    while (current.isNotEmpty && !_trailingTerminalRE.hasMatch(current)) {
      final lastNewline = current.lastIndexOf(_newlineRE);
      if (lastNewline == -1) return text;
      final next = current.substring(0, lastNewline).trimRight();
      if (next == current || next.isEmpty) return text;
      current = next;
    }
    return current;
  }

  static bool _passesThreshold(String original, String trimmed) {
    if (trimmed.isEmpty) return false;
    if (trimmed.length >= _minKeepChars) return true;
    return trimmed.length >= (original.length * _minKeepRatio);
  }
}
