import 'package:cardwave_nodes/src/nodes/node_effects.dart';
import 'package:cardwave_nodes/src/nodes/node_origin_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_scope_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_type_enum.dart';
import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

/// One beat in the pool. Holds both the authoring fields (initial
/// countdown values, scope, predicate, payload, effects, spawns) and the
/// per-turn runtime state (currentDelay, currentCooldown, currentSticky,
/// currentAlive) so the pool's tick can decrement in place and the whole
/// shape round-trips through JSON.
///
/// `-1` semantics by field:
///   - delay: literal; -1 treated as 0
///   - cooldown: -1 means "no cooldown" (equivalent to 0)
///   - sticky: -1 means "permanent sticky" (never decremented)
///   - alive: -1 means "no time-to-live" (never expires by alive)
@JsonSerializable(explicitToJson: true)
class Node {
  Node({
    required this.id,
    required this.origin,
    required this.type,
    required this.triggerProb,
    required this.delay,
    required this.cooldown,
    required this.sticky,
    required this.alive,
    required this.scope,
    required this.predicate,
    required this.narrativePayload,
    NodeEffects? effects,
    List<Node>? spawns,
    int? currentDelay,
    int? currentCooldown,
    int? currentSticky,
    int? currentAlive,
  })  : effects = effects ?? NodeEffects(),
        spawns = spawns ?? [],
        currentDelay = currentDelay ?? (delay < 0 ? 0 : delay),
        currentCooldown = currentCooldown ?? 0,
        currentSticky = currentSticky ?? 0,
        currentAlive = currentAlive ?? alive;

  factory Node.fromJson(Map<String, dynamic> json) => _$NodeFromJson(json);

  final String id;
  final NodeOriginEnum origin;
  final NodeTypeEnum type;
  final double triggerProb;

  // Initial values (authoring intent).
  final int delay;
  final int cooldown;
  final int sticky;
  final int alive;

  final NodeScopeEnum scope;

  /// Source text of the boolean expression that gates eligibility. The
  /// firing logic parses and caches the AST per pool entry.
  final String predicate;

  final String narrativePayload;
  final NodeEffects effects;
  final List<Node> spawns;

  // Runtime values (mutated by the pool's tick and by firing).
  int currentDelay;
  int currentCooldown;
  int currentSticky;
  int currentAlive;

  Map<String, dynamic> toJson() => _$NodeToJson(this);
}
