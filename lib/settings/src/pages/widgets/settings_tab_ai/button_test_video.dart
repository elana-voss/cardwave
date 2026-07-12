import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_tts.dart'
    show ButtonTestTts;
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Small IconButton that submits a test video-generation job for [model]
/// using [profile]'s credentials, then pops an [AppDialog] that plays the
/// downloaded MP4 so the user can actually see what the provider produced
/// — same intent as [ButtonTestTts], which plays the synthesized audio.
/// Renders nothing when the model has no video roster populated. Owns its
/// own in-flight flag so multiple buttons on the same screen don't
/// interfere. Errors surface via snackbar using
/// [LlmFetchException.userMessage]. On web the preview step is skipped
/// (the preview dialog uses a native file path written to system temp).
class ButtonTestVideo extends StatefulWidget {
  const ButtonTestVideo({
    required this.profile,
    required this.model,
    super.key,
  });
  final LlmProviderConfig profile;
  final LlmModel model;

  @override
  State<ButtonTestVideo> createState() => _ButtonTestVideoState();
}

class _ButtonTestVideoState extends State<ButtonTestVideo> {
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final options = widget.model.optionsVideo;
    if (options == null ||
        options.resolutions.isEmpty ||
        options.aspectRatios.isEmpty ||
        options.durations.isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: _isRunning
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.movie, size: 20),
      tooltip: t.settings.aiTab.testVideoTooltip,
      onPressed: _isRunning ? null : _test,
    );
  }

  Future<void> _test() async {
    setState(() => _isRunning = true);
    final svc = context.read<VideoGenerationController>();
    try {
      final bytes = await svc.testGenerateFor(
        provider: widget.profile,
        modelId: widget.model.id,
      );
      if (kIsWeb) {
        NavigationService().showSnackBar(
          t.settings.aiTab.videoGeneratedWebFallback,
        );
        return;
      }
      final file = await _writeTempMp4(bytes);
      LoggingService().logLlm(
        '[VIDEO] TEST_SAVED',
        '\nPath: ${file.path}'
            '\nBytes: ${bytes.length}',
      );
      if (!mounted) return;
      await NavigationService().showVideoTestPreviewDialog(file: file);
      unawaited(file.delete().catchError((_) => file));
    } on Exception catch (e) {
      final msg = e is LlmFetchException
          ? e.userMessage
          : t.settings.aiTab.videoFailedError;
      NavigationService().showSnackBar(msg);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<File> _writeTempMp4(Uint8List bytes) async {
    final dir = await Directory.systemTemp.createTemp('cardwave_video_test_');
    final file = File('${dir.path}/test.mp4');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
