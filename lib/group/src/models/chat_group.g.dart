// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatGroup _$ChatGroupFromJson(Map<String, dynamic> json) => ChatGroup(
  id: json['id'] as String,
  name: json['name'] as String,
  memberAppCardIds:
      (json['member_app_card_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$ChatGroupToJson(ChatGroup instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'member_app_card_ids': instance.memberAppCardIds,
};
