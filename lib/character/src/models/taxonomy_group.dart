import 'package:json_annotation/json_annotation.dart';

part 'taxonomy_group.g.dart';

/// One taxonomy group. Groups form a tree via [parentGroupId] (null = top
/// level). Each tag references its group via [TaxonomyTag.groupId]; tags
/// stay flat inside their group.
///
/// A group may have direct tags AND child groups simultaneously
/// (e.g. Source Material has direct tags Original Character / Pop Culture
/// alongside sub-groups Established IP / Real Person Fiction).
@JsonSerializable(checked: true, explicitToJson: true)
class TaxonomyGroup {
  TaxonomyGroup({
    required this.groupId,
    required this.name,
    required this.parentGroupId,
    required this.displayOrder,
    required this.groupExplain,
  });

  factory TaxonomyGroup.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyGroupFromJson(json);

  String groupId;
  String name;
  String? parentGroupId;
  int displayOrder;

  /// Optional human-friendly description of what this group covers. Empty
  /// string means "no explanation set." Surfaced in the LLM auto-tag prompt
  /// (and editor UI) to disambiguate group meaning beyond its display name.
  @JsonKey(defaultValue: '')
  String groupExplain;

  Map<String, dynamic> toJson() => _$TaxonomyGroupToJson(this);
}
