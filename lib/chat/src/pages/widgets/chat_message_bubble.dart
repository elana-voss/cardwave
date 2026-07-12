import 'dart:async';
import 'dart:typed_data';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/chat_page_controller.dart';
import 'package:cardwave/chat/src/controllers/video_generation_controller.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_actions_row.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_layout_bubble.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_layout_flat.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_markdown_renderer.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_swipe_detector.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/message_swipe_flipper.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/system_message_bubble.dart';
import 'package:cardwave/chat/src/pages/widgets/chat_message_bubble/video_player_inline.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.contentNotifier,
    required this.onRegenerate,
    required this.theme,
    required this.isGenerating,
    required this.isFirstMessage,
    required this.isLastMessage,
    super.key,
    this.chatSession,
    this.onSwipeChanged,
    this.characterFile,
    this.streamingFreezeText,
  });

  /// Nullable for group chats where no single session applies.
  final ChatSession? chatSession;
  final ChatMessage message;
  final ValueChanged<String> onEdit;
  final VoidCallback onDelete;

  /// Null when the controller does not support swipes (e.g. group chats).
  final VoidCallback? onSwipeChanged;
  final ValueNotifier<String>? contentNotifier;

  /// Streamed-so-far text to show statically while the reader has scrolled up
  /// mid-stream. Freezing it (instead of blanking the bubble) keeps the
  /// bubble's height stable, so the list does not collapse and clamp the
  /// reader back to the bottom.
  final String? streamingFreezeText;
  final VoidCallback? onRegenerate;

  /// Nullable for group chats where character info is resolved per-message.
  final CharacterFile? characterFile;
  final ChatTheme theme;
  final bool isGenerating;
  final bool isFirstMessage;
  final bool isLastMessage;

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<void> _saveOrShareImage(String imagePath) async {
    final bytes = await AppStorage.instance.readBytes(
      StorageDomainEnum.cards,
      imagePath,
    );
    final data = Uint8List.fromList(bytes);
    final fileName = p.basename(imagePath);

    if (_isDesktop) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: t.chat.chatMessageBubble.imagesTypeGroupLabel,
            extensions: const ['png'],
          ),
        ],
      );
      if (location == null) return;
      final file = XFile.fromData(data, mimeType: 'image/png', name: fileName);
      await file.saveTo(location.path);
    } else {
      final file = XFile.fromData(data, mimeType: 'image/png', name: fileName);
      await SharePlus.instance.share(ShareParams(files: [file]));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRoleEnum.system) {
      return SystemMessageBubble(message: message);
    }

    // Null in group chats where ChatPageController isn't in the tree.
    // Read (not watch): an optional reference used in callbacks / optional
    // features — the bubble rebuilds with the chat list, not via this.
    ChatPageController? pageController;
    try {
      // ignore: qcheck/avoid_read_inside_build
      pageController = context.read<ChatPageController>();
    } on ProviderNotFoundException {
      pageController = null;
    }

    final isUser = message.role == ChatRoleEnum.user;
    final textColor = isUser
        ? theme.resolveUserTextColor()
        : theme.resolveAssistantTextColor();

    final textShadowColor = theme.resolveTextShadowColor();
    final shadows = textShadowColor.a > 0
        ? [
            Shadow(
              offset: const Offset(0, 0.75),
              blurRadius: 2,
              color: textShadowColor,
            ),
          ]
        : null;

    final messageStyle = TextStyle(
      fontFamily: 'NotoSans',
      fontSize: 15,
      height: 24.5 / 15.0,
      fontWeight: FontWeight.w500,
      color: textColor,
      shadows: shadows,
    );

    final metaStyle = TextStyle(
      fontSize: 12,
      color: isUser
          ? theme.resolveUserMetaColor()
          : theme.resolveAssistantMetaColor(),
    );

    final displayNameStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: textColor.withValues(alpha: 0.8),
    );

    final markdownWidget = MessageMarkdownRenderer(
      content: streamingFreezeText ?? message.content,
      contentNotifier: contentNotifier,
      messageStyle: messageStyle,
      theme: theme,
    );
    final reasoningText = isUser
        ? null
        : UtilsLlm.extractThinkContent(message.content);
    final textWidget = reasoningText == null
        ? markdownWidget
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              _ReasoningReveal(
                // ObjectKey on the ChatMessage keeps the expand/collapse
                // state tied to the underlying message across parent
                // rebuilds — without it the State resets on every repaint.
                key: ObjectKey(message),
                text: reasoningText,
                metaStyle: metaStyle,
              ),
              markdownWidget,
            ],
          );
    final attachments = message.attachedImages;
    final hasText = message.content.trim().isNotEmpty;
    final caption = message.imageCaption?.trim();
    final hasCaption = caption != null && caption.isNotEmpty;
    final contentWidget = attachments.isEmpty
        ? textWidget
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText) ...[textWidget, const SizedBox(height: 8)],
              for (final path in attachments)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () => ImageFullScreenViewer.show(context, path),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 512),
                        child: ImageCharacter(
                          key: ValueKey('att:$path'),
                          imagePath: UtilsImage.thumbnailPathFor(path),
                          fit: BoxFit.contain,
                          cacheWidth: 1024,
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasCaption) ...[
                const SizedBox(height: 6),
                Text(
                  caption,
                  style: messageStyle.copyWith(
                    fontStyle: FontStyle.italic,
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          );
    final videoPath = message.swipes.isNotEmpty
        ? message.activeSwipe.videoPath
        : null;

    // The select below is reached only when this reply actually has recalled
    // lines, so bubbles with nothing to show don't rebuild when the toggle flips.
    final recalledMemory =
        message.role == ChatRoleEnum.assistant && message.swipes.isNotEmpty
        ? message.activeSwipe.recalledMemory
        : const <String>[];
    final showRecalledMemory =
        recalledMemory.isNotEmpty &&
        context.select<SettingsService, bool>(
          (s) => s.settings.showRecalledMemory,
        );

    // The breakdown bar shows only under the last assistant reply — it reflects
    // the live context state of the most recent turn. Earlier replies and
    // user/system bubbles never show it.
    final promptBreakdown =
        message.role == ChatRoleEnum.assistant &&
            isLastMessage &&
            message.swipes.isNotEmpty
        ? message.activeSwipe.promptBreakdown
        : null;

    final contentWithVideo =
        videoPath == null && message.role != ChatRoleEnum.assistant
        ? contentWidget
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              contentWidget,
              if (showRecalledMemory)
                _RecalledMemoryFootnote(
                  lines: recalledMemory,
                  metaStyle: metaStyle,
                ),
              if (promptBreakdown != null &&
                  context.select<SettingsService, bool>(
                    (s) => s.settings.showPromptBreakdown,
                  ))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: PromptBreakdownBar(breakdown: promptBreakdown),
                ),
              if (message.role == ChatRoleEnum.assistant)
                _BubbleWaitingIndicator(message: message, metaStyle: metaStyle),
              if (videoPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 512),
                    child: VideoPlayerInline(
                      key: ValueKey('vid:$videoPath'),
                      videoPath: videoPath,
                    ),
                  ),
                ),
            ],
          );
    final actionsRow = MessageActionsRow(
      message: message,
      metaStyle: metaStyle,
      isGenerating: isGenerating,
      isLastMessage: isLastMessage,
      chatSession: chatSession,
      onShowPrompt: () => NavigationService().showJsonPromptDialog(
        rawPrompt: message.rawPrompt,
      ),
      onShowEdit: () {
        unawaited(() async {
          final newContent = await NavigationService().showMessageEditDialog(
            initialContent: message.content,
          );
          if (newContent != null) onEdit(newContent);
        }());
      },
      onDelete: onDelete,
      onShareImage: message.attachedImages.isNotEmpty
          ? () => _saveOrShareImage(message.attachedImages.first)
          : null,
      onSetAsBackground:
          pageController != null && message.attachedImages.isNotEmpty
          ? () =>
                pageController!.setBackgroundImage(message.attachedImages.first)
          : null,
      onSetAsCharacterImage:
          characterFile != null && message.attachedImages.isNotEmpty
          ? () {
              characterFile!.card.cardwaveData.customAvatar =
                  message.attachedImages.first;
              unawaited(
                context.read<CharacterService>().saveJsonInCacheAndPngNow(
                  characterFile!,
                ),
              );
            }
          : null,
    );
    final displayName = _getDisplayName(context, isUser);

    final hasRegenerateCapability =
        onRegenerate != null && message.swipeIndex == message.swipes.length - 1;
    final flipper =
        (message.swipes.length > 1 || hasRegenerateCapability) &&
            onSwipeChanged != null
        ? MessageSwipeFlipper(
            message: message,
            isGenerating: isGenerating,
            isFirstMessage: isFirstMessage,
            isLastMessage: isLastMessage,
            onRegenerate: onRegenerate,
            onSwipeChanged: onSwipeChanged!,
            metaStyle: metaStyle,
          )
        : null;

    Widget mainLayout;
    if (theme.layoutType == ChatLayoutTypeEnum.flat) {
      mainLayout = MessageLayoutFlat(
        isUser: isUser,
        displayName: displayName,
        displayNameStyle: displayNameStyle,
        contentWidget: contentWithVideo,
        actionsRow: actionsRow,
        flipper: flipper,
        theme: theme,
      );
    } else {
      mainLayout = MessageLayoutBubble(
        isUser: isUser,
        displayName: displayName,
        displayNameStyle: displayNameStyle,
        contentWidget: contentWithVideo,
        actionsRow: actionsRow,
        flipper: flipper,
        theme: theme,
      );
    }

    return onSwipeChanged != null
        ? MessageSwipeDetector(
            message: message,
            isGenerating: isGenerating,
            isLastMessage: isLastMessage,
            isFirstMessage: isFirstMessage,
            onSwipeChanged: onSwipeChanged!,
            onRegenerate: onRegenerate,
            child: mainLayout,
          )
        : mainLayout;
  }

  /// Resolve the display name for this bubble.
  ///
  /// We hand the whole [message] to the controller so it can decide identity
  /// with all the signals available — in particular [ChatMessage.role], which
  /// 1:1 chats need (their messages never carry a `characterId`), and
  /// [ChatMessage.characterId], which group chats need to pick the right
  /// speaker out of several. See [BaseChatViewController.resolveDisplayName].
  String _getDisplayName(BuildContext context, bool isUser) {
    final controller = context.read<BaseChatViewController?>();
    if (controller != null) {
      return controller.resolveDisplayName(message);
    }
    // Fallback: legacy path (should not normally be reached).
    if (isUser) {
      final personaName = chatSession?.personaName;
      if (personaName != null && personaName.isNotEmpty) return personaName;
      return context.select<SettingsService, String>(
        (s) => s.settings.activePersona.name,
      );
    }
    final card = characterFile?.card;
    final nickname = card?.nickname;
    return (nickname != null && nickname.isNotEmpty)
        ? nickname
        : (card?.name.isNotEmpty == true
              ? card!.name
              : t.chat.chatMessageBubble.assistantFallbackName);
  }
}

