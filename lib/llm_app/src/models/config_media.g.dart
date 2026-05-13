// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigMediaApp _$ConfigMediaAppFromJson(Map<String, dynamic> json) =>
    ConfigMediaApp(
      imagePresetId: json['image_preset_id'] as String?,
      videoPresetId: json['video_preset_id'] as String?,
      ttsPresetId: json['tts_preset_id'] as String?,
    );

Map<String, dynamic> _$ConfigMediaAppToJson(ConfigMediaApp instance) =>
    <String, dynamic>{
      'image_preset_id': ?instance.imagePresetId,
      'video_preset_id': ?instance.videoPresetId,
      'tts_preset_id': ?instance.ttsPresetId,
    };

ConfigMediaCharacter _$ConfigMediaCharacterFromJson(
  Map<String, dynamic> json,
) => ConfigMediaCharacter(
  imagePresetId: json['image_preset_id'] as String?,
  imageAspectRatioId: json['image_aspect_ratio_id'] as String?,
  imageNsfwAllowed: json['image_nsfw_allowed'] as bool?,
  imagePromptPrefix: json['image_prompt_prefix'] as String?,
  imageToolSelfieAllowed: json['image_tool_selfie_allowed'] as bool?,
  imageToolSelfieCaptionsAllowed:
      json['image_tool_selfie_captions_allowed'] as bool?,
  videoPresetId: json['video_preset_id'] as String?,
  videoResolutionId: json['video_resolution_id'] as String?,
  videoAspectRatioId: json['video_aspect_ratio_id'] as String?,
  videoDurationSeconds: (json['video_duration_seconds'] as num?)?.toInt(),
  videoNsfwAllowed: json['video_nsfw_allowed'] as bool?,
  videoPromptPrefix: json['video_prompt_prefix'] as String?,
  videoToolSendAllowed: json['video_tool_send_allowed'] as bool?,
  ttsPresetId: json['tts_preset_id'] as String?,
  ttsVoiceId: json['tts_voice_id'] as String?,
  ttsLanguageCode: json['tts_language_code'] as String?,
  webToolFetchAllowed: json['web_tool_fetch_allowed'] as bool?,
);

Map<String, dynamic> _$ConfigMediaCharacterToJson(
  ConfigMediaCharacter instance,
) => <String, dynamic>{
  'image_preset_id': ?instance.imagePresetId,
  'image_aspect_ratio_id': ?instance.imageAspectRatioId,
  'image_nsfw_allowed': ?instance.imageNsfwAllowed,
  'image_prompt_prefix': ?instance.imagePromptPrefix,
  'image_tool_selfie_allowed': ?instance.imageToolSelfieAllowed,
  'image_tool_selfie_captions_allowed':
      ?instance.imageToolSelfieCaptionsAllowed,
  'video_preset_id': ?instance.videoPresetId,
  'video_resolution_id': ?instance.videoResolutionId,
  'video_aspect_ratio_id': ?instance.videoAspectRatioId,
  'video_duration_seconds': ?instance.videoDurationSeconds,
  'video_nsfw_allowed': ?instance.videoNsfwAllowed,
  'video_prompt_prefix': ?instance.videoPromptPrefix,
  'video_tool_send_allowed': ?instance.videoToolSendAllowed,
  'tts_preset_id': ?instance.ttsPresetId,
  'tts_voice_id': ?instance.ttsVoiceId,
  'tts_language_code': ?instance.ttsLanguageCode,
  'web_tool_fetch_allowed': ?instance.webToolFetchAllowed,
};

ConfigMediaSession _$ConfigMediaSessionFromJson(Map<String, dynamic> json) =>
    ConfigMediaSession(
      imagePresetId: json['image_preset_id'] as String?,
      imageAspectRatioId: json['image_aspect_ratio_id'] as String?,
      imageNsfwAllowed: json['image_nsfw_allowed'] as bool?,
      imageToolSelfieAllowed: json['image_tool_selfie_allowed'] as bool?,
      imageToolSelfieCaptionsAllowed:
          json['image_tool_selfie_captions_allowed'] as bool?,
      imagePromptReview: json['image_prompt_review'] as bool?,
      imageToolPromptReview: json['image_tool_prompt_review'] as bool?,
      videoPresetId: json['video_preset_id'] as String?,
      videoResolutionId: json['video_resolution_id'] as String?,
      videoAspectRatioId: json['video_aspect_ratio_id'] as String?,
      videoDurationSeconds: (json['video_duration_seconds'] as num?)?.toInt(),
      videoNsfwAllowed: json['video_nsfw_allowed'] as bool?,
      videoPromptReview: json['video_prompt_review'] as bool?,
      videoToolSendAllowed: json['video_tool_send_allowed'] as bool?,
      ttsPresetId: json['tts_preset_id'] as String?,
      ttsVoiceId: json['tts_voice_id'] as String?,
      ttsLanguageCode: json['tts_language_code'] as String?,
      webToolFetchAllowed: json['web_tool_fetch_allowed'] as bool?,
      webToolFetchReview: json['web_tool_fetch_review'] as bool?,
    );

Map<String, dynamic> _$ConfigMediaSessionToJson(ConfigMediaSession instance) =>
    <String, dynamic>{
      'image_preset_id': ?instance.imagePresetId,
      'image_aspect_ratio_id': ?instance.imageAspectRatioId,
      'image_nsfw_allowed': ?instance.imageNsfwAllowed,
      'image_tool_selfie_allowed': ?instance.imageToolSelfieAllowed,
      'image_tool_selfie_captions_allowed':
          ?instance.imageToolSelfieCaptionsAllowed,
      'image_prompt_review': ?instance.imagePromptReview,
      'image_tool_prompt_review': ?instance.imageToolPromptReview,
      'video_preset_id': ?instance.videoPresetId,
      'video_resolution_id': ?instance.videoResolutionId,
      'video_aspect_ratio_id': ?instance.videoAspectRatioId,
      'video_duration_seconds': ?instance.videoDurationSeconds,
      'video_nsfw_allowed': ?instance.videoNsfwAllowed,
      'video_prompt_review': ?instance.videoPromptReview,
      'video_tool_send_allowed': ?instance.videoToolSendAllowed,
      'tts_preset_id': ?instance.ttsPresetId,
      'tts_voice_id': ?instance.ttsVoiceId,
      'tts_language_code': ?instance.ttsLanguageCode,
      'web_tool_fetch_allowed': ?instance.webToolFetchAllowed,
      'web_tool_fetch_review': ?instance.webToolFetchReview,
    };
