import 'package:json_annotation/json_annotation.dart';

part 'taxonomy_tag.g.dart';

/// One taxonomy tag. Tags are flat within their group — there is no
/// tag-tree. All hierarchy lives in [TaxonomyGroup.parentGroupId].
///
/// [isExclusive] means "this tag belongs to its group's mutually-exclusive
/// subset". Within a group, all exclusive tags form one pick-one set;
/// non-exclusive tags are independent toggles. A group may contain both.
@JsonSerializable(checked: true, explicitToJson: true)
class TaxonomyTag {
  TaxonomyTag({
    required this.tagId,
    required this.tagName,
    required this.tagExplain,
    required this.synonyms,
    required this.groupId,
    required this.isExclusive,
    required this.displayOrder,
  });

  factory TaxonomyTag.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyTagFromJson(json);

  String tagId;
  String tagName;
  String tagExplain;
  List<String> synonyms;
  String groupId;
  bool isExclusive;
  int displayOrder;

  Map<String, dynamic> toJson() => _$TaxonomyTagToJson(this);
}
