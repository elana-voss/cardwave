// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxonomyTag _$TaxonomyTagFromJson(Map<String, dynamic> json) => $checkedCreate(
  'TaxonomyTag',
  json,
  ($checkedConvert) {
    final val = TaxonomyTag(
      tagId: $checkedConvert('tag_id', (v) => v as String),
      tagName: $checkedConvert('tag_name', (v) => v as String),
      tagExplain: $checkedConvert('tag_explain', (v) => v as String),
      synonyms: $checkedConvert(
        'synonyms',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      groupId: $checkedConvert('group_id', (v) => v as String),
      isExclusive: $checkedConvert('is_exclusive', (v) => v as bool),
      displayOrder: $checkedConvert('display_order', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'tagId': 'tag_id',
    'tagName': 'tag_name',
    'tagExplain': 'tag_explain',
    'groupId': 'group_id',
    'isExclusive': 'is_exclusive',
    'displayOrder': 'display_order',
  },
);

Map<String, dynamic> _$TaxonomyTagToJson(TaxonomyTag instance) =>
    <String, dynamic>{
      'tag_id': instance.tagId,
      'tag_name': instance.tagName,
      'tag_explain': instance.tagExplain,
      'synonyms': instance.synonyms,
      'group_id': instance.groupId,
      'is_exclusive': instance.isExclusive,
      'display_order': instance.displayOrder,
    };
