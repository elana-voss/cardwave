import 'package:json_annotation/json_annotation.dart';

part 'knowledge_record.g.dart';

/// A single fact the character has accumulated. Written by director output
/// and node effects (via `knowledgeWrites`); read by predicates as
/// `character.<id>.knowledge.<topic>.{value, confidence}`.
@JsonSerializable()
class KnowledgeRecord {
  const KnowledgeRecord({
    required this.topic,
    required this.value,
    required this.confidence,
  });

  factory KnowledgeRecord.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeRecordFromJson(json);

  final String topic;
  final Object? value;
  final double confidence;

  Map<String, dynamic> toJson() => _$KnowledgeRecordToJson(this);
}
