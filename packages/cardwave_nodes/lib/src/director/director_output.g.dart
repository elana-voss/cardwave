// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'director_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DirectorOutput _$DirectorOutputFromJson(Map<String, dynamic> json) =>
    DirectorOutput(
      emotionDeltas: (json['emotion_deltas'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          (e as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              $enumDecode(_$EmotionEnumEnumMap, k),
              (e as num).toDouble(),
            ),
          ),
        ),
      ),
      physicalDeltas: (json['physical_deltas'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          (e as Map<String, dynamic>).map(
            (k, e) => MapEntry(
              $enumDecode(_$PhysicalEnumEnumMap, k),
              (e as num).toDouble(),
            ),
          ),
        ),
      ),
      relationshipDeltas: (json['relationship_deltas'] as Map<String, dynamic>?)
          ?.map(
            (k, e) => MapEntry(
              k,
              (e as Map<String, dynamic>).map(
                (k, e) => MapEntry(
                  $enumDecode(_$RelationshipEnumEnumMap, k),
                  (e as num).toDouble(),
                ),
              ),
            ),
          ),
      flagSet: json['flag_set'] as Map<String, dynamic>?,
      knowledgeWrites: (json['knowledge_writes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          k,
          (e as List<dynamic>)
              .map((e) => KnowledgeRecord.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ),
      directiveLines: (json['directive_lines'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      generatedNodes: (json['generated_nodes'] as List<dynamic>?)
          ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventLogAppend: (json['event_log_append'] as List<dynamic>?)
          ?.map((e) => EventLogAppend.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DirectorOutputToJson(
  DirectorOutput instance,
) => <String, dynamic>{
  'emotion_deltas': instance.emotionDeltas.map(
    (k, e) =>
        MapEntry(k, e.map((k, e) => MapEntry(_$EmotionEnumEnumMap[k]!, e))),
  ),
  'physical_deltas': instance.physicalDeltas.map(
    (k, e) =>
        MapEntry(k, e.map((k, e) => MapEntry(_$PhysicalEnumEnumMap[k]!, e))),
  ),
  'relationship_deltas': instance.relationshipDeltas.map(
    (k, e) => MapEntry(
      k,
      e.map((k, e) => MapEntry(_$RelationshipEnumEnumMap[k]!, e)),
    ),
  ),
  'flag_set': instance.flagSet,
  'knowledge_writes': instance.knowledgeWrites.map(
    (k, e) => MapEntry(k, e.map((e) => e.toJson()).toList()),
  ),
  'directive_lines': instance.directiveLines,
  'generated_nodes': instance.generatedNodes.map((e) => e.toJson()).toList(),
  'event_log_append': instance.eventLogAppend.map((e) => e.toJson()).toList(),
};

const _$EmotionEnumEnumMap = {
  EmotionEnum.joy: 'joy',
  EmotionEnum.sadness: 'sadness',
  EmotionEnum.anger: 'anger',
  EmotionEnum.fear: 'fear',
  EmotionEnum.trust: 'trust',
  EmotionEnum.disgust: 'disgust',
  EmotionEnum.surprise: 'surprise',
  EmotionEnum.anticipation: 'anticipation',
};

const _$PhysicalEnumEnumMap = {
  PhysicalEnum.tiredness: 'tiredness',
  PhysicalEnum.hunger: 'hunger',
  PhysicalEnum.intoxication: 'intoxication',
  PhysicalEnum.arousal: 'arousal',
  PhysicalEnum.pain: 'pain',
  PhysicalEnum.discomfort: 'discomfort',
};

const _$RelationshipEnumEnumMap = {
  RelationshipEnum.trust: 'trust',
  RelationshipEnum.familiarity: 'familiarity',
  RelationshipEnum.attraction: 'attraction',
  RelationshipEnum.respect: 'respect',
  RelationshipEnum.resentment: 'resentment',
};
