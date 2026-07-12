import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _ChatListItemActionEnum { rename, delete }

class ChatListItem extends StatelessWidget {
  const ChatListItem({
    required this.chat, // required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    super.key,
  });
  final ChatIndexEntry chat;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(chat.lastActive);
    final dateStr = DateFormat.yMMMd(
      LocaleSettings.currentLocale.languageTag,
    ).add_jm().format(date);

    return ListTile(
      selected: isSelected,
      // no BG without this
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.surfaceContainer.withAlpha(225),
      tileColor: Theme.of(context).colorScheme.surfaceContainer.withAlpha(200),
      title: Text(
        chat.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.chat.chatListItem.messageCount(count: chat.messageCount),
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: PopupMenuButton<_ChatListItemActionEnum>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _ChatListItemActionEnum.rename:
              onRename();
            case _ChatListItemActionEnum.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            key: const Key('chat-history-rename'),
            value: _ChatListItemActionEnum.rename,
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(t.chat.chatListItem.renameAction),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const Key('chat-history-delete'),
            value: _ChatListItemActionEnum.delete,
            child: ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                t.chat.chatListItem.deleteChatAction,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
