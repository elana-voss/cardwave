import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
      title: Text(t.chat.tileNsfw.label),
      value: chatSession?.isNsfw ?? false,
      leading: const Icon(Icons.whatshot),
      onChanged: chatSession == null ? null : onChanged,
    );
  }
}
