import 'package:cardwave/chat/src/models/chat_session.dart' show ChatSession;
import 'package:json_annotation/json_annotation.dart';

part 'chat_index.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatIndex {
  ChatIndex({required this.entries});

  factory ChatIndex.fromJson(Map<String, dynamic> json) =>
      _$ChatIndexFromJson(json);
  @JsonKey(defaultValue: [])
  List<ChatIndexEntry> entries;
  Map<String, dynamic> toJson() => _$ChatIndexToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ChatIndexEntry {
  ChatIndexEntry({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.lastActive,
    required this.messageCount,
    this.isAssistant = false,
  });

  factory ChatIndexEntry.fromJson(Map<String, dynamic> json) =>
      _$ChatIndexEntryFromJson(json);
  final String id;

  /// See [ChatSession.ownerId].
  final String ownerId;
  String name;
  @JsonKey(defaultValue: 0)
  final int lastActive;
  @JsonKey(defaultValue: 0)
  final int messageCount;

  /// Mirrors [ChatSession.isAssistant] so the chat-list loader can
  /// filter without reading every chat file. False for the regular 1:1
  /// chat, true for the editor's assistant chat.
  @JsonKey(defaultValue: false)
  final bool isAssistant;

  Map<String, dynamic> toJson() => _$ChatIndexEntryToJson(this);
}
