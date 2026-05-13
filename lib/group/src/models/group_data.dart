import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/group/src/models/chat_group.dart' show ChatGroup;
import 'package:cardwave/group/src/models/group_file.dart' show GroupFile;
import 'package:json_annotation/json_annotation.dart';

part 'group_data.g.dart';

/// Per-chat-session group state. Non-null on a [ChatSession] marks that
/// session as a group chat. Holds state that varies between different chat
/// sessions of the same group — overrides and muted members. The group's
/// stable identity (name, full member list) lives on [GroupFile]/[ChatGroup].
///
/// Override strings: a non-null, non-whitespace value replaces the speaker's
/// card field during prompt building; null or empty falls through to the
/// card value.
@JsonSerializable()
class GroupData {
  GroupData({
    this.overrideScenario,
    this.overrideSystemPrompt,
    this.overrideMesExample,
    List<String>? mutedMemberAppCardIds,
  }) : mutedMemberAppCardIds = mutedMemberAppCardIds ?? [];

  factory GroupData.fromJson(Map<String, dynamic> json) =>
      _$GroupDataFromJson(json);
  String? overrideScenario;

  String? overrideSystemPrompt;

  String? overrideMesExample;

  /// appCardIds of members silenced in this chat session only.
  /// Does not affect other chat sessions of the same group.
  @JsonKey(defaultValue: [])
  List<String> mutedMemberAppCardIds;

  Map<String, dynamic> toJson() => _$GroupDataToJson(this);
}
