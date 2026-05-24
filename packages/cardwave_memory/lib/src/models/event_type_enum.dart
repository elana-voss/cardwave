import 'package:json_annotation/json_annotation.dart';

/// The kind of story moment a [StoryEvent] records, tuned for casual roleplay
/// rather than RPG play. Constants are camelCase; [wireName] (and JSON, via the
/// snake rename) is the snake_case form the extraction model sees and returns.
/// [description] is the one-line definition handed to the model so it classifies
/// consistently; it is the single source for those definitions.
@JsonEnum(fieldRename: FieldRename.snake)
enum EventTypeEnum {
  meeting,
  relationshipChange,
  conflict,
  reconciliation,
  separation,
  intimacy,
  promise,
  betrayal,
  revelation,
  discovery,
  locationChange,
  injuryOrIllness,
  birth,
  death,
  timeJump,
  lifeEvent,
  conversation,
  other;

  /// The snake_case form used in JSON and in the extraction prompt/schema,
  /// derived from [name] by the same rule the JSON snake rename applies, so the
  /// stored value and the model-facing string never drift.
  String get wireName =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// Maps a model-returned wire string back to a type, falling back to [other]
  /// for anything unrecognised (including the empty string callers use for
  /// a missing field).
  static EventTypeEnum fromWireName(String wire) =>
      values.firstWhere((e) => e.wireName == wire, orElse: () => other);

  /// One-line definition shown to the extraction model.
  String get description => switch (this) {
    EventTypeEnum.meeting =>
      'characters meet, or a new character enters for the first time',
    EventTypeEnum.relationshipChange =>
      'the bond between characters shifts (closer, romantic, estranged, allied)',
    EventTypeEnum.conflict => 'an argument, fight, or hostile confrontation',
    EventTypeEnum.reconciliation => 'characters make up or resolve a conflict',
    EventTypeEnum.separation =>
      'characters part ways, leave, or are forced apart',
    EventTypeEnum.intimacy => 'physical or sexual closeness',
    EventTypeEnum.promise => 'a vow, oath, or commitment is made',
    EventTypeEnum.betrayal => 'a character breaks trust or turns on another',
    EventTypeEnum.revelation =>
      'a secret or important truth is disclosed or learned',
    EventTypeEnum.discovery =>
      'a character finds a place, object, or fact about the world',
    EventTypeEnum.locationChange =>
      'the scene moves to a new place (includes travel)',
    EventTypeEnum.injuryOrIllness => 'a character is hurt or falls sick',
    EventTypeEnum.birth => 'a child is born or arrives',
    EventTypeEnum.death => 'a character dies',
    EventTypeEnum.timeJump =>
      'the story skips a meaningful span of time (days, years)',
    EventTypeEnum.lifeEvent =>
      'a major personal milestone (marriage, moving in together, new job, graduation)',
    EventTypeEnum.conversation =>
      'an important exchange not captured by another type',
    EventTypeEnum.other => 'anything notable fitting no category above',
  };
}
