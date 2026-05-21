// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_fact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryFact _$MemoryFactFromJson(Map<String, dynamic> json) => MemoryFact(
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
  supersededAt: (json['superseded_at'] as num?)?.toInt(),
  supersededBy: json['superseded_by'] as String?,
);

Map<String, dynamic> _$MemoryFactToJson(MemoryFact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subjects': instance.subjects,
      'text': instance.text,
      'message_ids': instance.messageIds,
      'superseded_at': instance.supersededAt,
      'superseded_by': instance.supersededBy,
    };
