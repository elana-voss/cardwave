import 'dart:math';

import 'package:cardwave_nodes/src/engine/value_math.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/models/tracked_value.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/nodes/node_pool.dart';
import 'package:cardwave_nodes/src/nodes/node_scope_enum.dart';
import 'package:cardwave_nodes/src/nodes/node_type_enum.dart';
import 'package:cardwave_nodes/src/observability/firing_log_event.dart';
import 'package:cardwave_nodes/src/observability/firing_logger.dart';
import 'package:cardwave_nodes/src/predicates/predicate_ast.dart';
import 'package:cardwave_nodes/src/predicates/predicate_evaluator.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parser.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// Outcome of one [FiringEngine.runTurn] pass.
typedef FiringResult = ({
  List<Node> fired,
});

/// Runs one firing pass per turn: filter eligible, roll, pick at most
/// one winner per pool, apply effects, update node countdowns and pool
/// pressure. Pool's [NodePool.tick] must run separately before this
/// (decrements countdowns, removes nodes whose alive expired).
class FiringEngine {
  FiringEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Parsed-AST cache keyed by predicate source. Avoids re-parsing on
  /// every evaluation. Filled on demand as nodes are seen.
  final Map<String, PredicateNode> _predicateCache = {};

  FiringResult runTurn(NodePool pool, SessionState state) {
    final skipped = <NodeSkipRecord>[];
    final rolled = <NodeRollRecord>[];
    final firedRecords = <NodeFireRecord>[];
    final winnersByPool = _rollEligible(pool, state, skipped, rolled);
    final fired = <Node>[];
    for (final type in NodeTypeEnum.values) {
      final winners = winnersByPool[type] ?? const [];
      if (winners.isEmpty) {
        pool.incrementPressure(type);
        continue;
      }
      final chosen = _weightedPick(winners, (n) => n.triggerProb);
      _fireNode(chosen, pool, state);
      fired.add(chosen);
      firedRecords.add(NodeFireRecord(
        nodeId: chosen.id,
        narrativePayload: chosen.narrativePayload,
      ));
      pool.resetPressure(type);
    }
    logTurnFiring(TurnFiringEvent(
      turn: state.turn,
      skipped: skipped,
      rolled: rolled,
      fired: firedRecords,
    ));
    return (fired: fired);
  }

  Map<NodeTypeEnum, List<Node>> _rollEligible(
    NodePool pool,
    SessionState state,
    List<NodeSkipRecord> skipped,
    List<NodeRollRecord> rolled,
  ) {
    final winners = <NodeTypeEnum, List<Node>>{
      for (final t in NodeTypeEnum.values) t: [],
    };
    for (final node in pool.active) {
      if (node.currentDelay > 0) {
        skipped.add(NodeSkipRecord(
          nodeId: node.id,
          reason: NodeSkipReason.delayActive,
        ));
        continue;
      }
      if (node.currentCooldown > 0) {
        skipped.add(NodeSkipRecord(
          nodeId: node.id,
          reason: NodeSkipReason.cooldownActive,
        ));
        continue;
      }
      final predicate = _predicateCache[node.predicate] ??=
          parsePredicate(node.predicate);
      if (!evaluatePredicate(predicate, state)) {
        skipped.add(NodeSkipRecord(
          nodeId: node.id,
          reason: NodeSkipReason.predicateFalse,
        ));
        continue;
      }
      final pressure = pool.pressureFor(node.type);
      final effective = (node.triggerProb + pressure).clamp(0.0, 1.0);
      final draw = _random.nextDouble();
      final won = draw < effective;
      rolled.add(NodeRollRecord(
        nodeId: node.id,
        triggerProb: node.triggerProb,
        pressure: pressure,
        draw: draw,
        won: won,
      ));
      if (won) {
        winners[node.type]!.add(node);
      }
    }
    return winners;
  }

  T _weightedPick<T>(List<T> items, double Function(T) weight) {
    assert(items.isNotEmpty, '_weightedPick requires a non-empty list');
    final total = items.fold<double>(0, (sum, it) => sum + weight(it));
    if (total <= 0) {
      // ignore: qcheck/avoid_unsafe_collection_methods
      return items.first;
    }
    final pick = _random.nextDouble() * total;
    var acc = 0.0;
    for (final item in items) {
      acc += weight(item);
      if (pick < acc) return item;
    }
    // Floating-point rounding can leave `acc` a hair below `pick`. Caller
    // guarantees items is non-empty (assert above).
    // ignore: qcheck/avoid_unsafe_collection_methods
    return items.last;
  }

  void _fireNode(Node node, NodePool pool, SessionState state) {
    _applyEffectsToState(node, state);
    _setCooldownAndSticky(node);
    _addSpawnsToPool(node, pool);
    if (node.scope == NodeScopeEnum.oneShot) {
      pool.active.remove(node);
    }
  }

  void _applyEffectsToState(Node node, SessionState state) {
    final effects = node.effects;
    effects.emotionDeltas.forEach((characterId, deltas) {
      final character = state.characters[characterId];
      if (character == null) return;
      deltas.forEach((emotion, delta) {
        final value = character.emotion[emotion];
        if (value == null) return;
        final outcome = applyDelta(value, delta);
        if (outcome.shouldLockOpposite) {
          final opposite = character.emotion[emotion.opposite];
          if (opposite != null) setLockout(opposite, lockoutDurationTurns);
        }
      });
    });
    effects.physicalDeltas.forEach((characterId, deltas) {
      _applyEnumDeltas(state.characters[characterId]?.physical, deltas);
    });
    effects.relationshipDeltas.forEach((characterId, deltas) {
      _applyEnumDeltas(state.characters[characterId]?.relationship, deltas);
    });
    state.flags.addAll(effects.flagSet);
    final goalChange = effects.goalChange;
    if (goalChange != null) state.currentGoal = goalChange;
    final phaseChange = effects.phaseChange;
    if (phaseChange != null) state.currentPhase = phaseChange;
    effects.knowledgeWrites.forEach((characterId, records) {
      final character = state.characters[characterId];
      if (character == null) return;
      for (final record in records) {
        character.knowledge[record.topic] = record;
      }
    });
  }

  void _applyEnumDeltas<E extends Enum>(
    Map<E, TrackedValue>? trackedMap,
    Map<E, double> deltas,
  ) {
    if (trackedMap == null) return;
    deltas.forEach((key, delta) {
      final value = trackedMap[key];
      if (value == null) return;
      applyDelta(value, delta);
    });
  }

  void _setCooldownAndSticky(Node node) {
    node.currentCooldown = node.cooldown < 0 ? 0 : node.cooldown;
    node.currentSticky = node.sticky;
  }

  void _addSpawnsToPool(Node parent, NodePool pool) {
    for (final spawn in parent.spawns) {
      final fresh = Node.fromJson(spawn.toJson())
        ..currentDelay = spawn.delay < 0 ? 0 : spawn.delay
        ..currentCooldown = 0
        ..currentSticky = 0
        ..currentAlive = spawn.alive;
      pool.add(fresh);
    }
  }
}

