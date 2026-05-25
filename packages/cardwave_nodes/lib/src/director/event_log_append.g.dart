// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_append.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventLogAppend _$EventLogAppendFromJson(Map<String, dynamic> json) =>
    EventLogAppend(
      text: json['text'] as String,
      significance: (json['significance'] as num).toDouble(),
    );

Map<String, dynamic> _$EventLogAppendToJson(EventLogAppend instance) =>
    <String, dynamic>{
      'text': instance.text,
      'significance': instance.significance,
    };
