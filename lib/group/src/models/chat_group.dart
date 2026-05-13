import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_group.g.dart';

/// The persistent identity of a group of characters. Analog of
/// [CharacterCardV3] for a character: owns the group's name and the ordered
/// list of member character ids. Multiple [ChatSession]s may exist under the
/// same group over time; this object is shared across all of them.
@JsonSerializable()
class ChatGroup {
  ChatGroup({
    required this.id,
    required this.name,
    List<String>? memberAppCardIds,
  }) : memberAppCardIds = memberAppCardIds ?? [];

  factory ChatGroup.fromJson(Map<String, dynamic> json) =>
      _$ChatGroupFromJson(json);
  final String id;
  String name;

  @JsonKey(defaultValue: [])
  List<String> memberAppCardIds;

  Map<String, dynamic> toJson() => _$ChatGroupToJson(this);
}
