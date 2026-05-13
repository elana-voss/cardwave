import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_session.g.dart';

@JsonSerializable(explicitToJson: true)
class ChatSession {
  ChatSession({
    required this.id,
    required this.ownerId,
    required this.modelPresetId,
    required this.created,
    required this.lastActive,
    required this.name,
    required this.isStreaming,
    required this.isNsfw,
    required this.isScenario,
    required this.removeTrailingSentences,
    required this.personaName,
    required this.personaDescription,
    required this.activeStickies,
    required this.activeCooldowns,
    required this.localVariables,
    this.groupData,
    this.backgroundImage,
    this.isAssistant = false,
    this.configMedia,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
  final String id;

  /// Stable id of the owning entity.
  /// - For 1:1 chats: a [CharacterFile.appCardId].
  /// - For group chats: a [GroupFile.id] (== [ChatGroup.id]).
  /// Discriminated by whether [groupData] is non-null.
  final String ownerId;

  String modelPresetId;

  /// Session-layer media settings — every per-domain preset / aspect /
  /// resolution / voice / language, NSFW gates, tool flags, and prompt
  /// review flags the chat drawer surfaces. Null when the user has not
  /// touched any media setting in this chat. See [ConfigMediaSession]
  /// for the field set; [resolveMedia] merges with the character and
  /// app layers at play time.
  @JsonKey(includeIfNull: false)
  ConfigMediaSession? configMedia;

  final int created;
  int lastActive;
  String name;
  bool isStreaming;
  bool isNsfw;
  bool isScenario;
  bool removeTrailingSentences;
  String personaName;
  String personaDescription;
  List<ChatMessage> messages;

  /// Tracks active sticky effects for Lorebook entries.
  /// Key: Lorebook Entry ID (as a String for JSON compatibility).
  /// Value: The absolute chat message length at which the sticky effect expires.
  @JsonKey(defaultValue: {})
  Map<String, int> activeStickies;

  /// Tracks active cooldown effects for Lorebook entries.
  /// Key: Lorebook Entry ID (as a String for JSON compatibility).
  /// Value: The absolute chat message length at which the cooldown effect expires.
  @JsonKey(defaultValue: {})
  Map<String, int> activeCooldowns;

  /// Chat-scoped local variables used by the macro engine.
  @JsonKey(defaultValue: {})
  Map<String, String> localVariables;

  /// Per-chat group state (null for 1:1 chats).
  @JsonKey(includeIfNull: false)
  GroupData? groupData;

  /// Relative path (cards-domain) to a generated image used as chat background.
  @JsonKey(includeIfNull: false)
  String? backgroundImage;

  /// True when this chat is the assistant chat for an editor split view
  /// (Editor + Assistant Chat side-by-side). False for the regular 1:1
  /// chat shown in the chat window. Persisted on the index entry so the
  /// loader can return only the right kind for each surface — without
  /// this filter, re-entering the regular 1:1 chat could pick up a more
  /// recently active assistant chat instead.
  @JsonKey(defaultValue: false)
  bool isAssistant;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isGroup => groupData != null;
  Map<String, dynamic> toJson() => _$ChatSessionToJson(this);
}
