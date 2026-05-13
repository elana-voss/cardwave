import 'package:json_annotation/json_annotation.dart';

part 'tts_option_options.dart';

part 'tts_option.g.dart';

@JsonSerializable()
class TtsVoice {
  const TtsVoice({required this.id, required this.label, this.tone});

  factory TtsVoice.fromJson(Map<String, dynamic> json) =>
      _$TtsVoiceFromJson(json);
  final String id;
  final String label;
  final String? tone;
  Map<String, dynamic> toJson() => _$TtsVoiceToJson(this);
}

@JsonSerializable()
class TtsLanguage {
  const TtsLanguage({required this.code, required this.label});

  factory TtsLanguage.fromJson(Map<String, dynamic> json) =>
      _$TtsLanguageFromJson(json);

  /// Sentinel BCP-47 code meaning "let the model detect the language". The
  /// default seeded into every `ConfigTts` at chat-creation time.
  static const String autoCode = 'auto';

  final String code;
  final String label;
  Map<String, dynamic> toJson() => _$TtsLanguageToJson(this);
}

@JsonSerializable()
class ConfigTts {
  ConfigTts({required this.voiceId, required this.languageCode});

  factory ConfigTts.fromJson(Map<String, dynamic> json) =>
      _$ConfigTtsFromJson(json);
  String voiceId;
  String languageCode;
  Map<String, dynamic> toJson() => _$ConfigTtsToJson(this);
}
