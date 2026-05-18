import 'dart:async';

import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/text_to_speech_controller.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

part 'message_actions_row_tts_play_button.dart';

class MessageActionsRow extends StatelessWidget {
  const MessageActionsRow({
    required this.message,
    required this.metaStyle,
    required this.isGenerating,
    required this.isLastMessage,
    super.key,
    this.onShowPrompt,
    this.onShowEdit,
    this.onDelete,
    this.onShareImage,
    this.onSetAsBackground,
    this.onSetAsCharacterImage,
    this.chatSession,
  });
  static final _timeFormatter = DateFormat.jm();

  final ChatMessage message;
  final TextStyle metaStyle;
  final bool isGenerating;
  final bool isLastMessage;
  final VoidCallback? onShowPrompt;
  final VoidCallback? onShowEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShareImage;
  final VoidCallback? onSetAsBackground;
  final VoidCallback? onSetAsCharacterImage;
  final ChatSession? chatSession;

  @override
  Widget build(BuildContext context) {
    final isStreamingThisMessage = isGenerating && isLastMessage;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeFormatter.format(
            DateTime.fromMillisecondsSinceEpoch(message.timestamp),
          ),
          style: metaStyle,
        ),
        if (message.tokenCount != null) ...[
          const SizedBox(width: 8),
          Text('${message.tokenCount}t', style: metaStyle),
        ],
        if (message.generationTime != null) ...[
          const SizedBox(width: 8),
          Text(
            '${(message.generationTime! / 1000).toStringAsFixed(1)}s',
            style: metaStyle,
          ),
        ],
        if (message.rawPrompt != null && onShowPrompt != null) ...[
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            iconSize: 20,
            color: metaStyle.color,
            disabledColor: Theme.of(context).disabledColor,
            tooltip: 'View generation prompt',
            icon: const Icon(Icons.description),
            onPressed: isStreamingThisMessage ? null : onShowPrompt,
          ),
        ],
        if (message.role == ChatRoleEnum.assistant) ...[
          const SizedBox(width: 4),
          _TtsPlayButton(
            message: message,
            metaStyle: metaStyle,
            isStreamingThisMessage: isStreamingThisMessage,
            chatSession: chatSession,
          ),
        ],
        const SizedBox(width: 4),
        PopupMenuButton<_MessageActionEnum>(
          key: const Key('msg-menu-trigger'),
          enabled: !isStreamingThisMessage,
          icon: Icon(Icons.more_vert, size: 20, color: metaStyle.color),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          tooltip: 'Message actions',
          itemBuilder: (context) => [
            if (onShowEdit != null)
              const PopupMenuItem(
                key: Key('msg-menu-edit'),
                value: _MessageActionEnum.edit,
                child: Text('Edit'),
              ),
            const PopupMenuItem(
              key: Key('msg-menu-copy'),
              value: _MessageActionEnum.copy,
              child: Text('Copy'),
            ),
            if (onShareImage != null)
              const PopupMenuItem(
                key: Key('msg-menu-share-image'),
                value: _MessageActionEnum.shareImage,
                child: Text('Share Image'),
              ),
            if (onSetAsBackground != null)
              const PopupMenuItem(
                key: Key('msg-menu-set-bg'),
                value: _MessageActionEnum.setAsBackground,
                child: Text('Set as Background'),
              ),
            if (onSetAsCharacterImage != null)
              const PopupMenuItem(
                key: Key('msg-menu-set-character-image'),
                value: _MessageActionEnum.setAsCharacterImage,
                child: Text('Set as Character Image'),
              ),
            if (onDelete != null)
              const PopupMenuItem(
                key: Key('msg-menu-delete'),
                value: _MessageActionEnum.delete,
                child: Text('Delete'),
              ),
          ],
          onSelected: (action) {
            unawaited(() async {
              switch (action) {
                case _MessageActionEnum.edit:
                  onShowEdit?.call();
                case _MessageActionEnum.copy:
                  await Clipboard.setData(ClipboardData(text: message.content));
                  NavigationService().showSnackBar(
                    'Message copied to clipboard',
                  );
                case _MessageActionEnum.shareImage:
                  onShareImage?.call();
                case _MessageActionEnum.setAsBackground:
                  onSetAsBackground?.call();
                case _MessageActionEnum.setAsCharacterImage:
                  onSetAsCharacterImage?.call();
                case _MessageActionEnum.delete:
                  onDelete?.call();
              }
            }());
          },
        ),
      ],
    );
  }
}

enum _MessageActionEnum {
  edit,
  copy,
  shareImage,
  setAsBackground,
  setAsCharacterImage,
  delete,
}
