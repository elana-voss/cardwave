// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoResolution _$VideoResolutionFromJson(Map<String, dynamic> json) =>
    VideoResolution(id: json['id'] as String, label: json['label'] as String);

Map<String, dynamic> _$VideoResolutionToJson(VideoResolution instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

VideoAspectRatio _$VideoAspectRatioFromJson(Map<String, dynamic> json) =>
    VideoAspectRatio(id: json['id'] as String, label: json['label'] as String);

Map<String, dynamic> _$VideoAspectRatioToJson(VideoAspectRatio instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

VideoDuration _$VideoDurationFromJson(Map<String, dynamic> json) =>
    VideoDuration(
      seconds: (json['seconds'] as num).toInt(),
      label: json['label'] as String,
    );

Map<String, dynamic> _$VideoDurationToJson(VideoDuration instance) =>
    <String, dynamic>{'seconds': instance.seconds, 'label': instance.label};

OptionsVideo _$OptionsVideoFromJson(Map<String, dynamic> json) => OptionsVideo(
  resolutions: (json['resolutions'] as List<dynamic>)
      .map((e) => VideoResolution.fromJson(e as Map<String, dynamic>))
      .toList(),
  aspectRatios: (json['aspect_ratios'] as List<dynamic>)
      .map((e) => VideoAspectRatio.fromJson(e as Map<String, dynamic>))
      .toList(),
  durations: (json['durations'] as List<dynamic>)
      .map((e) => VideoDuration.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OptionsVideoToJson(OptionsVideo instance) =>
    <String, dynamic>{
      'resolutions': instance.resolutions.map((e) => e.toJson()).toList(),
      'aspect_ratios': instance.aspectRatios.map((e) => e.toJson()).toList(),
      'durations': instance.durations.map((e) => e.toJson()).toList(),
    };

ConfigVideo _$ConfigVideoFromJson(Map<String, dynamic> json) => ConfigVideo(
  resolutionId: json['resolution_id'] as String,
  aspectRatioId: json['aspect_ratio_id'] as String,
  durationSeconds: (json['duration_seconds'] as num).toInt(),
);

Map<String, dynamic> _$ConfigVideoToJson(ConfigVideo instance) =>
    <String, dynamic>{
      'resolution_id': instance.resolutionId,
      'aspect_ratio_id': instance.aspectRatioId,
      'duration_seconds': instance.durationSeconds,
    };
