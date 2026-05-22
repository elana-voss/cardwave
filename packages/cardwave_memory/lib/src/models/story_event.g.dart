// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'story_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoryEvent _$StoryEventFromJson(Map<String, dynamic> json) => StoryEvent(
  id: json['id'] as String,
  recordedAt: (json['recorded_at'] as num).toInt(),
  text: json['text'] as String? ?? '',
  contextualPrefix: json['contextual_prefix'] as String? ?? '',
  eventType:
      $enumDecodeNullable(_$EventTypeEnumEnumMap, json['event_type']) ??
      EventTypeEnum.other,
  cause: json['cause'] as String? ?? '',
  effect: json['effect'] as String? ?? '',
  messageIds:
      (json['message_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  characterEmotion:
      $enumDecodeNullable(
        _$EmotionLabelEnumEnumMap,
        json['character_emotion'],
      ) ??
      EmotionLabelEnum.neutral,
  userEmotion:
      $enumDecodeNullable(_$EmotionLabelEnumEnumMap, json['user_emotion']) ??
      EmotionLabelEnum.neutral,
  importance: (json['importance'] as num?)?.toInt() ?? 0,
  characters:
      (json['characters'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  locations:
      (json['locations'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  items:
      (json['items'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  concepts:
      (json['concepts'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  keywords:
      (json['keywords'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$StoryEventToJson(
  StoryEvent instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'contextual_prefix': instance.contextualPrefix,
  'event_type': _$EventTypeEnumEnumMap[instance.eventType]!,
  'cause': instance.cause,
  'effect': instance.effect,
  'message_ids': instance.messageIds,
  'recorded_at': instance.recordedAt,
  'character_emotion': _$EmotionLabelEnumEnumMap[instance.characterEmotion]!,
  'user_emotion': _$EmotionLabelEnumEnumMap[instance.userEmotion]!,
  'importance': instance.importance,
  'characters': instance.characters,
  'locations': instance.locations,
  'items': instance.items,
  'concepts': instance.concepts,
  'keywords': instance.keywords,
};

const _$EventTypeEnumEnumMap = {
  EventTypeEnum.meeting: 'meeting',
  EventTypeEnum.relationshipChange: 'relationship_change',
  EventTypeEnum.conflict: 'conflict',
  EventTypeEnum.reconciliation: 'reconciliation',
  EventTypeEnum.separation: 'separation',
  EventTypeEnum.intimacy: 'intimacy',
  EventTypeEnum.promise: 'promise',
  EventTypeEnum.betrayal: 'betrayal',
  EventTypeEnum.revelation: 'revelation',
  EventTypeEnum.discovery: 'discovery',
  EventTypeEnum.locationChange: 'location_change',
  EventTypeEnum.injuryOrIllness: 'injury_or_illness',
  EventTypeEnum.birth: 'birth',
  EventTypeEnum.death: 'death',
  EventTypeEnum.timeJump: 'time_jump',
  EventTypeEnum.lifeEvent: 'life_event',
  EventTypeEnum.conversation: 'conversation',
  EventTypeEnum.other: 'other',
};

const _$EmotionLabelEnumEnumMap = {
  EmotionLabelEnum.admiration: 'admiration',
  EmotionLabelEnum.amusement: 'amusement',
  EmotionLabelEnum.anger: 'anger',
  EmotionLabelEnum.annoyance: 'annoyance',
  EmotionLabelEnum.approval: 'approval',
  EmotionLabelEnum.caring: 'caring',
  EmotionLabelEnum.confusion: 'confusion',
  EmotionLabelEnum.curiosity: 'curiosity',
  EmotionLabelEnum.desire: 'desire',
  EmotionLabelEnum.disappointment: 'disappointment',
  EmotionLabelEnum.disapproval: 'disapproval',
  EmotionLabelEnum.disgust: 'disgust',
  EmotionLabelEnum.embarrassment: 'embarrassment',
  EmotionLabelEnum.excitement: 'excitement',
  EmotionLabelEnum.fear: 'fear',
  EmotionLabelEnum.gratitude: 'gratitude',
  EmotionLabelEnum.grief: 'grief',
  EmotionLabelEnum.joy: 'joy',
  EmotionLabelEnum.love: 'love',
  EmotionLabelEnum.nervousness: 'nervousness',
  EmotionLabelEnum.optimism: 'optimism',
  EmotionLabelEnum.pride: 'pride',
  EmotionLabelEnum.realization: 'realization',
  EmotionLabelEnum.relief: 'relief',
  EmotionLabelEnum.remorse: 'remorse',
  EmotionLabelEnum.sadness: 'sadness',
  EmotionLabelEnum.surprise: 'surprise',
  EmotionLabelEnum.neutral: 'neutral',
};
