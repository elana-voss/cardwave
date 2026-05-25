// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Scene _$SceneFromJson(Map<String, dynamic> json) => Scene(
  location: json['location'] as String? ?? '',
  timeOfDay: json['time_of_day'] as String? ?? '',
  presentEntities: (json['present_entities'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  sensoryHooks: (json['sensory_hooks'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SceneToJson(Scene instance) => <String, dynamic>{
  'location': instance.location,
  'time_of_day': instance.timeOfDay,
  'present_entities': instance.presentEntities,
  'sensory_hooks': instance.sensoryHooks,
};
