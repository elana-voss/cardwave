/// Trims incomplete trailing content from LLM replies that got cut off
/// mid-sentence or mid-paragraph.
///
/// Strategy: block-level repairs first (close an unterminated code fence, drop
/// a bare trailing list marker), then a sentence-level trim, then a
/// paragraph-level fallback, with a "don't nuke short messages" safety net — if
/// a sentence/paragraph trim would remove too much of the original, the
/// original is returned unchanged.
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

  /// A trailing line that is only a list marker (bullet `-`/`*`/`+` or an
  /// ordered `N.`/`N)`) and whitespace — the model opened a new list item and
  /// got cut before writing it. The leading newline is part of the match so
  /// the empty line is removed whole.
  static final RegExp _trailingEmptyListMarkerRE =
      RegExp(r'\n[ \t]*(?:[-*+]|\d+[.)])[ \t]*$');

  /// A code-fence line: three or more backticks at the start of a line (after
  /// up to three leading spaces, per CommonMark). Counted to tell whether the
  /// reply ended inside an open code block.
  static final RegExp _codeFenceRE = RegExp(r'^ {0,3}`{3,}', multiLine: true);

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

  /// Symmetric delimiters — the same character opens and closes, so each
  /// occurrence is classified open/close by position, never by raw count (an
  /// even count of `"` hides two unclosed openers or a stray literal quote).
  /// Straight quote and roleplay action asterisk. Single quotes and tildes are
  /// left out on purpose: apostrophes make `'` ambiguous, and a lone trailing
  /// `~` is a common flourish, not an opener.
  static const List<String> _symmetricDelimiters = ['"', '*'];

  /// Directional delimiter pairs — opener maps to a distinct closer, so they
  /// nest on a stack. Curly quote plus the bracketing pairs that wrap an aside.
  static const Map<String, String> _directionalDelimiters = {
    '“': '”',
    '(': ')',
    '[': ']',
    '{': '}',
  };

  /// [_directionalDelimiters] inverted — closer back to its opener.
  static final Map<String, String> _closerToOpener = {
    for (final e in _directionalDelimiters.entries) e.value: e.key,
  };

  /// Whether a delimiter at [i] sits in an opening position: the start of the
  /// text or just after whitespace. That is how an aside or a line of dialogue
  /// opens (`... (she thinks`, `... "hello`), and it keeps emoticons (`:(`) and
  /// call syntax (`f(x`) from reading as an unclosed opener.
  static bool _isOpeningContext(String text, int i) =>
      i == 0 || _isSpaceChar(text[i - 1]);

  /// The list index of the most recent still-open delimiter whose closer is
  /// [closer], or -1 when none is open. Symmetric and directional closers never
  /// collide (`"`/`*` vs `”`/`)`/`]`/`}`), so a match by closer char is exact.
  static int _lastOpenMatching(List<_OpenDelim> open, String closer) {
    for (var i = open.length - 1; i >= 0; i--) {
      if (open[i].closer == closer) return i;
    }
    return -1;
  }

  /// Every delimiter left open at the end of [text], in the order it opened.
  ///
  /// A straight quote and an action asterisk are the SAME character open and
  /// closed, so counting occurrences cannot tell balance from imbalance — an
  /// even count hides two unclosed openers (`"one. "two`) or a stray literal
  /// quote (`the 6" pipe. "hi`). Each occurrence is classified by position
  /// instead: one in an opening context opens a run; otherwise it closes the
  /// matching open run, or — with nothing open to close — is itself an opener
  /// (a lone `."` gluing new dialogue onto a period). Directional pairs nest on
  /// the same list, their opener counted only in an opening context.
  static List<_OpenDelim> _openDelimiters(String text) {
    final open = <_OpenDelim>[];
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_symmetricDelimiters.contains(ch)) {
        if (_isOpeningContext(text, i)) {
          open.add(_OpenDelim(i, ch, symmetric: true));
        } else {
          final match = _lastOpenMatching(open, ch);
          if (match != -1) {
            open.removeAt(match);
          } else {
            open.add(_OpenDelim(i, ch, symmetric: true));
          }
        }
      } else if (_directionalDelimiters.containsKey(ch)) {
        if (_isOpeningContext(text, i)) {
          open.add(
            _OpenDelim(i, _directionalDelimiters[ch]!, symmetric: false),
          );
        }
      } else if (_closerToOpener.containsKey(ch)) {
        final match = _lastOpenMatching(open, ch);
        if (match != -1) open.removeAt(match);
      }
    }
    return open;
  }

  /// Index of the earliest unmatched opening delimiter — a quote, an action
  /// asterisk, or a bracketing pair left open — or -1 when every delimiter is
  /// balanced.
  static int _danglingDelimiterStart(String text) {
    final open = _openDelimiters(text);
    if (open.isEmpty) return -1;
    var earliest = open.first.index;
    for (final d in open) {
      if (d.index < earliest) earliest = d.index;
    }
    return earliest;
  }

  /// Whether [text] closes on something legitimate — sentence punctuation, a
  /// roleplay closer, or an emoji — with no quote, action asterisk, or
  /// bracketing pair left dangling open. A reply cut right after an opening `"`
  /// or `*` ends on a closer char and would pass the char-class check alone;
  /// the balance check is what catches it. The single definition of "ends
  /// cleanly": the fast path and the paragraph loop must agree on it, or one of
  /// them trims a close the other accepts.
  static bool _endsCleanly(String text) =>
      _openDelimiters(text).isEmpty &&
      (_trailingTerminalRE.hasMatch(text) || _trailingEmojiRE.hasMatch(text));

  /// The closer strings that balance [prefix], innermost-first (so they append
  /// in nesting order), or null when a non-nesting delimiter — a straight quote
  /// or an action asterisk — is left open more than once. Two of the same such
  /// delimiter open means two separate unfinished runs; appending closers would
  /// still leave the first one open, so the caller must cut back to an earlier
  /// boundary instead of closing here.
  static List<String>? _danglingClosers(String prefix) {
    final open = _openDelimiters(prefix);
    final symmetricOpenCounts = <String, int>{};
    for (final d in open) {
      if (d.symmetric) {
        symmetricOpenCounts[d.closer] = (symmetricOpenCounts[d.closer] ?? 0) + 1;
      }
    }
    if (symmetricOpenCounts.values.any((count) => count > 1)) return null;
    return [for (final d in open.reversed) d.closer];
  }

  /// Returns [text] with any incomplete trailing sentence/paragraph removed.
  /// Never returns an empty string; if the result would be empty or fall
  /// below the safety threshold, returns [text] unchanged.
  static String trim(String text) {
    if (text.isEmpty) return text;

    // Block-level repairs first — a bare trailing list marker or an
    // unterminated code fence is structural, not a sentence to trim. Each only
    // removes a marker line or appends a closing fence, so neither can nuke
    // content; when one fires the reply is repaired and we are done.
    final blockRepaired =
        _closeUnterminatedCodeFence(_dropTrailingEmptyListMarker(text));
    if (blockRepaired != text) return blockRepaired;

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

  /// Drops a bare trailing list marker (`...\n- `) the model opened but never
  /// filled. Returns [text] unchanged when the marker is the whole reply
  /// (nothing would be left) or there is no such marker.
  static String _dropTrailingEmptyListMarker(String text) {
    final match = _trailingEmptyListMarkerRE.firstMatch(text);
    if (match == null || match.start == 0) return text;
    return text.substring(0, match.start).trimRight();
  }

  /// Closes an unterminated markdown code fence. An odd number of fence lines
  /// means the reply was cut inside a code block; append a closing fence on its
  /// own line so the block is valid instead of swallowing the rest of the chat.
  static String _closeUnterminatedCodeFence(String text) {
    final fences = _codeFenceRE.allMatches(text).length;
    if (fences == 0 || fences.isEven) return text;
    return text.endsWith('\n') ? '$text```' : '$text\n```';
  }

  /// Scans backwards for the last valid sentence end — punctuation, or an
  /// emoji that closes a sentence — and returns the substring up to and
  /// including it. A boundary inside an unterminated quotation or action gets
  /// the closing delimiter appended, so a cut-off dialogue line ends properly
  /// instead of dangling open. Returns null if no valid boundary is found.
  static String? _trimToLastSentenceEnd(String text) {
    final dangling = _danglingDelimiterStart(text);
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
      final prefix = text.substring(0, cut + 1);
      // A cut that would leave a non-nesting delimiter open twice cannot be
      // repaired by appending — the earlier run would stay open — so move to an
      // earlier boundary, which drops the second unfinished run.
      final closers = _danglingClosers(prefix);
      if (closers == null) continue;
      final result = prefix.trimRight() + closers.join();
      if (result.isEmpty) continue;
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
  /// (quotes, asterisks, brackets) so `she said."` cuts after the quote, not
  /// the dot. Never extends to or past [limit] — the start of a dangling open
  /// delimiter, which is an opener, not a close to keep.
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
      ch == '~' ||
      ch == ')' ||
      ch == ']' ||
      ch == '}';

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

/// One still-open delimiter found by `UtilsAppTextTrim._openDelimiters`: the
/// index it opened at, the string that closes it, and whether it is symmetric
/// (same character opens and closes, so it cannot nest — a straight quote or an
/// action asterisk).
class _OpenDelim {
  const _OpenDelim(this.index, this.closer, {required this.symmetric});
  final int index;
  final String closer;
  final bool symmetric;
}
