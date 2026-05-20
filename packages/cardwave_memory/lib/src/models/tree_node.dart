import 'package:cardwave_memory/src/models/tree_level_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tree_node.g.dart';

/// One node in the story tree. A node at [level] groups the [childIds] one
/// level finer, references the [messageIds] it covers, and (at scene level)
/// the [eventIds] it seals. [summary] is the short description used for
/// arc-level retrieval at part/chapter level.
@JsonSerializable(explicitToJson: true)
class TreeNode {
  const TreeNode({
    required this.id,
    required this.level,
    this.parentId,
    this.childIds = const [],
    this.messageIds = const [],
    required this.summary,
    this.eventIds = const [],
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) =>
      _$TreeNodeFromJson(json);

  final String id;
  final TreeLevelEnum level;
  final String? parentId;

  final List<String> childIds;

  final List<String> messageIds;

  @JsonKey(defaultValue: '')
  final String summary;

  final List<String> eventIds;

  Map<String, dynamic> toJson() => _$TreeNodeToJson(this);
}
