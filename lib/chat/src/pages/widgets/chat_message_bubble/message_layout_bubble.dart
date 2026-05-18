import 'dart:ui';

import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';

class MessageLayoutBubble extends StatelessWidget {
  const MessageLayoutBubble({
    required this.isUser,
    required this.displayName,
    required this.displayNameStyle,
    required this.contentWidget,
    required this.actionsRow,
    required this.theme,
    super.key,
    this.flipper,
  });
  final bool isUser;
  final String displayName;
  final TextStyle displayNameStyle;
  final Widget contentWidget;
  final Widget actionsRow;
  final Widget? flipper;
  final ChatTheme theme;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isUser
        ? theme.resolveUserBackgroundColor()
        : theme.resolveAssistantBackgroundColor();

    final borderColor = theme.borderColor != 0
        ? theme.resolveBorderColor()
        : null;

    Widget bubble = Container(
      constraints: const BoxConstraints(maxWidth: 800),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: theme.shadowColor != 0 && theme.shadowWidth > 0
            ? [
                BoxShadow(
                  color: theme.resolveShadowColor(),
                  blurRadius: theme.shadowWidth,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: displayNameStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              actionsRow,
            ],
          ),
          contentWidget,
          if (flipper != null)
            Align(alignment: Alignment.centerRight, child: flipper),
        ],
      ),
    );

    if (theme.blurTintColor != 0 && theme.blurStrength > 0) {
      bubble = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: theme.blurStrength,
            sigmaY: theme.blurStrength,
          ),
          child: ColoredBox(color: theme.resolveBlurTintColor(), child: bubble),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: bubble,
      ),
    );
  }
}
