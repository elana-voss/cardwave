// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TreeNode _$TreeNodeFromJson(Map<String, dynamic> json) => TreeNode(
  id: json['id'] as String,
  level: $enumDecode(_$TreeLevelEnumEnumMap, json['level']),
  parentId: json['parent_id'] as String?,
  childIds:
      (json['child_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  messageIds:
      (json['message_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  summary: json['summary'] as String? ?? '',
  eventIds:
      (json['event_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$TreeNodeToJson(TreeNode instance) => <String, dynamic>{
  'id': instance.id,
  'level': _$TreeLevelEnumEnumMap[instance.level]!,
  'parent_id': instance.parentId,
  'child_ids': instance.childIds,
  'message_ids': instance.messageIds,
  'summary': instance.summary,
  'event_ids': instance.eventIds,
};

const _$TreeLevelEnumEnumMap = {
  TreeLevelEnum.book: 'book',
  TreeLevelEnum.part: 'part',
  TreeLevelEnum.chapter: 'chapter',
  TreeLevelEnum.scene: 'scene',
  TreeLevelEnum.eventTurn: 'eventTurn',
};
