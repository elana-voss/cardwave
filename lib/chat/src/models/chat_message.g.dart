// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  role: $enumDecode(_$ChatRoleEnumEnumMap, json['role']),
  timestamp: (json['timestamp'] as num).toInt(),
  swipes: (json['swipes'] as List<dynamic>?)
      ?.map((e) => ChatSwipe.fromJson(e as Map<String, dynamic>))
      .toList(),
  swipeIndex: (json['swipe_index'] as num?)?.toInt() ?? 0,
  generationTime: (json['generation_time'] as num?)?.toInt(),
  modelUsed: json['model_used'] as String?,
  characterId: json['character_id'] as String?,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'role': _$ChatRoleEnumEnumMap[instance.role]!,
      'swipes': instance.swipes.map((e) => e.toJson()).toList(),
      'swipe_index': instance.swipeIndex,
      'timestamp': instance.timestamp,
      'generation_time': instance.generationTime,
      'model_used': instance.modelUsed,
      'character_id': instance.characterId,
    };

const _$ChatRoleEnumEnumMap = {
  ChatRoleEnum.system: 'system',
  ChatRoleEnum.user: 'user',
  ChatRoleEnum.assistant: 'assistant',
  ChatRoleEnum.character: 'character',
};
