import 'package:flutter/material.dart';

class JsonPromptViewer extends StatelessWidget {
  const JsonPromptViewer({required this.jsonContent, super.key});
  static final _jsonRegex = RegExp(
    r'(?<key>"(?:[^"\\]|\\.)*")\s*:|(?<string>"(?:[^"\\]|\\.)*")|(?<number>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<keyword>true|false|null)|(?<punct>[{}\[\],:])',
  );

  final String jsonContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];

    var lastIndex = 0;
    for (final match in _jsonRegex.allMatches(jsonContent)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(text: jsonContent.substring(lastIndex, match.start)),
        );
      }

      TextStyle? style;
      if (match.namedGroup('key') != null) {
        style = TextStyle(color: scheme.primary);
      } else if (match.namedGroup('string') != null) {
        style = TextStyle(color: scheme.tertiary);
      } else if (match.namedGroup('number') != null) {
        style = TextStyle(color: scheme.secondary);
      } else if (match.namedGroup('keyword') != null) {
        style = TextStyle(color: scheme.error);
      } else {
        style = TextStyle(color: scheme.onSurface);
      }

      spans.add(TextSpan(text: match.group(0), style: style));
      lastIndex = match.end;
    }

    if (lastIndex < jsonContent.length) {
      spans.add(TextSpan(text: jsonContent.substring(lastIndex)));
    }

    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(
        TextSpan(children: spans),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
