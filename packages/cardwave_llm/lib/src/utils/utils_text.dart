/// Mirrors `UtilsApp.cleanForTts` so the LLM domain has no app-side dependency.
class UtilsText {
  static final _emojis = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
    unicode: true,
  );
  static final _multiSpace = RegExp(' {2,}');
  static final _lineTrim = RegExp(r'(^ +| +$)', multiLine: true);
  static final _multiNewline = RegExp(r'\n{3,}');
  static final _asterisks = RegExp(r'\*');

  /// Strips roleplay asterisks, emojis, and fancy Unicode typography
  /// (𝒉𝒆𝒍𝒍𝒐 → hello). Collapses runs of spaces but keeps paragraph
  /// breaks so the synth engine gets natural pauses.
  static String cleanForTts(String input) {
    if (input.isEmpty) return input;
    return _normalizeFancyChars(input)
        .replaceAll(_asterisks, ' ')
        .replaceAll(_emojis, ' ')
        .replaceAll(_multiSpace, ' ')
        .replaceAll(_lineTrim, '')
        .replaceAll(_multiNewline, '\n\n')
        .trim();
  }

  static String _normalizeFancyChars(String input) {
    if (input.isEmpty) return input;
    final sb = StringBuffer();
    // Common holes in the Mathematical Alphanumeric Symbols block
    // located in the Letterlike Symbols block (U+2100-U+214F).
    const replacements = {
      0x2102: 'C',
      0x210A: 'g',
      0x210B: 'H',
      0x210C: 'H',
      0x210D: 'H',
      0x210E: 'h',
      0x2110: 'I',
      0x2111: 'I',
      0x2112: 'L',
      0x2113: 'l',
      0x2115: 'N',
      0x2119: 'P',
      0x211A: 'Q',
      0x211B: 'R',
      0x211C: 'R',
      0x211D: 'R',
      0x2124: 'Z',
      0x2128: 'Z',
      0x212A: 'K',
      0x212B: 'A',
      0x212C: 'B',
      0x212D: 'C',
      0x212F: 'e',
      0x2130: 'E',
      0x2131: 'F',
      0x2133: 'M',
      0x2134: 'o',
      0x2139: 'i',
      0x2145: 'D',
      0x2146: 'd',
      0x2147: 'e',
      0x2148: 'i',
      0x2149: 'j',
    };

    for (final rune in input.runes) {
      if (rune >= 0x1D400 && rune <= 0x1D6A3) {
        final val = (rune - 0x1D400) % 52;
        sb.writeCharCode(val < 26 ? 0x41 + val : 0x61 + (val - 26));
      } else if (rune >= 0x1D7CE && rune <= 0x1D7FF) {
        sb.writeCharCode(0x30 + (rune - 0x1D7CE) % 10);
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        sb.writeCharCode(rune - 0xFEE0);
      } else if (rune >= 0x24B6 && rune <= 0x24CF) {
        sb.writeCharCode(0x41 + (rune - 0x24B6));
      } else if (rune >= 0x24D0 && rune <= 0x24E9) {
        sb.writeCharCode(0x61 + (rune - 0x24D0));
      } else if (rune >= 0x1F130 && rune <= 0x1F149) {
        sb.writeCharCode(0x41 + (rune - 0x1F130));
      } else if (rune >= 0x1F150 && rune <= 0x1F169) {
        sb.writeCharCode(0x41 + (rune - 0x1F150));
      } else if (rune >= 0x1F170 && rune <= 0x1F189) {
        sb.writeCharCode(0x41 + (rune - 0x1F170));
      } else if (rune >= 0x1F1E6 && rune <= 0x1F1FF) {
        sb.writeCharCode(0x41 + (rune - 0x1F1E6));
      } else {
        final replacement = replacements[rune];
        if (replacement != null) {
          sb.write(replacement);
        } else {
          sb.writeCharCode(rune);
        }
      }
    }
    return sb.toString();
  }
}
