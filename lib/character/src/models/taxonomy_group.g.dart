// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxonomyGroup _$TaxonomyGroupFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'TaxonomyGroup',
  json,
  ($checkedConvert) {
    final val = TaxonomyGroup(
      groupId: $checkedConvert('group_id', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String),
      parentGroupId: $checkedConvert('parent_group_id', (v) => v as String?),
      displayOrder: $checkedConvert('display_order', (v) => (v as num).toInt()),
      groupExplain: $checkedConvert('group_explain', (v) => v as String? ?? ''),
    );
    return val;
  },
  fieldKeyMap: const {
    'groupId': 'group_id',
    'parentGroupId': 'parent_group_id',
    'displayOrder': 'display_order',
    'groupExplain': 'group_explain',
  },
);

Map<String, dynamic> _$TaxonomyGroupToJson(TaxonomyGroup instance) =>
    <String, dynamic>{
      'group_id': instance.groupId,
      'name': instance.name,
      'parent_group_id': instance.parentGroupId,
      'display_order': instance.displayOrder,
      'group_explain': instance.groupExplain,
    };
