// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupFile _$GroupFileFromJson(Map<String, dynamic> json) => GroupFile(
  group: ChatGroup.fromJson(json['group'] as Map<String, dynamic>),
  created: (json['created'] as num).toInt(),
  lastActive: (json['last_active'] as num).toInt(),
  isArchive: json['is_archive'] as bool? ?? false,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toSet() ?? {},
);

Map<String, dynamic> _$GroupFileToJson(GroupFile instance) => <String, dynamic>{
  'group': instance.group.toJson(),
  'created': instance.created,
  'last_active': instance.lastActive,
  'is_archive': instance.isArchive,
  'tags': instance.tags.toList(),
};
