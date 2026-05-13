import 'package:cardwave/character/character.dart';
import 'package:cardwave/group/src/models/chat_group.dart';
import 'package:json_annotation/json_annotation.dart';

part 'group_file.g.dart';

/// Persistent envelope for a group of characters. Mirrors [CharacterFile]'s
/// role for a character: owns the inner [ChatGroup] (identity + members) and
/// metadata the future Groups grid can use for sort/filter/thumbnail.
///
/// One file per group on disk at `customCacheGroupPath/<id>.json`.
@JsonSerializable(explicitToJson: true)
class GroupFile {
  GroupFile({
    required this.group,
    required this.created,
    required this.lastActive,
    this.isArchive = false,
    Set<String>? tags,
  }) : tags = tags ?? <String>{};

  factory GroupFile.fromJson(Map<String, dynamic> json) =>
      _$GroupFileFromJson(json);
  ChatGroup group;

  int created;

  int lastActive;

  @JsonKey(defaultValue: false)
  bool isArchive;

  @JsonKey(defaultValue: <String>{})
  Set<String> tags;

  /// The group's stable id — delegates to the inner [ChatGroup.id].
  /// Parallels [CharacterFile.appCardId] as the "primary key" of this file.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id => group.id;

  Map<String, dynamic> toJson() => _$GroupFileToJson(this);
}
