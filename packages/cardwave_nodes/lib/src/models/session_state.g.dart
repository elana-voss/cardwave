// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionState _$SessionStateFromJson(Map<String, dynamic> json) => SessionState(
  characters: (json['characters'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, CharacterState.fromJson(e as Map<String, dynamic>)),
  ),
  currentGoal: json['current_goal'] as String? ?? '',
  currentPhase:
      $enumDecodeNullable(_$PhaseEnumEnumMap, json['current_phase']) ??
      PhaseEnum.scene,
  currentScene: json['current_scene'] == null
      ? null
      : Scene.fromJson(json['current_scene'] as Map<String, dynamic>),
  flags: json['flags'] as Map<String, dynamic>?,
  eventLog: (json['event_log'] as List<dynamic>?)
      ?.map((e) => EventLogEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  turn: (json['turn'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$SessionStateToJson(SessionState instance) =>
    <String, dynamic>{
      'characters': instance.characters.map((k, e) => MapEntry(k, e.toJson())),
      'current_goal': instance.currentGoal,
      'current_phase': _$PhaseEnumEnumMap[instance.currentPhase]!,
      'current_scene': instance.currentScene.toJson(),
      'flags': instance.flags,
      'event_log': instance.eventLog.map((e) => e.toJson()).toList(),
      'turn': instance.turn,
    };

const _$PhaseEnumEnumMap = {
  PhaseEnum.scene: 'scene',
  PhaseEnum.sequel: 'sequel',
};
