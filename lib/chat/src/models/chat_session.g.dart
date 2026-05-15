// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) => ChatSession(
  id: json['id'] as String,
  ownerId: json['owner_id'] as String,
  modelPresetId: json['model_preset_id'] as String,
  created: (json['created'] as num).toInt(),
  lastActive: (json['last_active'] as num).toInt(),
  name: json['name'] as String,
  isStreaming: json['is_streaming'] as bool,
  isNsfw: json['is_nsfw'] as bool,
  isScenario: json['is_scenario'] as bool,
  removeTrailingSentences: json['remove_trailing_sentences'] as bool,
  personaName: json['persona_name'] as String,
  personaDescription: json['persona_description'] as String,
  activeStickies:
      (json['active_stickies'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      {},
  activeCooldowns:
      (json['active_cooldowns'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      {},
  localVariables:
      (json['local_variables'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      {},
  groupData: json['group_data'] == null
      ? null
      : GroupData.fromJson(json['group_data'] as Map<String, dynamic>),
  backgroundImage: json['background_image'] as String?,
  isAssistant: json['is_assistant'] as bool? ?? false,
  configMedia: json['config_media'] == null
      ? null
      : ConfigMediaSession.fromJson(
          json['config_media'] as Map<String, dynamic>,
        ),
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  usedFirstNames:
      (json['used_first_names'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      {},
  usedLastNames:
      (json['used_last_names'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      {},
);

Map<String, dynamic> _$ChatSessionToJson(ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'model_preset_id': instance.modelPresetId,
      'config_media': ?instance.configMedia?.toJson(),
      'created': instance.created,
      'last_active': instance.lastActive,
      'name': instance.name,
      'is_streaming': instance.isStreaming,
      'is_nsfw': instance.isNsfw,
      'is_scenario': instance.isScenario,
      'remove_trailing_sentences': instance.removeTrailingSentences,
      'persona_name': instance.personaName,
      'persona_description': instance.personaDescription,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'active_stickies': instance.activeStickies,
      'active_cooldowns': instance.activeCooldowns,
      'local_variables': instance.localVariables,
      'group_data': ?instance.groupData?.toJson(),
      'background_image': ?instance.backgroundImage,
      'is_assistant': instance.isAssistant,
      'used_first_names': instance.usedFirstNames.toList(),
      'used_last_names': instance.usedLastNames.toList(),
    };
