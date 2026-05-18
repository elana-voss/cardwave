part of 'tts_option.dart';

@JsonSerializable()
class OptionsTts {
  const OptionsTts({required this.voices, required this.languages});

  factory OptionsTts.fromJson(Map<String, dynamic> json) =>
      _$OptionsTtsFromJson(json);
  final List<TtsVoice> voices;
  final List<TtsLanguage> languages;
  Map<String, dynamic> toJson() => _$OptionsTtsToJson(this);
}

/// OpenAI-voice rosters keyed by TTS model id. Shared by OpenAI,
/// OpenRouter, and NanoGpt — all three proxy the same voice set. Kept in a
/// neutral module rather than an `OpenAiProvider` private constant to avoid
/// cross-provider imports.
const openAiTtsVoicesByModel = <String, List<String>>{
  'tts-1': ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'],
  'tts-1-hd': ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'],
  'gpt-4o-mini-tts': [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
    'ash',
    'ballad',
    'coral',
    'sage',
    'verse',
  ],
  'gpt-audio': [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
    'ash',
    'ballad',
    'coral',
    'sage',
    'verse',
  ],
  'gpt-audio-mini': [
    'alloy',
    'echo',
    'fable',
    'onyx',
    'nova',
    'shimmer',
    'ash',
    'ballad',
    'coral',
    'sage',
    'verse',
  ],
};

/// Maps a model id (possibly namespaced like `openai/gpt-4o-mini-tts` on
/// OpenRouter) to the OpenAI voice list. Strips vendor prefix and any
/// trailing date suffix (`-2025-03-20`) so aggregator-specific ids resolve.
List<TtsVoice> openAiVoicesFor(String modelId) {
  final bareId = modelId.contains('/')
      ? modelId.substring(modelId.indexOf('/') + 1)
      : modelId;
  // Try exact first, then longest-prefix match so `gpt-audio-mini-<date>`
  // doesn't fall through to `gpt-audio`'s roster when the two diverge.
  var voiceIds = openAiTtsVoicesByModel[bareId];
  if (voiceIds == null) {
    final keys = openAiTtsVoicesByModel.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (bareId.startsWith(key)) {
        voiceIds = openAiTtsVoicesByModel[key];
        break;
      }
    }
  }
  if (voiceIds == null) return const [];
  return [
    for (final id in voiceIds)
      TtsVoice(id: id, label: '${id.substring(0, 1).toUpperCase()}${id.substring(1)}'),
  ];
}