class _ReasoningReveal extends StatefulWidget {
  const _ReasoningReveal({
    required this.text,
    required this.metaStyle,
    super.key,
  });
  final String text;
  final TextStyle metaStyle;

  @override
  State<_ReasoningReveal> createState() => _ReasoningRevealState();
}

class _ReasoningRevealState extends State<_ReasoningReveal> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: widget.metaStyle.color,
                ),
                Text(
                  t.chat.chatMessageBubble.reasoningLabel,
                  style: widget.metaStyle,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, left: 8),
            child: Text(
              widget.text,
              style: widget.metaStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

/// Spinner + label that appears below the message body whenever the
/// active swipe's `waitingFor` state asks for it. Single source for
/// every "in flight" cue across text streaming, tool dispatch, and
/// image / video generation.
///
/// For `generatingVideo`, refines the label from the live job phase
/// registered with `VideoGenerationController`. The `provider.select`
/// scopes rebuilds to this message's job so unrelated bubbles don't
/// rebuild on every poll tick.
class _BubbleWaitingIndicator extends StatelessWidget {
  const _BubbleWaitingIndicator({
    required this.message,
    required this.metaStyle,
  });

  final ChatMessage message;
  final TextStyle metaStyle;

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // subscribe to locale; label/_videoJobLabel read t
    if (message.swipes.isEmpty) return const SizedBox.shrink();
    final swipe = message.activeSwipe;
    if (!swipe.waitingFor.showsIndicator) return const SizedBox.shrink();

    var label = swipe.waitingForLabel ?? swipe.waitingFor.defaultLabel;
    if (swipe.waitingFor == BubbleWaitingForEnum.generatingVideo) {
      final job = context.select<VideoGenerationController, VideoJobView?>(
        (service) => service.jobFor(message.timestamp),
      );
      final phase = _videoJobLabel(job);
      if (phase != null) label = phase;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(metaStyle.color),
            ),
          ),
          Text(label, style: metaStyle),
        ],
      ),
    );
  }

  String? _videoJobLabel(VideoJobView? job) {
    if (job == null) return null;
    switch (job.state) {
      case VideoJobStateEnum.submitting:
        return t.chat.chatMessageBubble.sendingToProvider;
      case VideoJobStateEnum.polling:
        final pct = job.progressPct;
        return pct != null
            ? t.chat.chatMessageBubble.pollingWithPercent(pct: pct)
            : t.chat.chatMessageBubble.polling;
      case VideoJobStateEnum.downloading:
        return t.chat.chatMessageBubble.downloading;
      case VideoJobStateEnum.done:
      case VideoJobStateEnum.failed:
        return null;
    }
  }
}

/// Dimmed footnotes under an AI reply listing the story-memory lines that
/// informed it. Each line arrives preformatted (e.g. "- (current) …"); this
/// only styles them as muted metadata so they read as a footnote, not part of
/// the reply. The parent decides whether to show it.
class _RecalledMemoryFootnote extends StatelessWidget {
  const _RecalledMemoryFootnote({required this.lines, required this.metaStyle});

  final List<String> lines;
  final TextStyle metaStyle;

  @override
  Widget build(BuildContext context) {
    final style = metaStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: metaStyle.color?.withValues(alpha: 0.7),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [for (final line in lines) Text(line, style: style)],
      ),
    );
  }
}
