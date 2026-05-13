// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TtsVoice _$TtsVoiceFromJson(Map<String, dynamic> json) => TtsVoice(
  id: json['id'] as String,
  label: json['label'] as String,
  tone: json['tone'] as String?,
);

Map<String, dynamic> _$TtsVoiceToJson(TtsVoice instance) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'tone': instance.tone,
};

TtsLanguage _$TtsLanguageFromJson(Map<String, dynamic> json) =>
    TtsLanguage(code: json['code'] as String, label: json['label'] as String);

Map<String, dynamic> _$TtsLanguageToJson(TtsLanguage instance) =>
    <String, dynamic>{'code': instance.code, 'label': instance.label};

ConfigTts _$ConfigTtsFromJson(Map<String, dynamic> json) => ConfigTts(
  voiceId: json['voice_id'] as String,
  languageCode: json['language_code'] as String,
);

Map<String, dynamic> _$ConfigTtsToJson(ConfigTts instance) => <String, dynamic>{
  'voice_id': instance.voiceId,
  'language_code': instance.languageCode,
};

OptionsTts _$OptionsTtsFromJson(Map<String, dynamic> json) => OptionsTts(
  voices: (json['voices'] as List<dynamic>)
      .map((e) => TtsVoice.fromJson(e as Map<String, dynamic>))
      .toList(),
  languages: (json['languages'] as List<dynamic>)
      .map((e) => TtsLanguage.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OptionsTtsToJson(OptionsTts instance) =>
    <String, dynamic>{
      'voices': instance.voices.map((e) => e.toJson()).toList(),
      'languages': instance.languages.map((e) => e.toJson()).toList(),
    };
