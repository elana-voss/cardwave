import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_nodes_state.g.dart';

/// What persists per chat for the NODES engine: the [SessionState]
/// (emotions, scene, goal, event log, flags, knowledge) plus the
/// pool's active nodes (carrying their current delay / cooldown /
/// sticky / alive counters so a resumed session continues mid-flight).
///
/// Pool pressure is intentionally NOT persisted — a few quiet turns
/// rebuild it, and skipping it keeps the [NodePool] API unchanged.
/// Authored nodes are re-seeded from the card extension on session
/// open, so a fresh chat starts with [activeNodes] empty.
@JsonSerializable(explicitToJson: true)
class ChatNodesState {
  ChatNodesState({SessionState? state, List<Node>? activeNodes})
    : state = state ?? SessionState(),
      activeNodes = activeNodes ?? [];

  factory ChatNodesState.fromJson(Map<String, dynamic> json) =>
      _$ChatNodesStateFromJson(json);

  final SessionState state;
  final List<Node> activeNodes;

  Map<String, dynamic> toJson() => _$ChatNodesStateToJson(this);
}
