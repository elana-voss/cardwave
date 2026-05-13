import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class MessageSwipeDetector extends StatelessWidget {
  const MessageSwipeDetector({
    required this.child,
    required this.message,
    required this.isGenerating,
    required this.isLastMessage,
    required this.isFirstMessage,
    required this.onSwipeChanged,
    super.key,
    this.onRegenerate,
  });
  final Widget child;
  final ChatMessage message;
  final bool isGenerating;
  final bool isLastMessage;
  final bool isFirstMessage;
  final VoidCallback onSwipeChanged;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if (isGenerating || !isLastMessage) return;

        final velocity = details.primaryVelocity ?? 0;
        if (velocity > AppConstants.chatSwipeVelocityThreshold &&
            message.swipes.length > 1) {
          if (message.swipeIndex == 0) {
            message.swipeIndex = message.swipes.length - 1;
          } else {
            message.previousSwipe();
          }
          onSwipeChanged();
        } else if (velocity < -AppConstants.chatSwipeVelocityThreshold) {
          final canCycleRight = isFirstMessage && message.swipes.length > 1;
          if (message.swipeIndex < message.swipes.length - 1 || canCycleRight) {
            if (canCycleRight &&
                message.swipeIndex == message.swipes.length - 1) {
              message.swipeIndex = 0;
            } else {
              message.nextSwipe();
            }
            onSwipeChanged();
          } else if (onRegenerate != null &&
              message.swipeIndex == message.swipes.length - 1) {
            onRegenerate!();
          }
        }
      },
      child: child,
    );
  }
}
