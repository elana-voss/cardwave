part of '../../workspace_page.dart';

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.mode,
    required this.isWideScreen,
    required this.isImageVisible,
    required this.characterFile,
    required this.primaryChat,
    required this.editor,
    required this.assistantChat,
  });
  final ChatPageModeEnum mode;
  final bool isWideScreen;
  final bool isImageVisible;
  final CharacterFile characterFile;
  final Widget primaryChat;
  final Widget editor;
  final Widget assistantChat;

  @override
  Widget build(BuildContext context) {
    var content = switch (mode) {
      ///
      /// Chat
      ///
      ChatPageModeEnum.chat =>
        isWideScreen
            ?
              ///
              /// Chat: Wide-Screen
              ///
              Row(
                children: [
                  const Spacer(),
                  Expanded(flex: 2, child: primaryChat),
                  Expanded(
                    child: ImageThumbnailStyled(
                      file: characterFile,
                      isVisible: isImageVisible,
                    ),
                  ),
                ],
              )
            :
              ///
              /// Chat: Small-Screen
              ///
              primaryChat,

      ///
      /// Editor
      ///
      ChatPageModeEnum.editor =>
        isWideScreen
            ?
              ///
              /// Chat: Wide-Screen
              ///
              Row(
                children: [
                  Expanded(flex: 3, child: editor),
                  if (isImageVisible)
                    Expanded(
                      child: ImageThumbnailStyled(
                        file: characterFile,
                        onTapEdit: () {
                          unawaited(
                            context
                                .read<EditorPageController>()
                                .pickAndReplaceImage(context, characterFile),
                          );
                        },
                      ),
                    ),
                ],
              )
            :
              ///
              /// Editor: Small-Screen
              ///
              editor,

      ///
      /// Chat-Editor
      ///
      ChatPageModeEnum.splitChatEditor => WorkspaceSplitPane(
        leftChild: primaryChat,
        rightChild: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          clipBehavior: Clip.antiAlias,
          child: editor,
        ),
      ),

      ///
      /// Editor-Assistant
      ///
      ChatPageModeEnum.splitEditorAssistant => WorkspaceSplitPane(
        leftChild: editor,
        rightChild: assistantChat,
      ),
    };

    ///
    /// Background image for chat
    ///
    // `if` over 2 of 4 layout modes wrapping a large block; a switch needs an
    // empty break arm — uglier, no gain.
    // ignore: qcheck/prefer_switch_with_enums
    if (mode == ChatPageModeEnum.chat ||
        mode == ChatPageModeEnum.splitChatEditor) {
      final customBg = context
          .watch<ChatPageController>()
          .selectedChat
          ?.backgroundImage;
      content = Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: customBg != null
                // Mirrors the blur from ImageBackgroundBlurred, which
                // can't be reused here because it expects a CharacterFile,
                // not a raw path. If blur strength becomes a setting later,
                // extract a shared constant or widget for both paths.
                ? RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: ImageCharacter(
                        key: ValueKey('chat-bg:$customBg'),
                        imagePath: UtilsImage.thumbnailPathFor(customBg),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : ImageBackgroundBlurred(character: characterFile),
          ),
          content,
        ],
      );
    }

    return content;
  }
}
