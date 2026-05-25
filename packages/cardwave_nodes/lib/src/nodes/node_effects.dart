import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/models/phase_enum.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'node_effects.g.dart';

/// What happens to state when a node fires. Delta maps are keyed by
/// character id (outer) then field name (inner) to match the namespace
/// `character.<id>.xxx`.
@JsonSerializable(explicitToJson: true)
class NodeEffects {
  NodeEffects({
    Map<String, Map<EmotionEnum, double>>? emotionDeltas,
    Map<String, Map<PhysicalEnum, double>>? physicalDeltas,
    Map<String, Map<RelationshipEnum, double>>? relationshipDeltas,
    Map<String, Object?>? flagSet,
    this.goalChange,
    this.phaseChange,
    this.sceneTransition = false,
    Map<String, List<KnowledgeRecord>>? knowledgeWrites,
  })  : emotionDeltas = emotionDeltas ?? {},
        physicalDeltas = physicalDeltas ?? {},
        relationshipDeltas = relationshipDeltas ?? {},
        flagSet = flagSet ?? {},
        knowledgeWrites = knowledgeWrites ?? {};

  factory NodeEffects.fromJson(Map<String, dynamic> json) =>
      _$NodeEffectsFromJson(json);

  final Map<String, Map<EmotionEnum, double>> emotionDeltas;
  final Map<String, Map<PhysicalEnum, double>> physicalDeltas;
  final Map<String, Map<RelationshipEnum, double>> relationshipDeltas;
  final Map<String, Object?> flagSet;
  final String? goalChange;
  final PhaseEnum? phaseChange;
  final bool sceneTransition;
  final Map<String, List<KnowledgeRecord>> knowledgeWrites;

  Map<String, dynamic> toJson() => _$NodeEffectsToJson(this);
}
