import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/scene.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:json_annotation/json_annotation.dart';

part 'card_nodes_extension.g.dart';

/// Contents of the `cardwave_nodes` block inside a SillyTavern v3 card's
/// `extensions` field. Loaded at session start and consumed by the
/// session bootstrapper:
///   - [authoredNodes] are seeded into the pool with fresh countdowns
///   - [emotionBaseline] becomes each character's starting emotion vector
///   - [initialGoal] becomes [SessionState.currentGoal] for the first turn
///   - [initialScene] is the starting `currentScene` if present
///
/// All fields optional — a card with no `cardwave_nodes` extension still
/// works (the pool stays empty, baseline is all zeros, goal is empty,
/// scene starts empty).
@JsonSerializable(explicitToJson: true)
class CardNodesExtension {
  CardNodesExtension({
    List<Node>? authoredNodes,
    Map<EmotionEnum, double>? emotionBaseline,
    this.initialGoal = '',
    this.initialScene,
  })  : authoredNodes = authoredNodes ?? [],
        emotionBaseline = emotionBaseline ?? {};

  factory CardNodesExtension.fromJson(Map<String, dynamic> json) =>
      _$CardNodesExtensionFromJson(json);

  final List<Node> authoredNodes;
  final Map<EmotionEnum, double> emotionBaseline;
  final String initialGoal;
  @JsonKey(includeIfNull: false)
  final Scene? initialScene;

  Map<String, dynamic> toJson() => _$CardNodesExtensionToJson(this);
}
