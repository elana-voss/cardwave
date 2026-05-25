// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterState _$CharacterStateFromJson(Map<String, dynamic> json) =>
    CharacterState(
      emotion: (json['emotion'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$EmotionEnumEnumMap, k),
          TrackedValue.fromJson(e as Map<String, dynamic>),
        ),
      ),
      physical: (json['physical'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$PhysicalEnumEnumMap, k),
          TrackedValue.fromJson(e as Map<String, dynamic>),
        ),
      ),
      relationship: (json['relationship'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$RelationshipEnumEnumMap, k),
          TrackedValue.fromJson(e as Map<String, dynamic>),
        ),
      ),
      knowledge: (json['knowledge'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, KnowledgeRecord.fromJson(e as Map<String, dynamic>)),
      ),
      flags: json['flags'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CharacterStateToJson(CharacterState instance) =>
    <String, dynamic>{
      'emotion': instance.emotion.map(
        (k, e) => MapEntry(_$EmotionEnumEnumMap[k]!, e.toJson()),
      ),
      'physical': instance.physical.map(
        (k, e) => MapEntry(_$PhysicalEnumEnumMap[k]!, e.toJson()),
      ),
      'relationship': instance.relationship.map(
        (k, e) => MapEntry(_$RelationshipEnumEnumMap[k]!, e.toJson()),
      ),
      'knowledge': instance.knowledge.map((k, e) => MapEntry(k, e.toJson())),
      'flags': instance.flags,
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
