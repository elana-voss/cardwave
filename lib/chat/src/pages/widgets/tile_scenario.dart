import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class TileScenario extends StatelessWidget {
  const TileScenario({
    required this.chatSession,
    required this.onChanged,
    super.key,
  });
  final ChatSession? chatSession;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DrawerSwitchTile(
      title: Text(t.chat.tileScenario.label),
      value: chatSession?.isScenario ?? false,
      leading: const Icon(Icons.people),
      onChanged: chatSession == null ? null : onChanged,
    );
  }
}
