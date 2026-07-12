import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class TileTrailingParagraph extends StatelessWidget {
  const TileTrailingParagraph({
    required this.chatSession,
    required this.onChanged,
    super.key,
  });
  final ChatSession? chatSession;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return DrawerSwitchTile(
      title: Text(t.chat.tileTrailingParagraph.label),
      value: chatSession?.removeTrailingSentences ?? false,
      leading: const Icon(Icons.content_cut),
      onChanged: chatSession == null ? null : onChanged,
    );
  }
}
