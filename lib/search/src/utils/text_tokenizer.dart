/// Splits text into lowercase tokens for keyword search. Drops single-letter
/// noise. ASCII fast-path (a–z, A–Z, 0–9) walks `codeUnits` directly; if a
/// non-ASCII code unit appears, we fall back to the unicode-regex split so
/// CJK / accented Latin / etc. tokenize the same way the dense embedder
/// sees them. The fast-path is ~2-3× faster than the regex on English text,
/// which dominates the card pool.
class TextTokenizer {
  const TextTokenizer._();

  static final RegExp _unicodeSplitter = RegExp(
    r'[^\p{L}\p{N}]+',
    unicode: true,
  );

  static List<String> tokenize(String text) {
    if (text.isEmpty) return const [];

    if (_isAscii(text)) {
      return _tokenizeAscii(text);
    }

    return text
        .toLowerCase()
        .split(_unicodeSplitter)
        .where((t) => t.length > 1)
        .toList();
  }

  static bool _isAscii(String text) {
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) >= 0x80) return false;
    }
    return true;
  }

  static List<String> _tokenizeAscii(String text) {
    final out = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      final isLower = unit >= 0x61 && unit <= 0x7A;
      final isUpper = unit >= 0x41 && unit <= 0x5A;
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (isLower || isDigit) {
        buf.writeCharCode(unit);
      } else if (isUpper) {
        buf.writeCharCode(unit + 0x20);
      } else if (buf.isNotEmpty) {
        if (buf.length > 1) out.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.length > 1) out.add(buf.toString());
    return out;
  }
}
