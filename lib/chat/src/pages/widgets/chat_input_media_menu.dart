import 'package:cardwave/chat/src/pages/widgets/dialog_free_image_prompt.dart';
import 'package:cardwave/chat/src/pages/widgets/dialog_free_video_prompt.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';

/// Single magic-wand entry point in the chat input row for both image and
/// video generation. Two-stage popup: tap the wand → outer menu lists the
/// two media branches (`Generate image ▸` / `Generate video ▸`) → picking
/// a branch opens a second menu anchored at the same spot with the 6
/// modes (character, face, scenario, last message, background, free
/// prompt). `free` opens a small dialog to collect the user's subject.
/// Branches render only when the concrete controller wired in the
/// corresponding mixin; wand hides entirely when neither is available.
class ChatInputMediaMenu extends StatefulWidget {
  const ChatInputMediaMenu({
    required this.enabled,
    super.key,
    this.imageEnabled = false,
    this.videoEnabled = false,
    this.onGenerateImage,
    this.onGenerateVideo,
  });

  /// Gate for the whole wand + both branches. Usually `!isGenerating`
  /// (chat reply in flight) — keeps the user from stacking generations.
  final bool enabled;

  /// Additional image-branch gate, evaluated AFTER [enabled]. Typically
  /// `!isGeneratingImage` to block double-submits while a prompt is
  /// being compacted. Null when the image mixin isn't mounted.
  final bool imageEnabled;

  /// Additional video-branch gate, evaluated AFTER [enabled]. Typically
  /// `!isGeneratingVideo && canGenerateVideo` so the branch dims when no
  /// video preset resolves. Null when the video mixin isn't mounted.
  final bool videoEnabled;

  /// Fired when the user picks an image mode. Null hides the image branch.
  final Future<void> Function(
    ImageGenerationModeEnum mode, {
    String? freePrompt,
  })?
  onGenerateImage;

  /// Fired when the user picks a video mode. Null hides the video branch.
  final Future<void> Function(
    VideoGenerationModeEnum mode, {
    String? freePrompt,
  })?
  onGenerateVideo;

  @override
  State<ChatInputMediaMenu> createState() => _ChatInputMediaMenuState();
}

class _ChatInputMediaMenuState extends State<ChatInputMediaMenu> {
  // Captures the wand icon's render box so the second-stage submenu
  // anchors at the same screen position as the outer menu, not at the
  // tap location of the selected PopupMenuItem (which would jitter left
  // or right depending on where the user's finger landed).
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.onGenerateImage != null;
    final hasVideo = widget.onGenerateVideo != null;
    if (!hasImage && !hasVideo) return const SizedBox.shrink();

    return KeyedSubtree(
      key: const Key('chat-media-menu'),
      child: IconButton(
        key: _buttonKey,
        icon: const Icon(Icons.auto_fix_high),
        tooltip: 'Generate media',
        onPressed: widget.enabled ? _openTopMenu : null,
      ),
    );
  }

  Future<void> _openTopMenu() async {
    final rect = _buttonRect();
    final branch = await showMenu<_TopBranchEnum>(
      context: context,
      position: rect,
      items: [
        if (widget.onGenerateImage != null)
          PopupMenuItem<_TopBranchEnum>(
            key: const Key('media-menu-image'),
            value: _TopBranchEnum.image,
            enabled: widget.imageEnabled,
            child: const _BranchRow(
              icon: Icons.image_outlined,
              label: 'Generate image',
            ),
          ),
        if (widget.onGenerateVideo != null)
          PopupMenuItem<_TopBranchEnum>(
            key: const Key('media-menu-video'),
            value: _TopBranchEnum.video,
            enabled: widget.videoEnabled,
            child: const _BranchRow(
              icon: Icons.movie_outlined,
              label: 'Generate video',
            ),
          ),
      ],
    );
    if (branch == null || !mounted) return;
    switch (branch) {
      case _TopBranchEnum.image:
        await _openImageSubmenu(rect);
      case _TopBranchEnum.video:
        await _openVideoSubmenu(rect);
    }
  }

  Future<void> _openImageSubmenu(RelativeRect anchor) async {
    final mode = await showMenu<ImageGenerationModeEnum>(
      context: context,
      position: anchor,
      items: [
        for (final m in ImageGenerationModeEnum.values)
          if (m.isUserPickable)
            PopupMenuItem<ImageGenerationModeEnum>(
              key: Key('media-image-mode-${m.name}'),
              value: m,
              child: _ModeRow(icon: _imageIcon(m), label: m.label),
            ),
      ],
    );
    if (mode == null || !mounted) return;
    final callback = widget.onGenerateImage;
    if (callback == null) return;
    if (mode == ImageGenerationModeEnum.free) {
      final subject = await DialogFreeImagePrompt.show(context);
      if (subject == null || subject.isEmpty) return;
      await callback(mode, freePrompt: subject);
      return;
    }
    await callback(mode);
  }

  Future<void> _openVideoSubmenu(RelativeRect anchor) async {
    final mode = await showMenu<VideoGenerationModeEnum>(
      context: context,
      position: anchor,
      items: [
        for (final m in VideoGenerationModeEnum.values)
          if (m.isUserPickable)
            PopupMenuItem<VideoGenerationModeEnum>(
              key: Key('media-video-mode-${m.name}'),
              value: m,
              child: _ModeRow(icon: _videoIcon(m), label: m.label),
            ),
      ],
    );
    if (mode == null || !mounted) return;
    final callback = widget.onGenerateVideo;
    if (callback == null) return;
    if (mode == VideoGenerationModeEnum.free) {
      final subject = await DialogFreeVideoPrompt.show(context);
      if (subject == null || subject.isEmpty) return;
      await callback(mode, freePrompt: subject);
      return;
    }
    await callback(mode);
  }

  RelativeRect _buttonRect() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) {
      return RelativeRect.fill;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );
  }

  IconData _imageIcon(ImageGenerationModeEnum mode) {
    switch (mode) {
      case ImageGenerationModeEnum.character:
        return Icons.person;
      case ImageGenerationModeEnum.face:
        return Icons.face;
      case ImageGenerationModeEnum.scenario:
        return Icons.auto_stories;
      case ImageGenerationModeEnum.lastMessage:
        return Icons.chat;
      case ImageGenerationModeEnum.background:
        return Icons.landscape;
      case ImageGenerationModeEnum.free:
        return Icons.edit;
      case ImageGenerationModeEnum.selfie:
        // Never reached — selfie is filtered out of the user-facing menu via
        // `isUserPickable`. Returning a stable icon keeps the switch
        // exhaustive without inventing UI for a tool-only mode.
        return Icons.camera_alt;
    }
  }

  IconData _videoIcon(VideoGenerationModeEnum mode) {
    switch (mode) {
      case VideoGenerationModeEnum.character:
        return Icons.person;
      case VideoGenerationModeEnum.face:
        return Icons.face;
      case VideoGenerationModeEnum.scenario:
        return Icons.auto_stories;
      case VideoGenerationModeEnum.lastMessage:
        return Icons.chat;
      case VideoGenerationModeEnum.background:
        return Icons.landscape;
      case VideoGenerationModeEnum.free:
        return Icons.edit;
      case VideoGenerationModeEnum.selfie:
        // Never reached — see `_imageIcon` for the reasoning.
        return Icons.movie_creation;
    }
  }
}

enum _TopBranchEnum { image, video }

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        // Chevron cue so users know the item expands into another menu
        // rather than firing the action directly — matches Material
        // submenu affordance.
        Icon(Icons.chevron_right, size: 18, color: outline),
      ],
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
