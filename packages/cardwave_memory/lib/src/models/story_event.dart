import 'dart:typed_data';

import 'package:cardwave_emotion/cardwave_emotion.dart';
import 'package:cardwave_memory/src/models/event_type_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'story_event.g.dart';

/// One atomic story event extracted from a window of chat messages — a "what
/// happened" moment. Events are append-only: an event that happened stays
/// happened, so it is never superseded; only reconcile (an edit or deletion of
/// its source messages) removes it. Current-state validity lives on
/// [MemoryFact], not here. [messageIds] points one way into the chat log (the
/// source of truth never points back), so the whole event can be rebuilt or
/// discarded without touching chat data.
@JsonSerializable(explicitToJson: true)
class StoryEvent {
  StoryEvent({
    required this.id,
    required this.recordedAt,
    required this.text,
    required this.contextualPrefix,
    this.eventType = EventTypeEnum.other,
    this.cause = '',
    this.effect = '',
    this.messageIds = const [],
    this.characterEmotion = EmotionLabelEnum.neutral,
    this.userEmotion = EmotionLabelEnum.neutral,
    this.importance = 0,
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

  /// The kind of story moment this is. Display + ranking only; not embedded.
  final EventTypeEnum eventType;

  /// Why it happened and what came of it — free text, may be empty. Sent in the
  /// prompt under the event; not embedded or keyword-indexed.
  @JsonKey(defaultValue: '')
  final String cause;

  @JsonKey(defaultValue: '')
  final String effect;

  final List<String> messageIds;

  /// Record time the system extracted this event (epoch ms).
  final int recordedAt;

  final EmotionLabelEnum characterEmotion;
  final EmotionLabelEnum userEmotion;
  final int importance;

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
