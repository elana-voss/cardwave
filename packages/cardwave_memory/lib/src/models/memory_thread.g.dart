// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_thread.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryThread _$MemoryThreadFromJson(Map<String, dynamic> json) => MemoryThread(
  id: json['id'] as String,
  subjects:
      (json['subjects'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  text: json['text'] as String? ?? '',
  messageIds:
      (json['message_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  resolvedAt: (json['resolved_at'] as num?)?.toInt(),
  resolvedByMessageIds:
      (json['resolved_by_message_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$MemoryThreadToJson(MemoryThread instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subjects': instance.subjects,
      'text': instance.text,
      'message_ids': instance.messageIds,
      'resolved_at': instance.resolvedAt,
      'resolved_by_message_ids': instance.resolvedByMessageIds,
    };
