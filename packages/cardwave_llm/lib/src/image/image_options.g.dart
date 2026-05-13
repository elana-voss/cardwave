// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImageAspectRatio _$ImageAspectRatioFromJson(Map<String, dynamic> json) =>
    ImageAspectRatio(id: json['id'] as String, label: json['label'] as String);

Map<String, dynamic> _$ImageAspectRatioToJson(ImageAspectRatio instance) =>
    <String, dynamic>{'id': instance.id, 'label': instance.label};

OptionsImage _$OptionsImageFromJson(Map<String, dynamic> json) => OptionsImage(
  aspectRatios: (json['aspect_ratios'] as List<dynamic>)
      .map((e) => ImageAspectRatio.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$OptionsImageToJson(OptionsImage instance) =>
    <String, dynamic>{
      'aspect_ratios': instance.aspectRatios.map((e) => e.toJson()).toList(),
    };

ConfigImage _$ConfigImageFromJson(Map<String, dynamic> json) =>
    ConfigImage(aspectRatioId: json['aspect_ratio_id'] as String);

Map<String, dynamic> _$ConfigImageToJson(ConfigImage instance) =>
    <String, dynamic>{'aspect_ratio_id': instance.aspectRatioId};
