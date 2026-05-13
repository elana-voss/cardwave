import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class TileNsfw extends StatelessWidget {
  const TileNsfw({
    required this.chatSession,
    required this.onChanged,
    super.key,
  });
  final ChatSession? chatSession;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DrawerSwitchTile(
      title: const Text('NSFW / Unlimited'),
      value: chatSession?.isNsfw ?? false,
      leading: const Icon(Icons.whatshot),
      onChanged: chatSession == null ? null : onChanged,
    );
  }
}
