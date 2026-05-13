// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_persona.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatPersona _$ChatPersonaFromJson(Map<String, dynamic> json) => ChatPersona(
  name: json['name'] as String,
  description: json['description'] as String,
  id: json['id'] as String?,
);

Map<String, dynamic> _$ChatPersonaToJson(ChatPersona instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
    };
