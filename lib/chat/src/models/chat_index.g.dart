// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_index.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatIndex _$ChatIndexFromJson(Map<String, dynamic> json) => ChatIndex(
  entries:
      (json['entries'] as List<dynamic>?)
          ?.map((e) => ChatIndexEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$ChatIndexToJson(ChatIndex instance) => <String, dynamic>{
  'entries': instance.entries.map((e) => e.toJson()).toList(),
};

ChatIndexEntry _$ChatIndexEntryFromJson(Map<String, dynamic> json) =>
    ChatIndexEntry(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      lastActive: (json['last_active'] as num?)?.toInt() ?? 0,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      isAssistant: json['is_assistant'] as bool? ?? false,
    );

Map<String, dynamic> _$ChatIndexEntryToJson(ChatIndexEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'name': instance.name,
      'last_active': instance.lastActive,
      'message_count': instance.messageCount,
      'is_assistant': instance.isAssistant,
    };
