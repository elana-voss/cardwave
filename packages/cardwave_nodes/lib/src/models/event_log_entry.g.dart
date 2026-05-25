// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventLogEntry _$EventLogEntryFromJson(Map<String, dynamic> json) =>
    EventLogEntry(
      turn: (json['turn'] as num).toInt(),
      text: json['text'] as String,
      significance: (json['significance'] as num).toDouble(),
    );

Map<String, dynamic> _$EventLogEntryToJson(EventLogEntry instance) =>
    <String, dynamic>{
      'turn': instance.turn,
      'text': instance.text,
      'significance': instance.significance,
    };
