import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/widget/span_node.dart';

// Highly optimized regex to check if a block consists ONLY of standalone actions and whitespace
final _standaloneActionsRegex = RegExp(
  r'^(?:\s*(?:(?<!\*)\*[^\*]+\*(?!\*)|(?<!_)_[^_]+_(?!_))\s*)+$',
);

class QuoteNode extends ElementNode {
  QuoteNode(this.quoteStyle);
  final TextStyle quoteStyle;

  @override
  TextStyle get style => parentStyle?.merge(quoteStyle) ?? quoteStyle;

  @override
  InlineSpan build() {
    return TextSpan(
      style: style,
      children: [for (final e in children) e.build()],
    );
  }
}

class ActionNode extends ElementNode {
  ActionNode(
    this.defaultTextColor,
    this.asteriskColor, {
    this.isStandalone = false,
  });
  final Color? defaultTextColor;
  final Color asteriskColor;
  final bool isStandalone;

  @override
  TextStyle get style {
    final isNested =
        parentStyle != null && parentStyle!.color != defaultTextColor;

    if (isNested) {
      // It's inside quotes (or something with a different color). Inherit it.
      const italicStyle = TextStyle(fontStyle: FontStyle.italic);
      return parentStyle?.merge(italicStyle) ?? italicStyle;
    } else if (isStandalone) {
      // Standalone action in plain text.
      final customStyle = TextStyle(
        fontStyle: FontStyle.italic,
        color: asteriskColor,
      );
      return parentStyle?.merge(customStyle) ?? customStyle;
    } else {
      // Embedded in plain text. Inherit plain text color.
      const italicStyle = TextStyle(fontStyle: FontStyle.italic);
      return parentStyle?.merge(italicStyle) ?? italicStyle;
    }
  }

  @override
  InlineSpan build() {
    return TextSpan(
      style: style,
      children: [for (final e in children) e.build()],
    );
  }
}

// 2. ONLY the Quote Parser (Keeps quotation marks)
class QuotedTextSyntax extends md.InlineSyntax {
  // Matches standard straight quotes (") and typographical smart quotes (“ ”)
  QuotedTextSyntax() : super('["“”]([^"“”]+)["“”]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final innerText = match[1]!;
    final fullMatch = match.group(0)!;

    // Extract the exact quotes used so we don't accidentally replace
    // smart quotes with straight quotes in the final render.
    final startQuote = fullMatch.substring(0, 1);
    final endQuote = fullMatch.substring(fullMatch.length - 1);

    final innerParser = md.InlineParser(innerText, parser.document);

    final element = md.Element('quoted', [
      md.Text(startQuote),
      ...innerParser.parse(),
      md.Text(endQuote),
    ]);

    parser.addNode(element);
    return true;
  }
}

// 4. ONLY the Underscore Parser (Keeps underscores)
class UnderscoreTextSyntax extends md.InlineSyntax {
  // Uses lookbehind and lookahead to ensure it strictly matches exactly 1 underscore
  UnderscoreTextSyntax() : super(_pattern);
  static const _pattern = '(?<!_)_([^_]+)_(?!_)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final innerText = match[1]!;
    final innerParser = md.InlineParser(innerText, parser.document);

    final isStandalone = _standaloneActionsRegex.hasMatch(parser.source);

    final element = md.Element(
      isStandalone ? 'action_standalone' : 'action_embedded',
      [...innerParser.parse()],
    );

    parser.addNode(element);
    return true;
  }
}

// 3. ONLY the Asterisk Parser (Keeps asterisks)
class AsteriskTextSyntax extends md.InlineSyntax {
  // Uses lookbehind and lookahead to ensure it strictly matches exactly 1 asterisk
  AsteriskTextSyntax() : super(_pattern);
  static const _pattern = r'(?<!\*)\*([^\*]+)\*(?!\*)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final innerText = match[1]!;
    final innerParser = md.InlineParser(innerText, parser.document);

    final isStandalone = _standaloneActionsRegex.hasMatch(parser.source);

    final element = md.Element(
      isStandalone ? 'action_standalone' : 'action_embedded',
      [...innerParser.parse()],
    );

    parser.addNode(element);
    return true;
  }
}
