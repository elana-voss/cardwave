import 'dart:typed_data';

import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_memory/src/models/scene_beat_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'story_event.g.dart';

/// One atomic story event extracted from a window of chat messages.
///
/// Story-time validity ([validFrom]/[validUntil]) and record-time provenance
/// ([recordedAt]/[supersededAt]) are kept separate — Graphiti's
/// four-timestamp model — so a superseded fact drops out of normal retrieval
/// yet stays recallable for "remember when…" questions. [messageIds] points
/// one way into the chat log (the source of truth never points back), so the
/// whole event can be rebuilt or discarded without touching chat data.
@JsonSerializable(explicitToJson: true)
class StoryEvent {
  StoryEvent({
    required this.id,
    required this.recordedAt,
    required this.text,
    required this.contextualPrefix,
    this.messageIds = const [],
    this.validFrom,
    this.validUntil,
    this.supersededAt,
    this.beat,
    this.characterEmotion = EmotionLabelEnum.neutral,
    this.userEmotion = EmotionLabelEnum.neutral,
    this.importance = 0,
    this.linkedEventIds = const [],
    this.characters = const [],
    this.locations = const [],
    this.items = const [],
    this.concepts = const [],
    this.keywords = const [],
    this.vector,
  });

  factory StoryEvent.fromJson(Map<String, dynamic> json) =>
      _$StoryEventFromJson(json);

  final String id;

  @JsonKey(defaultValue: '')
  final String text;

  /// One-line situating sentence prepended to [text] before embedding
  /// (Anthropic contextual retrieval).
  @JsonKey(defaultValue: '')
  final String contextualPrefix;

  final List<String> messageIds;

  /// Story time the fact became / stopped being true (epoch ms); null when
  /// unknown or still true.
  final int? validFrom;
  final int? validUntil;

  /// Record time the system learned the fact. [supersededAt] is stamped when
  /// a later event contradicts it, and is null while the fact is current.
  final int recordedAt;
  final int? supersededAt;

  final SceneBeatEnum? beat;
  final EmotionLabelEnum characterEmotion;
  final EmotionLabelEnum userEmotion;
  final int importance;

  /// Lateral links to related events across the tree (callbacks, cause
  /// chains) — the additive-links model, never deletions.
  final List<String> linkedEventIds;

  final List<String> characters;
  final List<String> locations;
  final List<String> items;
  final List<String> concepts;
  final List<String> keywords;

  /// Dense embedding of the contextual-prefixed [text]. Lives in the binary
  /// sidecar, never JSON; restored after load via `MemoryGraph.restoreVectors`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  Float32List? vector;

  Map<String, dynamic> toJson() => _$StoryEventToJson(this);
}
