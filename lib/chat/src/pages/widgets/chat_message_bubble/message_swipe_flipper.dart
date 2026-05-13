import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:flutter/material.dart';

class MessageSwipeFlipper extends StatelessWidget {
  const MessageSwipeFlipper({
    required this.message,
    required this.isGenerating,
    required this.isFirstMessage,
    required this.isLastMessage,
    required this.onRegenerate,
    required this.onSwipeChanged,
    required this.metaStyle,
    super.key,
  });
  final ChatMessage message;
  final bool isGenerating;
  final bool isFirstMessage;
  final bool isLastMessage;
  final VoidCallback? onRegenerate;
  final VoidCallback onSwipeChanged;
  final TextStyle metaStyle;

  @override
  Widget build(BuildContext context) {
    final canCycleRight = isFirstMessage && message.swipes.length > 1;
    final canCycleLeft = message.swipes.length > 1;
    final canSwipeLeft = isLastMessage && !isGenerating && canCycleLeft;
    final canSwipeRight =
        isLastMessage &&
        !isGenerating &&
        (message.swipeIndex < message.swipes.length - 1 || canCycleRight);
    final hasRegenerateCapability =
        onRegenerate != null && message.swipeIndex == message.swipes.length - 1;
    final canRegenerate =
        isLastMessage && !isGenerating && hasRegenerateCapability;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          iconSize: 24,
          color: metaStyle.color,
          disabledColor: metaStyle.color?.withValues(alpha: 0.3),
          tooltip: 'Previous version',
          icon: const Icon(Icons.chevron_left),
          onPressed: canSwipeLeft
              ? () {
                  if (canCycleLeft && message.swipeIndex == 0) {
                    message.swipeIndex = message.swipes.length - 1;
                  } else {
                    message.previousSwipe();
                  }
                  onSwipeChanged();
                }
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          '${message.swipeIndex + 1} / ${message.swipes.length}',
          style: metaStyle,
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('msg-swipe-next'),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          iconSize: 24,
          color: metaStyle.color,
          disabledColor: metaStyle.color?.withValues(alpha: 0.3),
          tooltip: canRegenerate ? 'Regenerate' : 'Next version',
          icon: const Icon(Icons.chevron_right),
          onPressed: canSwipeRight
              ? () {
                  if (canCycleRight &&
                      message.swipeIndex == message.swipes.length - 1) {
                    message.swipeIndex = 0;
                  } else {
                    message.nextSwipe();
                  }
                  onSwipeChanged();
                }
              : (canRegenerate ? onRegenerate : null),
        ),
      ],
    );
  }
}
