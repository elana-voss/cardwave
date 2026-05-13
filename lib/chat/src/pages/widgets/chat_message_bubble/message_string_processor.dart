import 'package:cardwave_llm/cardwave_llm.dart';

class MessageStringProcessor {
  static final _htmlCommentRegex = RegExp(r'<!--.*?-->\n?', dotAll: true);
  static final _indentationRegex = RegExp(r'^[ \t]|\n[ \t]');

  static String processContent(String text) {
    if (text.isEmpty) return text;

    // Raw content is kept on ChatMessage so the bubble reveal still works.
    text = UtilsLlm.stripThinkTags(text);
    if (text.isEmpty) return text;

    if (text.contains('<!--')) {
      text = text.replaceAll(_htmlCommentRegex, '');
    }

    if (!_indentationRegex.hasMatch(text)) {
      return text;
    }

    final buffer = StringBuffer();
    var inCodeBlock = false;
    var start = 0;
    final length = text.length;

    while (start < length) {
      var end = text.indexOf('\n', start);
      if (end == -1) end = length;

      final line = text.substring(start, end);
      final trimmed = line.trimLeft();

      if (trimmed.startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        buffer.write(line);
      } else {
        buffer.write(inCodeBlock ? line : trimmed);
      }

      if (end < length) buffer.write('\n');
      start = end + 1;
    }

    return buffer.toString();
  }
}
