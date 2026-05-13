import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:flutter/material.dart';

class SystemMessageBubble extends StatelessWidget {
  const SystemMessageBubble({required this.message, super.key});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          message.content,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
