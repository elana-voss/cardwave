/// Trims incomplete trailing content from LLM replies that got cut off
/// mid-sentence or mid-paragraph.
///
/// Strategy: sentence-level trim first, paragraph-level fallback, with a
/// "don't nuke short messages" safety net — if either strategy would remove
/// too much of the original, the original is returned unchanged.
///
/// Kept in lockstep with circe's `trimIncompleteTrailing`
/// (`companion_helper`, `text_trim.dart`).
class UtilsAppTextTrim {
  /// Minimum fraction of the original length the trimmed result must retain.
  static const double _minKeepRatio = 0.4;

  /// Absolute minimum character count the trimmed result must retain.
  /// The threshold passes if the result meets EITHER the ratio OR the floor.
  static const int _minKeepChars = 120;

  /// Characters that can legitimately close a sentence. Includes roleplay
  /// dialogue/action closers (quotes, asterisks, tildes).
  static final RegExp _trailingTerminalRE = RegExp(r'''[.!?…*"”~’']\s*$''');

  /// Pictographic characters (emoji), plus the variation selector, ZWJ, and
  /// skin-tone modifiers that compose them — a reply ending in any of these
  /// ended on an emoji, which is a legitimate close.
  static final RegExp _trailingEmojiRE = RegExp(
    r'[\p{Extended_Pictographic}\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}]\s*$',
    unicode: true,
  );

  /// A run of emoji code points — matched as a whole so surrogate pairs, ZWJ
  /// sequences and skin-tone modifiers advance as one unit.
  static final RegExp _emojiRunRE = RegExp(
    r'(?:[\p{Extended_Pictographic}\u{FE0F}\u{200D}\u{1F3FB}-\u{1F3FF}])+',
    unicode: true,
  );

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

  /// Whether [text] closes on something legitimate — sentence punctuation, a
  /// roleplay closer, or an emoji — with no double quote left dangling open.
  /// A reply cut right after an opening `"` ends on a quote char and would
  /// pass the char-class check alone; the balance check is what catches it.
  /// The single definition of "ends cleanly": the fast path and the paragraph
  /// loop must agree on it, or one of them trims a close the other accepts.
  static bool _endsCleanly(String text) =>
      _danglingQuoteStart(text) == -1 &&
      (_trailingTerminalRE.hasMatch(text) || _trailingEmojiRE.hasMatch(text));

  /// Index of the earliest unmatched opening double quote — where an
  /// unterminated quotation begins — or -1 when all double quotes are
  /// balanced. Straight quotes alternate open/close; curly quotes are matched
  /// by kind. Single quotes are ignored: apostrophes make their parity
  /// meaningless.
  static int _danglingQuoteStart(String text) {
    var straightOpen = -1;
    final curlyOpens = <int>[];
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '"') {
        straightOpen = straightOpen == -1 ? i : -1;
      } else if (ch == '“') {
        curlyOpens.add(i);
      } else if (ch == '”' && curlyOpens.isNotEmpty) {
        curlyOpens.removeLast();
      }
    }
    final curlyOpen = curlyOpens.isEmpty ? -1 : curlyOpens.first;
    if (straightOpen == -1) return curlyOpen;
    if (curlyOpen == -1) return straightOpen;
    return straightOpen < curlyOpen ? straightOpen : curlyOpen;
  }

  /// The closing counterpart of an opening double quote.
  static String _closerFor(String opener) => opener == '“' ? '”' : opener;

  /// Returns [text] with any incomplete trailing sentence/paragraph removed.
  /// Never returns an empty string; if the result would be empty or fall
  /// below the safety threshold, returns [text] unchanged.
  static String trim(String text) {
    if (text.isEmpty) return text;

    // Fast path — already ends cleanly, nothing to do.
    if (_endsCleanly(text)) return text;

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

  /// Scans backwards for the last valid sentence end — punctuation, or an
  /// emoji that closes a sentence — and returns the substring up to and
  /// including it. A boundary inside an unterminated quotation gets the
  /// closing quote appended, so a cut-off dialogue line ends properly instead
  /// of dangling open. Returns null if no valid boundary is found.
  static String? _trimToLastSentenceEnd(String text) {
    final dangling = _danglingQuoteStart(text);
    final closerLimit = dangling == -1 ? text.length : dangling;
    final emojiEnds = _sentenceFinalEmojiEnds(text);
    for (var i = text.length - 1; i >= 0; i--) {
      final int cut;
      if (emojiEnds.contains(i)) {
        cut = i;
      } else {
        final ch = text[i];
        if (!_isTerminalChar(ch)) continue;
        if (!_isValidBoundary(text, i)) continue;
        cut = _extendOverClosers(text, i, closerLimit);
      }
      final result = text.substring(0, cut + 1).trimRight();
      if (result.isEmpty) return null;
      if (dangling != -1 && cut > dangling) {
        return result + _closerFor(text[dangling]);
      }
      return result;
    }
    return null;
  }

  /// The last code unit of every emoji run that closes a sentence — a run
  /// followed by whitespace or the end of the text. An emoji glued to the
  /// next word (`hi 😊there`) is mid-sentence decoration, not a boundary.
  /// Collected as whole-run matches because a backwards per-code-unit scan
  /// would only ever see half of a surrogate pair, which matches no emoji
  /// property.
  static Set<int> _sentenceFinalEmojiEnds(String text) => {
        for (final m in _emojiRunRE.allMatches(text))
          if (m.end == text.length || _isSpaceChar(text[m.end])) m.end - 1,
      };

  static bool _isSpaceChar(String ch) =>
      ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';

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
  /// Never extends to or past [limit] — the start of a dangling open quote,
  /// which is an opener, not a close to keep.
  static int _extendOverClosers(String text, int index, int limit) {
    var i = index;
    while (i + 1 < limit && _isCloserChar(text[i + 1])) {
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
    while (current.isNotEmpty && !_endsCleanly(current)) {
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
