// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackedValue _$TrackedValueFromJson(Map<String, dynamic> json) => TrackedValue(
  value: (json['value'] as num?)?.toDouble() ?? 0.0,
  lockoutTurnsRemaining:
      (json['lockout_turns_remaining'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TrackedValueToJson(TrackedValue instance) =>
    <String, dynamic>{
      'value': instance.value,
      'lockout_turns_remaining': instance.lockoutTurnsRemaining,
    };
