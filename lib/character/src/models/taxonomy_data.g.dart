// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'taxonomy_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaxonomyData _$TaxonomyDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TaxonomyData', json, ($checkedConvert) {
      final val = TaxonomyData(
        groups: $checkedConvert(
          'groups',
          (v) => (v as List<dynamic>)
              .map((e) => TaxonomyGroup.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        tags: $checkedConvert(
          'tags',
          (v) => (v as List<dynamic>)
              .map((e) => TaxonomyTag.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TaxonomyDataToJson(TaxonomyData instance) =>
    <String, dynamic>{
      'groups': instance.groups.map((e) => e.toJson()).toList(),
      'tags': instance.tags.map((e) => e.toJson()).toList(),
    };
