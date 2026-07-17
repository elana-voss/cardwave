import 'dart:async';

import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/text_to_speech_controller.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
    // Built per-render (not cached in a static) so it tracks the active locale.
    final timeFormatter = DateFormat.jm(
      LocaleSettings.currentLocale.languageTag,
    );

    // Non-uniform spacers (8 and 4 mixed); single `spacing:` can't express both.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeFormatter.format(
            DateTime.fromMillisecondsSinceEpoch(message.timestamp),
          ),
          style: metaStyle,
        ),
        if (message.tokenCount != null) ...[
          const SizedBox(width: 8),
          Text(
            t.chat.messageActionsRow.tokenCountAbbrev(
              count: message.tokenCount!,
            ),
            style: metaStyle,
          ),
        ],
        if (message.generationTime != null) ...[
          const SizedBox(width: 8),
          Text(
            t.chat.messageActionsRow.generationTimeAbbrev(
              seconds: (message.generationTime! / 1000).toStringAsFixed(1),
            ),
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
            tooltip: t.chat.messageActionsRow.viewGenerationPromptTooltip,
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
          tooltip: t.chat.messageActionsRow.messageActionsTooltip,
          itemBuilder: (context) => [
            if (onShowEdit != null)
              PopupMenuItem(
                key: const Key('msg-menu-edit'),
                value: _MessageActionEnum.edit,
                child: Text(t.chat.messageActionsRow.editAction),
              ),
            PopupMenuItem(
              key: const Key('msg-menu-copy'),
              value: _MessageActionEnum.copy,
              child: Text(t.chat.messageActionsRow.copyAction),
            ),
            if (onShareImage != null)
              PopupMenuItem(
                key: const Key('msg-menu-share-image'),
                value: _MessageActionEnum.shareImage,
                child: Text(t.chat.messageActionsRow.shareImageAction),
              ),
            if (onSetAsBackground != null)
              PopupMenuItem(
                key: const Key('msg-menu-set-bg'),
                value: _MessageActionEnum.setAsBackground,
                child: Text(t.chat.messageActionsRow.setAsBackgroundAction),
              ),
            if (onSetAsCharacterImage != null)
              PopupMenuItem(
                key: const Key('msg-menu-set-character-image'),
                value: _MessageActionEnum.setAsCharacterImage,
                child: Text(
                  t.chat.messageActionsRow.setAsCharacterImageAction,
                ),
              ),
            if (onDelete != null)
              PopupMenuItem(
                key: const Key('msg-menu-delete'),
                value: _MessageActionEnum.delete,
                child: Text(t.chat.messageActionsRow.deleteAction),
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
                    t.chat.messageActionsRow.copiedToClipboard,
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
