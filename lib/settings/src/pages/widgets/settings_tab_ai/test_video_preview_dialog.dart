import 'dart:async';
import 'dart:io' show File;

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Modal wrapper that plays a freshly-downloaded test MP4 via media_kit
/// inside an [AppDialog]. Scoped to the AI providers test flow because the
/// chat bubble's `VideoPlayerInline` is bound to the cards-domain storage
/// path; the test MP4 lives in system temp, so reusing that widget would
/// mean threading absolute-path support through it for a single caller. The
/// media_kit `Player` + `VideoController` pair gives us cross-platform
/// playback (Windows included, unlike the old `video_player`-based dialog)
/// and `MaterialVideoControls` supplies play/pause + scrubber.
class TestVideoPreviewDialog extends StatefulWidget {
  const TestVideoPreviewDialog({required this.file, super.key});
  final File file;

  @override
  State<TestVideoPreviewDialog> createState() => _TestVideoPreviewDialogState();
}

class _TestVideoPreviewDialogState extends State<TestVideoPreviewDialog> {
  Player? _player;
  VideoController? _videoController;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final player = Player();
    final videoController = VideoController(player);
    try {
      // `play: true` starts playback as soon as the header is parsed,
      // matching the prior `controller.play()` call behavior.
      await player.open(Media(widget.file.path));
      // Test clips are ~4 seconds — looping avoids a static end-frame that
      // could be mistaken for a still image while the user reviews output.
      await player.setPlaylistMode(PlaylistMode.single);
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
        'TTS / video test player init failed',
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
    return AppDialog(
      builder: (_, _) {
        if (_initFailed) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.settings.aiTab.videoLoadFailedMessage),
          );
        }
        final videoController = _videoController;
        final player = _player;
        if (videoController == null || player == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final w = player.state.width;
        final h = player.state.height;
        final aspect = (w != null && h != null && w > 0 && h > 0)
            ? w / h
            : 16 / 9;
        return AspectRatio(
          aspectRatio: aspect,
          child: Video(
            controller: videoController,
            controls: MaterialVideoControls,
          ),
        );
      },
    );
  }
}
