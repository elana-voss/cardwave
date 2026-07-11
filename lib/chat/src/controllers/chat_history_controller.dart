import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_index.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart' show Color;

/// Stateless orchestrator for the per-entry actions in the "All Chats"
/// drawer list — rename and delete. Each method opens its dialog and runs
/// the persistence step; the widget keeps `setState` for its own in-memory
/// chat-index list since that is widget-local view state, not domain data.
class ChatHistoryController {
  const ChatHistoryController._();

  /// Opens a rename dialog for [entry]. On confirm, loads the full chat,
  /// updates its name, and persists it. Returns the new name so the caller
  /// can update its local index entry; returns null on cancel or empty input.
  static Future<String?> renameChat({
    required ChatService chatService,
    required CharacterFile characterFile,
    required ChatIndexEntry entry,
  }) async {
    final newName = await NavigationService().showTextInputDialog(
      title: t.chat.chatHistoryController.renameChatTitle,
      initialText: entry.name,
      hintText: t.chat.chatHistoryController.chatNameHint,
      confirmText: t.chat.chatHistoryController.renameButton,
      maxLines: 1,
    );
    if (newName == null || newName.isEmpty) return null;

    final fullChat = await chatService.getChat(characterFile, entry.id);
    if (fullChat != null) {
      fullChat.name = newName;
      await chatService.updateChat(characterFile, fullChat);
    }
    return newName;
  }

  /// Asks the user to confirm, then deletes [entry]'s chat. Returns true if
  /// the delete committed so the caller can drop it from its in-memory
  /// index; false on cancel. [confirmColor] tints the destructive confirm
  /// button — passed in because the controller has no BuildContext access.
  static Future<bool> confirmAndDelete({
    required ChatService chatService,
    required CharacterFile characterFile,
    required ChatIndexEntry entry,
    required Color confirmColor,
  }) async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: t.chat.chatHistoryController.deleteChatTitle,
      message: t.chat.chatHistoryController.deleteChatMessage,
      confirmText: t.common.actions.delete,
      confirmColor: confirmColor,
    );
    if (!confirmed) return false;
    await chatService.deleteChat(characterFile, entry.id);
    return true;
  }
}
