import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/nodes/node_scope_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_type_enum.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// Holds the active nodes for one session plus per-type pressure.
/// Mutated by the per-turn tick and by firing. Firing logic itself
/// lives outside this class (step 5).
class NodePool {
  NodePool();

  /// All nodes currently in the pool, regardless of eligibility.
  final List<Node> active = [];

  /// Every authored node by id, including ones not yet in the pool.
  /// Firing resolves a node's `spawnIds` against this so a spawned node
  /// can be dropped into the pool even though it was never seeded.
  /// Filled once at session open via [registerAuthored].
  final Map<String, Node> authoredById = {};

  /// Records an authored node so firing can resolve spawn links to it.
  /// Independent of [add]: a node can be registered (spawnable) without
  /// being seeded into the pool at start.
  void registerAuthored(Node node) {
    authoredById[node.id] = node;
  }

  /// Pressure per node type. Cleared to 0 by [resetPressure]; bounded
  /// at [pressureCap] by [incrementPressure].
  final Map<NodeTypeEnum, double> _pressure = {
    for (final t in NodeTypeEnum.values) t: 0.0,
  };

  /// Adds a node. Caller (director, authored loader, or spawn handler)
  /// supplies it with its initial runtime values already set by [Node]'s
  /// constructor.
  void add(Node node) {
    active.add(node);
  }

  /// One-turn countdown step. Decrements every node's `current*`
  /// counter that is positive; removes nodes whose `alive` has reached
  /// zero. Sticky and alive `-1` sentinels are left untouched
  /// (permanent / no-TTL).
  void tick() {
    for (final n in active) {
      if (n.currentDelay > 0) n.currentDelay--;
      if (n.currentCooldown > 0) n.currentCooldown--;
      if (n.currentSticky > 0) n.currentSticky--;
      if (n.currentAlive > 0) n.currentAlive--;
    }
    active.removeWhere((n) => n.alive != -1 && n.currentAlive == 0);
  }

  /// Removes every node whose [Node.scope] matches [scope]. Called by
  /// the engine after a phase or scene transition.
  void removeByScope(NodeScopeEnum scope) {
    active.removeWhere((n) => n.scope == scope);
  }

  /// Current pressure for [type] (0.0..[pressureCap]).
  double pressureFor(NodeTypeEnum type) => _pressure[type] ?? 0.0;

  /// Bumps pressure for [type] toward [pressureCap]. Called for every
  /// pool that had no firing this turn.
  void incrementPressure(
    NodeTypeEnum type, {
    double step = pressureIncrementPerTurn,
  }) {
    final current = _pressure[type] ?? 0.0;
    final next = current + step;
    _pressure[type] = next > pressureCap ? pressureCap : next;
  }

  /// Resets pressure for [type] back to 0. Called for the pool that
  /// just fired a node.
  void resetPressure(NodeTypeEnum type) {
    _pressure[type] = 0.0;
  }
}
