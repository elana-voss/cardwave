import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Inline video player for a completed generated MP4 stored at
/// cards-domain-relative [videoPath]. Built on `media_kit` (libmpv) so the
/// same widget renders on Windows, Linux, macOS, Android, and iOS — the
/// standard `video_player` package had no Windows backend and left the
/// bubble stuck on "Could not load generated video". The `Player` is
/// constructed lazily on mount; `MaterialVideoControls` supply play/pause
/// and scrubber. Web is intentionally unsupported (the feature path writes
/// to a native file under the cards domain, which doesn't exist in-browser).
class VideoPlayerInline extends StatefulWidget {
  const VideoPlayerInline({required this.videoPath, super.key});
  final String videoPath;

  @override
  State<VideoPlayerInline> createState() => _VideoPlayerInlineState();
}

class _VideoPlayerInlineState extends State<VideoPlayerInline> {
  Player? _player;
  VideoController? _videoController;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant VideoPlayerInline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      unawaited(_player?.dispose());
      _player = null;
      _videoController = null;
      _initFailed = false;
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    if (kIsWeb) return;
    final absolute = AppStorage.instance.absolutePathFor(
      StorageDomainEnum.cards,
      widget.videoPath,
    );
    if (absolute == null) return;
    final player = Player();
    final videoController = VideoController(player);
    try {
      // `Player.open(..., play: false)` resolves once the file header is
      // parsed — the media_kit equivalent of the old
      // `VideoPlayerController.initialize()` call.
      await player.open(Media(absolute), play: false);
      if (!mounted) {
        unawaited(player.dispose());
        return;
      }
      setState(() {
        _player = player;
        _videoController = videoController;
      });
    } on Exception catch (e, stackTrace) {
      LoggingService().error(
        'Inline video player init failed for ${widget.videoPath}',
        e,
        stackTrace,
      );
      unawaited(player.dispose());
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Video playback not supported on web.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }
    if (_initFailed) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Could not load video.', style: TextStyle(fontSize: 12)),
      );
    }
    final videoController = _videoController;
    final player = _player;
    if (videoController == null || player == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _aspectRatio(player),
        child: Video(
          controller: videoController,
          controls: MaterialVideoControls,
        ),
      ),
    );
  }

  /// Pulls native video dimensions from the `Player` state to constrain
  /// the [Video] widget's outer box. media_kit's Video widget fills its
  /// parent with `BoxFit.contain` by default, so without this wrapper the
  /// bubble's 512px max-height `ConstrainedBox` would letterboxes the
  /// clip at a fixed oversized frame. Falls back to 16/9 on the rare case
  /// state isn't populated yet.
  double _aspectRatio(Player player) {
    final w = player.state.width;
    final h = player.state.height;
    if (w == null || h == null || w <= 0 || h <= 0) return 16 / 9;
    return w / h;
  }
}
