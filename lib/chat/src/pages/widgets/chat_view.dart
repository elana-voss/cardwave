import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/chat_controller.dart'
    show ChatController;
import 'package:cardwave/chat/src/controllers/mixins/chat_image_generation_mixin.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_video_generation_mixin.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_input_media_menu.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble.dart';
import 'package:cardwave/chat/src/pages/widgets/dialog_image_prompt_review.dart';
import 'package:cardwave/chat/src/pages/widgets/dialog_url_fetch_review.dart';
import 'package:cardwave/chat/src/pages/widgets/dialog_video_prompt_review.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum _ChatInputOptionEnum {
  newChat,
  continueChat,
  impersonate,
  generateReply,
  improveInput,
}

/// A self-contained chat UI that delegates all logic to a
/// [BaseChatViewController] provided via [Provider].
///
/// Works for both 1:1 chats (backed by [ChatController]) and group chats
/// (backed by [GroupChatController]). The parent widget is responsible for
/// creating and providing the controller.
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    this.characterFile,
    this.theme = ChatTheme.azure,
    this.onNewChat,
  });

  /// Used to render message bubbles (avatar, name). Nullable for group chats
  /// where character info is resolved per-message by the controller.
  final CharacterFile? characterFile;
  final ChatTheme theme;
  final VoidCallback? onNewChat;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final BaseChatViewController _controller;
  late final Map<ShortcutActivator, VoidCallback> _shortcutBindings;

  @override
  void initState() {
    super.initState();
    _controller = context.read<BaseChatViewController>();
    _controller.addListener(_onControllerUpdate);
    _controller.focusNode.addListener(_onFocusChange);
    _shortcutBindings = {
      const SingleActivator(LogicalKeyboardKey.enter): _handleSend,
      const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleSend,
    };
    final imageMixin = _controller is ChatImageGenerationMixin
        ? _controller
        : null;
    imageMixin?.onReviewImagePrompt = (prompt) =>
        DialogImagePromptReview.show(context, prompt: prompt);
    imageMixin?.onConfirmUrlFetch = (url, {purpose}) =>
        DialogUrlFetchReview.show(context, url: url, purpose: purpose);
    final videoMixin = _controller is ChatVideoGenerationMixin
        ? _controller
        : null;
    videoMixin?.onReviewVideoPrompt = (prompt) =>
        DialogVideoPromptReview.show(context, prompt: prompt);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.jumpToBottom(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.focusNode.removeListener(_onFocusChange);
    // ChatView does not own the controller — the parent does. Do not dispose it here.
    super.dispose();
  }

  void _onFocusChange() {
    if (_controller.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.jumpToBottom();
      });
    }
  }

  void _onControllerUpdate() {
    // Rebuild on a change to the chat controller (it holds the chat state —
    // messages, session — outside this State).
    // ignore: qcheck/avoid_empty_setstate
    if (mounted) setState(() {});
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await NavigationService().showConfirmCancelDialog(
      title: t.chat.chatView.deleteMessageTitle,
      message: t.chat.chatView.deleteMessageConfirmation,
      confirmText: t.common.actions.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirm && mounted) {
      await _controller.deleteMessage(message);
    }
  }

  void _handleSend() {
    if (_controller.isGenerating) {
      _controller.stopGeneration();
    } else {
      unawaited(_controller.sendMessage());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.jumpToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final messages = _controller.messages;
    final isLastMessageAI =
        messages.isNotEmpty &&
        (messages.last.role == ChatRoleEnum.assistant ||
            messages.last.role == ChatRoleEnum.character);
    final isLastMessageUser =
        messages.isNotEmpty && messages.last.role == ChatRoleEnum.user;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_controller.focusNode.hasFocus) {
                _controller.focusNode.unfocus();
              }
            },
            child: ListView.builder(
              controller: _controller.scrollController,
              reverse: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: messages.length,
              findChildIndexCallback: (key) {
                if (key is ObjectKey && key.value is ChatMessage) {
                  final index = messages.indexOf(key.value! as ChatMessage);
                  if (index >= 0) {
                    return messages.length - 1 - index;
                  }
                }
                return null;
              },
              itemBuilder: (context, index) {
                final msgIndex = messages.length - 1 - index;
                final message = messages[msgIndex];
                final isLastAndGenerating =
                    _controller.isGenerating &&
                    !_controller.isProcessingInput &&
                    msgIndex == messages.length - 1 &&
                    (message.role == ChatRoleEnum.assistant ||
                        message.role == ChatRoleEnum.character) &&
                    message.swipeIndex == message.swipes.length - 1;
                final isFirstMessage = msgIndex == 0;
                final isLastMessage = msgIndex == messages.length - 1;

                return ChatMessageBubble(
                  key: ObjectKey(message),
                  message: message,
                  chatSession: _controller.chatSession,
                  characterFile: widget.characterFile,
                  theme: widget.theme,
                  isGenerating: _controller.isGenerating,
                  isFirstMessage: isFirstMessage,
                  isLastMessage: isLastMessage,
                  contentNotifier:
                      (isLastAndGenerating && !_controller.userDetached)
                      ? _controller.streamingContent
                      : null,
                  // While the reader has scrolled up mid-stream, show the text
                  // streamed so far frozen, not the live feed: a blanked bubble
                  // collapses the list and snaps them back to the bottom.
                  streamingFreezeText:
                      (isLastAndGenerating && _controller.userDetached)
                      ? _controller.streamingContent.value
                      : null,
                  onEdit: (newContent) =>
                      _controller.updateMessage(message, newContent),
                  onDelete: () => _deleteMessage(message),
                  onSwipeChanged: _controller.supportsSwipe
                      ? () => _controller.changeSwipe(message)
                      : null,
                  onRegenerate:
                      (isLastMessage &&
                          (message.role == ChatRoleEnum.assistant ||
                              message.role == ChatRoleEnum.character) &&
                          !isFirstMessage)
                      ? _controller.regenerateLastMessage
                      : null,
                );
              },
            ),
          ),
        ),
        if (_controller.isProcessingInput)
          const LinearProgressIndicator(minHeight: 2)
        else
          const Divider(height: 1),
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CallbackShortcuts(
              bindings: _shortcutBindings,
              child: Listener(
                onPointerUp: (_) {
                  if (_controller.focusNode.hasFocus) {
                    unawaited(
                      SystemChannels.textInput.invokeMethod('TextInput.show'),
                    );
                  }
                },
                child: TextFieldAutotrim(
                  key: const Key('chat-input'),
                  controller: _controller.inputController,
                  focusNode: _controller.focusNode,
                  autoTrim: false,
                  decoration: InputDecoration(
                    hintText: t.chat.chatView.typeMessageHint,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    prefixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller.inputController,
                      builder: (context, textValue, child) {
                        final isInputEmpty = textValue.text.trim().isEmpty;
                        final controller = _controller;
                        final imageMixin =
                            controller is ChatImageGenerationMixin
                            ? controller
                            : null;
                        final videoMixin =
                            controller is ChatVideoGenerationMixin
                            ? controller
                            : null;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<_ChatInputOptionEnum>(
                              key: const Key('chat-menu-trigger'),
                              icon: const Icon(Icons.more_vert),
                              tooltip: t.chat.chatView.moreActionsTooltip,
                              enabled: !_controller.isGenerating,
                              onSelected: (option) {
                                switch (option) {
                                  case _ChatInputOptionEnum.continueChat:
                                    unawaited(_controller.continueChat());
                                  case _ChatInputOptionEnum.impersonate:
                                    unawaited(_controller.impersonateUser());
                                  case _ChatInputOptionEnum.generateReply:
                                    unawaited(_controller.generateReply());
                                  case _ChatInputOptionEnum.improveInput:
                                    unawaited(_controller.improveInput());
                                  case _ChatInputOptionEnum.newChat:
                                    widget.onNewChat?.call();
                                }
                              },
                              itemBuilder: (context) => [
                                if (widget.onNewChat != null)
                                  PopupMenuItem(
                                    key: const Key('chat-menu-new-chat'),
                                    value: _ChatInputOptionEnum.newChat,
                                    child: Row(
                                      spacing: 8,
                                      children: [
                                        const Icon(
                                          Icons.add_comment,
                                          size: 20,
                                        ),
                                        Text(t.chat.newChatLabel),
                                      ],
                                    ),
                                  ),
                                if (_controller.supportsContinue)
                                  PopupMenuItem(
                                    key: const Key('chat-menu-continue'),
                                    value: _ChatInputOptionEnum.continueChat,
                                    enabled: isLastMessageAI,
                                    child: Row(
                                      spacing: 8,
                                      children: [
                                        const Icon(
                                          Icons.fast_forward,
                                          size: 20,
                                        ),
                                        Text(t.chat.chatView.continueAction),
                                      ],
                                    ),
                                  ),
                                if (_controller.supportsImpersonation)
                                  PopupMenuItem(
                                    key: const Key('chat-menu-impersonate'),
                                    value: _ChatInputOptionEnum.impersonate,
                                    enabled: isLastMessageAI,
                                    child: Row(
                                      spacing: 8,
                                      children: [
                                        const Icon(Icons.person, size: 20),
                                        Text(
                                          t.chat.chatView.impersonateAction,
                                        ),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  key: const Key('chat-menu-generate-reply'),
                                  value: _ChatInputOptionEnum.generateReply,
                                  enabled: isLastMessageUser,
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 20,
                                      ),
                                      Text(
                                        t.chat.chatView.generateReplyAction,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_controller.supportsImproveInput)
                                  PopupMenuItem(
                                    key: const Key('chat-menu-improve'),
                                    value: _ChatInputOptionEnum.improveInput,
                                    enabled: !isInputEmpty,
                                    child: Row(
                                      spacing: 8,
                                      children: [
                                        const Icon(
                                          Icons.auto_fix_high,
                                          size: 20,
                                        ),
                                        Text(
                                          t.chat.chatView.improveMessageAction,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (imageMixin != null || videoMixin != null)
                              ChatInputMediaMenu(
                                enabled: !_controller.isGenerating,
                                imageEnabled:
                                    imageMixin != null &&
                                    !imageMixin.isGeneratingImage,
                                videoEnabled:
                                    videoMixin != null &&
                                    !videoMixin.isGeneratingVideo,
                                onGenerateImage: imageMixin?.generateImage,
                                onGenerateVideo: videoMixin?.generateVideo,
                              ),
                          ],
                        );
                      },
                    ),
                    suffixIcon: IconButton(
                      key: const Key('chat-send'),
                      icon: _controller.isGenerating
                          ? const Icon(Icons.stop)
                          : const Icon(Icons.send),
                      onPressed: _handleSend,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
