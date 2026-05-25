import 'package:cardwave_nodes/src/director/event_log_append.dart';
import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:json_annotation/json_annotation.dart';

part 'director_output.g.dart';

/// The single JSON object the director returns per turn. All fields
/// optional; missing or empty fields mean "no change in that area."
/// The director does NOT write goal, phase, or scene context — those
/// change only as effects of fired node specs in [generatedNodes].
@JsonSerializable(explicitToJson: true)
class DirectorOutput {
  DirectorOutput({
    Map<String, Map<EmotionEnum, double>>? emotionDeltas,
    Map<String, Map<PhysicalEnum, double>>? physicalDeltas,
    Map<String, Map<RelationshipEnum, double>>? relationshipDeltas,
    Map<String, Object?>? flagSet,
    Map<String, List<KnowledgeRecord>>? knowledgeWrites,
    List<String>? directiveLines,
    List<Node>? generatedNodes,
    List<EventLogAppend>? eventLogAppend,
  })  : emotionDeltas = emotionDeltas ?? {},
        physicalDeltas = physicalDeltas ?? {},
        relationshipDeltas = relationshipDeltas ?? {},
        flagSet = flagSet ?? {},
        knowledgeWrites = knowledgeWrites ?? {},
        directiveLines = directiveLines ?? [],
        generatedNodes = generatedNodes ?? [],
        eventLogAppend = eventLogAppend ?? [];

  factory DirectorOutput.fromJson(Map<String, dynamic> json) =>
      _$DirectorOutputFromJson(json);

  final Map<String, Map<EmotionEnum, double>> emotionDeltas;
  final Map<String, Map<PhysicalEnum, double>> physicalDeltas;
  final Map<String, Map<RelationshipEnum, double>> relationshipDeltas;
  final Map<String, Object?> flagSet;
  final Map<String, List<KnowledgeRecord>> knowledgeWrites;
  final List<String> directiveLines;
  final List<Node> generatedNodes;
  final List<EventLogAppend> eventLogAppend;

  Map<String, dynamic> toJson() => _$DirectorOutputToJson(this);
}
