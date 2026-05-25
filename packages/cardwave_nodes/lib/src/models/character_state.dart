import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:cardwave_nodes/src/models/tracked_value.dart';
import 'package:json_annotation/json_annotation.dart';

part 'character_state.g.dart';

/// All per-character session-state. Keyed in `SessionState.characters` by
/// character id (one entry for 1:1 chats; one per participant in groups).
@JsonSerializable(explicitToJson: true)
class CharacterState {
  CharacterState({
    Map<EmotionEnum, TrackedValue>? emotion,
    Map<PhysicalEnum, TrackedValue>? physical,
    Map<RelationshipEnum, TrackedValue>? relationship,
    Map<String, KnowledgeRecord>? knowledge,
    Map<String, Object?>? flags,
  })  : emotion = emotion ?? _initEnumMap(EmotionEnum.values),
        physical = physical ?? _initEnumMap(PhysicalEnum.values),
        relationship = relationship ?? _initEnumMap(RelationshipEnum.values),
        knowledge = knowledge ?? {},
        flags = flags ?? {};

  factory CharacterState.fromJson(Map<String, dynamic> json) =>
      _$CharacterStateFromJson(json);

  final Map<EmotionEnum, TrackedValue> emotion;
  final Map<PhysicalEnum, TrackedValue> physical;
  final Map<RelationshipEnum, TrackedValue> relationship;
  final Map<String, KnowledgeRecord> knowledge;
  final Map<String, Object?> flags;

  Map<String, dynamic> toJson() => _$CharacterStateToJson(this);

  static Map<E, TrackedValue> _initEnumMap<E extends Enum>(List<E> values) =>
      {for (final value in values) value: TrackedValue()};
}
