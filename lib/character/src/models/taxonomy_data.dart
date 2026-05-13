import 'package:cardwave/character/src/models/taxonomy_group.dart';
import 'package:cardwave/character/src/models/taxonomy_tag.dart';
import 'package:json_annotation/json_annotation.dart';

part 'taxonomy_data.g.dart';

/// JSON wrapper for the on-disk taxonomy file. Holds a flat list of
/// [TaxonomyGroup] records (forming a tree via parent_group_id) and a flat
/// list of [TaxonomyTag] records (each pointing to its owning group).
@JsonSerializable(checked: true, explicitToJson: true)
class TaxonomyData {
  TaxonomyData({required this.groups, required this.tags});

  factory TaxonomyData.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyDataFromJson(json);

  List<TaxonomyGroup> groups;
  List<TaxonomyTag> tags;

  Map<String, dynamic> toJson() => _$TaxonomyDataToJson(this);
}
