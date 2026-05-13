import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Small IconButton that synthesizes a fixed test phrase for [model] using
/// [profile]'s credentials. Renders nothing when the model has no voice
/// roster (i.e. [LlmPureHelpers.populateTtsVoices] hasn't populated it).
/// Owns its own in-flight flag so multiple buttons on the same screen don't
/// interfere. Errors surface via snackbar using [LlmFetchException.userMessage].
class ButtonTestTts extends StatefulWidget {
  const ButtonTestTts({
    required this.profile,
    required this.model,
    super.key,
  });
  final LlmProviderConfig profile;
  final LlmModel model;

  @override
  State<ButtonTestTts> createState() => _ButtonTestTtsState();
}

class _ButtonTestTtsState extends State<ButtonTestTts> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    final options = widget.model.optionsTts;
    if (options == null || options.voices.isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: _isPlaying
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow, size: 20),
      tooltip: 'Test TTS',
      onPressed: _isPlaying ? null : _testTts,
    );
  }

  Future<void> _testTts() async {
    // This button only renders for models with a non-empty TTS voice roster.
    final optionsTts = widget.model.optionsTts!;
    // ignore: qcheck/avoid_unsafe_collection_methods
    final voiceId = optionsTts.voices.first.id;
    setState(() => _isPlaying = true);
    final tts = context.read<TextToSpeechController>();
    try {
      await tts.testSpeakFor(
        provider: widget.profile,
        modelId: widget.model.id,
        text: 'Hello, this is a test.',
        voiceId: voiceId,
        languageCode: TtsLanguage.autoCode,
      );
    } on Exception catch (e) {
      final msg = e is LlmFetchException ? e.userMessage : 'TTS failed.';
      NavigationService().showSnackBar(msg);
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }
}
