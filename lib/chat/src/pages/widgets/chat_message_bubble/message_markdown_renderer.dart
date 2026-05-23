import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/markdown_cache_manager.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/markdown_helper_classes.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_string_processor.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class MessageMarkdownRenderer extends StatelessWidget {
  const MessageMarkdownRenderer({
    required this.content,
    required this.messageStyle,
    required this.theme,
    super.key,
    this.contentNotifier,
  });
  static final _quotedSyntax = QuotedTextSyntax();
  static final _asteriskSyntax = AsteriskTextSyntax();
  static final _underscoreSyntax = UnderscoreTextSyntax();

  final String content;
  final ValueNotifier<String>? contentNotifier;
  final TextStyle messageStyle;
  final ChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final underlineColor = theme.resolveUnderlineColor();
    final quoteColor = theme.resolveQuoteColor();
    final asteriskColor = theme.resolveAsteriskColor();
    final shadowColor = theme.resolveTextShadowColor();

    final cacheKey = MarkdownCacheKey(
      textColor: messageStyle.color,
      underlineColor: underlineColor,
      quoteColor: quoteColor,
      asteriskColor: asteriskColor,
      surfaceColor: surfaceColor,
      shadowColor: shadowColor,
    );

    var cacheValue = lookupMarkdownCache(cacheKey);
    if (cacheValue == null) {
      final quoteStyle = messageStyle.copyWith(color: quoteColor);

      final markdownConfig = MarkdownConfig(
        configs: [
          PConfig(textStyle: messageStyle),
          LinkConfig(
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: underlineColor,
              color: underlineColor,
            ),
          ),
          BlockquoteConfig(textColor: quoteColor),
          PreConfig(
            textStyle: const TextStyle(fontFamily: 'monospace'),
            wrapper: (child, code, language) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Text(
                code,
                style: messageStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: messageStyle.fontSize != null
                      ? messageStyle.fontSize! - 1
                      : 13,
                ),
              ),
            ),
          ),
          CodeConfig(
            style: TextStyle(
              backgroundColor: surfaceColor,
              fontFamily: 'monospace',
            ),
          ),
          H1Config(
            style: messageStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          H2Config(
            style: messageStyle.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          H3Config(
            style: messageStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          H4Config(
            style: messageStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          H5Config(
            style: messageStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          H6Config(
            style: messageStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

      final markdownGenerator = MarkdownGenerator(
        inlineSyntaxList: [_quotedSyntax, _asteriskSyntax, _underscoreSyntax],
        generators: [
          SpanNodeGeneratorWithTag(
            tag: 'quoted',
            generator: (e, config, visitor) => QuoteNode(quoteStyle),
          ),
          SpanNodeGeneratorWithTag(
            tag: 'action_standalone',
            generator: (e, config, visitor) => ActionNode(
              messageStyle.color,
              asteriskColor,
              isStandalone: true,
            ),
          ),
          SpanNodeGeneratorWithTag(
            tag: 'action_embedded',
            generator: (e, config, visitor) => ActionNode(
              messageStyle.color,
              asteriskColor,
            ),
          ),
        ],
      );

      cacheValue = MarkdownCacheValue(markdownConfig, markdownGenerator);
      putMarkdownCache(cacheKey, cacheValue);
    }

    if (contentNotifier != null) {
      return ValueListenableBuilder<String>(
        valueListenable: contentNotifier!,
        builder: (context, val, _) {
          if (val.isEmpty) return const SizedBox.shrink();
          // `cacheValue` is non-null here (assigned just above if the cache
          // missed); it's only nullable again *inside* this closure because
          // it's a mutable capture, hence the local unwrap.
          final cv = cacheValue!;
          return MarkdownBlock(
            data: MessageStringProcessor.processContent(val),
            config: cv.config,
            generator: cv.generator,
          );
        },
      );
    }

    return MarkdownBlock(
      data: MessageStringProcessor.processContent(content),
      config: cacheValue.config,
      generator: cacheValue.generator,
    );
  }
}
