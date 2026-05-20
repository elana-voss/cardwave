import 'dart:math' as math;

import 'package:uuid/uuid.dart';

class UtilsApp {
  static final _htmlTags = RegExp('<[^>]*>');
  static final _mdImages = RegExp(r'!\[.*?\]\(.*?\)');
  static final _mdLinks = RegExp(r'\[(.*?)\]\(.*?\)');
  static final _mdFormatting = RegExp(r'[*_~`\[\]\{\}]');
  static final _mdHeaders = RegExp(r'^#+\s*', multiLine: true);
  static final _emojis = RegExp(
    r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
    unicode: true,
  );
  static final _whitespace = RegExp(r'\s+'); // flattens line breaks
  static final _multiSpace = RegExp(' {2,}');
  static final _lineTrim = RegExp(r'(^ +| +$)', multiLine: true);
  static final _multiNewline = RegExp(r'\n{3,}');
  static final _asterisks = RegExp(r'\*');
  static final _htmlBr = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final _htmlPEnds = RegExp('</p>', caseSensitive: false);
  static final _htmlBlockEnds = RegExp(
    '</div>|</h[1-6]>',
    caseSensitive: false,
  );
  static final _htmlLi = RegExp('<li>', caseSensitive: false);

  static final _markdownLinkAndImages = RegExp(
    r'!?\[[^\]]*\]\([^)]+\)',
    caseSensitive: false,
  );

  static final _invalidFileNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final _trailingDotsOrSpaces = RegExp(r'[. ]+$');

  /// Sanitizes a string for use as a file name on any platform.
  ///
  /// Strips characters disallowed on Windows (`<>:"/\|?*` plus control chars),
  /// trims trailing dots/spaces (also a Windows restriction), and falls back
  /// to [fallback] if the result is empty or a reserved Windows device name.
  static String sanitizeFileName(String input, {String fallback = 'Untitled'}) {
    final cleaned = input
        .replaceAll(_invalidFileNameChars, '_')
        .replaceAll(_trailingDotsOrSpaces, '')
        .trim();
    if (cleaned.isEmpty) return fallback;
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    if (reserved.contains(cleaned.toUpperCase())) return '_$cleaned';
    return cleaned;
  }

  static String timeAgo(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = DateTime.now().difference(date);

    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  static String cleanseAndInlineForPrompt(String input, {int? maxLength}) {
    final cleansed = normalizeFancyChars(input)
        .replaceAll(_htmlTags, ' ')
        .replaceAll(_markdownLinkAndImages, ' ')
        .replaceAll(_mdImages, ' ')
        .replaceAllMapped(_mdLinks, (m) => m[1] ?? ' ')
        .replaceAll(_mdFormatting, ' ')
        .replaceAll(_mdHeaders, ' ')
        .replaceAll(_emojis, ' ')
        .replaceAll(_asterisks, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();

    if (maxLength == null) {
      return cleansed;
    }

    return cleansed.substring(0, math.min(300, cleansed.length));
  }

  static String normalizeFancyChars(String input) {
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
      // Mathematical Alphanumeric Symbols (A-Z, a-z)
      if (rune >= 0x1D400 && rune <= 0x1D6A3) {
        final val = (rune - 0x1D400) % 52;
        sb.writeCharCode(val < 26 ? 0x41 + val : 0x61 + (val - 26));
      }
      // Mathematical Bold Digits (0-9)
      else if (rune >= 0x1D7CE && rune <= 0x1D7FF) {
        sb.writeCharCode(0x30 + (rune - 0x1D7CE) % 10);
      }
      // Fullwidth ASCII (U+FF01 - U+FF5E)
      else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        sb.writeCharCode(rune - 0xFEE0);
      }
      // Circled Latin Capital (A-Z)
      else if (rune >= 0x24B6 && rune <= 0x24CF) {
        sb.writeCharCode(0x41 + (rune - 0x24B6));
      }
      // Circled Latin Small (a-z)
      else if (rune >= 0x24D0 && rune <= 0x24E9) {
        sb.writeCharCode(0x61 + (rune - 0x24D0));
      }
      // Squared Latin Capital (A-Z)
      else if (rune >= 0x1F130 && rune <= 0x1F149) {
        sb.writeCharCode(0x41 + (rune - 0x1F130));
      }
      // Negative Squared Latin Capital (A-Z)
      else if (rune >= 0x1F150 && rune <= 0x1F169) {
        sb.writeCharCode(0x41 + (rune - 0x1F150));
      }
      // Negative Circled Latin Capital (A-Z)
      else if (rune >= 0x1F170 && rune <= 0x1F189) {
        sb.writeCharCode(0x41 + (rune - 0x1F170));
      }
      // Regional Indicator Symbols (A-Z)
      else if (rune >= 0x1F1E6 && rune <= 0x1F1FF) {
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

  /// Cleans LLM output for TTS synthesis.
  ///
  /// Strips roleplay asterisks, emojis, and fancy Unicode typography
  /// (𝒉𝒆𝒍𝒍𝒐 → hello). Collapses runs of spaces but keeps paragraph
  /// breaks so the synth engine gets natural pauses.
  static String cleanForTts(String input) {
    if (input.isEmpty) return input;
    return normalizeFancyChars(input)
        .replaceAll(_asterisks, ' ')
        .replaceAll(_emojis, ' ')
        .replaceAll(_multiSpace, ' ')
        .replaceAll(_lineTrim, '')
        .replaceAll(_multiNewline, '\n\n')
        .trim();
  }

  static String purgeEmojis(String text) => text.replaceAll(_emojis, ' ');

  static String purgeHtml(String text) {
    var processed = text;
    processed = processed.replaceAll(_htmlBr, '\n');
    processed = processed.replaceAll(_htmlPEnds, '\n\n');
    processed = processed.replaceAll(_htmlBlockEnds, '\n');
    processed = processed.replaceAll(_htmlLi, '\n• ');
    processed = processed.replaceAll(_htmlTags, ' ');
    processed = processed.replaceAll(_multiNewline, '\n\n');
    return processed.trim();
  }

  static String purgeMarkdownLinksImages(String text) =>
      text.replaceAll(_markdownLinkAndImages, '\n').trim();

  static String purgeExtraSpaces(String text) => text
      .replaceAll(_multiSpace, ' ')
      .replaceAll(_lineTrim, '')
      .replaceAll(_multiNewline, '\n\n')
      .trim();

  static String generateId(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'profile';

    return '$slug-${const Uuid().v4()}';
  }
}
