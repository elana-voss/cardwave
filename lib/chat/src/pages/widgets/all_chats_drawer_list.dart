import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/chat_history_controller.dart';
import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_list_item.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AllChatsDrawerList extends StatefulWidget {
  const AllChatsDrawerList({
    required this.characterFile,
    required this.onChatSelected,
    required this.onChatDeleted,
    super.key,
    this.selectedChatId,
  });
  final CharacterFile characterFile;
  final String? selectedChatId;
  final ValueChanged<ChatIndexEntry> onChatSelected;
  final ValueChanged<String> onChatDeleted;

  @override
  State<AllChatsDrawerList> createState() => _AllChatsDrawerListState();
}

class _AllChatsDrawerListState extends State<AllChatsDrawerList> {
  ChatIndex? _chatIndex;
  bool _isRebuilding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadChats());
  }

  Future<void> _loadChats() async {
    final index = await context.read<ChatService>().getChatsForCharacter(
      widget.characterFile,
      onRebuild: () {
        if (mounted) setState(() => _isRebuilding = true);
      },
    );
    if (!mounted) return;
    setState(() {
      _chatIndex = index;
      _isRebuilding = false;
    });
  }

  Future<void> _renameChat(ChatIndexEntry entry) async {
    final newName = await ChatHistoryController.renameChat(
      chatService: context.read<ChatService>(),
      characterFile: widget.characterFile,
      entry: entry,
    );
    if (newName != null && mounted) {
      setState(() => entry.name = newName);
    }
  }

  Future<void> _deleteChat(ChatIndexEntry entry) async {
    final committed = await ChatHistoryController.confirmAndDelete(
      chatService: context.read<ChatService>(),
      characterFile: widget.characterFile,
      entry: entry,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (committed && mounted) {
      setState(() => _chatIndex?.entries.removeWhere((c) => c.id == entry.id));
      widget.onChatDeleted(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    if (_chatIndex == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_isRebuilding) ...[
              const SizedBox(height: 16),
              Text(t.chat.allChatsDrawerList.rebuildingIndex),
            ],
          ],
        ),
      );
    }
    if (_chatIndex!.entries.isEmpty) {
      return Center(child: Text(t.chat.allChatsDrawerList.noChatsFound));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _chatIndex!.entries.length,
      itemBuilder: (context, index) {
        final entry = _chatIndex!.entries[index];
        final isSelected = widget.selectedChatId == entry.id;
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: ChatListItem(
            chat: entry,
            // index: index,
            isSelected: isSelected,
            onRename: () => _renameChat(entry),
            onDelete: () => _deleteChat(entry),
            onTap: () => widget.onChatSelected(entry),
          ),
        );
      },
    );
  }
}
