// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KnowledgeRecord _$KnowledgeRecordFromJson(Map<String, dynamic> json) =>
    KnowledgeRecord(
      topic: json['topic'] as String,
      value: json['value'],
      confidence: (json['confidence'] as num).toDouble(),
    );

Map<String, dynamic> _$KnowledgeRecordToJson(KnowledgeRecord instance) =>
    <String, dynamic>{
      'topic': instance.topic,
      'value': instance.value,
      'confidence': instance.confidence,
    };
