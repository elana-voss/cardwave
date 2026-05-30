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
import 'package:cardwave_nodes/src/observability/state_change_record.dart';
import 'package:cardwave_nodes/src/predicates/predicate_ast.dart';
import 'package:cardwave_nodes/src/predicates/predicate_evaluator.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parser.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// Outcome of one [FiringEngine.runTurn] pass.
typedef FiringResult = ({
  List<Node> fired,
});

/// Outcome of `_rollEligible`: per-type winners pulled off the pool,
/// plus the per-node skip/roll records the engine then bundles into a
/// [TurnFiringEvent] for the host.
typedef _RollResult = ({
  Map<NodeTypeEnum, List<Node>> winners,
  List<NodeSkipRecord> skipped,
  List<NodeRollRecord> rolled,
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

  /// Runs decay+lockout-tick across every tracked value, rolls the
  /// pool, fires at most one winner per type, applies effects.
  ///
  /// [changeLog] is optional; when supplied, every mutation (decay,
  /// delta, flag write, goal/phase change, knowledge write) is
  /// captured as a [StateChangeRecord] for the debug panel.
  FiringResult runTurn(
    NodePool pool,
    SessionState state, {
    StateChangeLog? changeLog,
  }) {
    _decayAndTickLockouts(state, changeLog);
    final roll = _rollEligible(pool, state);
    final fired = <Node>[];
    for (final type in NodeTypeEnum.values) {
      final winners = roll.winners[type] ?? const [];
      if (winners.isEmpty) {
        pool.incrementPressure(type);
        continue;
      }
      final chosen = _weightedPick(winners, (n) => n.triggerProb);
      _fireNode(chosen, pool, state, changeLog);
      fired.add(chosen);
      pool.resetPressure(type);
    }
    logTurnFiring(TurnFiringEvent(
      turn: state.turn,
      skipped: roll.skipped,
      rolled: roll.rolled,
      fired: [
        for (final node in fired)
          NodeFireRecord(
            nodeId: node.id,
            narrativePayload: node.narrativePayload,
          ),
      ],
    ));
    return (fired: fired);
  }

  /// Per-spec §3.1/§3.2: every tracked value fades a little each turn
  /// (`applyDecay`) and the lockout countdown decrements
  /// (`tickLockout`). Runs once at the start of every turn, before
  /// firing rolls — so a node firing this turn sees the post-decay
  /// values, not stale ones.
  void _decayAndTickLockouts(SessionState state, StateChangeLog? changeLog) {
    for (final entry in state.characters.entries) {
      final characterId = entry.key;
      final character = entry.value;
      _decayTrackedMap(
        characterId,
        'emotion',
        character.emotion,
        (k) => emotionDecayRates[k] ?? 0.0,
        state.turn,
        changeLog,
      );
      _decayTrackedMap(
        characterId,
        'physical',
        character.physical,
        (k) => physicalDecayRates[k] ?? 0.0,
        state.turn,
        changeLog,
      );
      _decayTrackedMap(
        characterId,
        'relationship',
        character.relationship,
        (k) => relationshipDecayRates[k] ?? 0.0,
        state.turn,
        changeLog,
      );
    }
  }

  void _decayTrackedMap<E extends Enum>(
    String characterId,
    String category,
    Map<E, TrackedValue> map,
    double Function(E) rateFor,
    int turn,
    StateChangeLog? changeLog,
  ) {
    map.forEach((key, value) {
      tickLockout(value);
      final before = value.value;
      applyDecay(value, rateFor(key));
      recordValueChange(
        changeLog: changeLog,
        category: StateChangeCategory.decay,
        turn: turn,
        path: '$characterId.$category.${key.name}',
        before: before,
        after: value.value,
      );
    });
  }

  _RollResult _rollEligible(NodePool pool, SessionState state) {
    final skipped = <NodeSkipRecord>[];
    final rolled = <NodeRollRecord>[];
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
    return (winners: winners, skipped: skipped, rolled: rolled);
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

  void _fireNode(
    Node node,
    NodePool pool,
    SessionState state,
    StateChangeLog? changeLog,
  ) {
    _applyEffectsToState(node, state, changeLog);
    _setCooldownAndSticky(node);
    // Spec §4.6: phase/scene transitions retire all nodes whose scope
    // is bound to the old context. Done before adding spawns so a
    // spawn whose scope matches the new context survives.
    if (node.effects.phaseChange != null) {
      pool.removeByScope(NodeScopeEnum.phase);
    }
    if (node.effects.sceneTransition) {
      pool.removeByScope(NodeScopeEnum.scene);
    }
    _addSpawnsToPool(node, pool);
    if (node.scope == NodeScopeEnum.oneShot) {
      pool.active.remove(node);
    }
  }

  void _applyEffectsToState(
    Node node,
    SessionState state,
    StateChangeLog? changeLog,
  ) {
    final effects = node.effects;
    final nodeId = node.id;
    effects.emotionDeltas.forEach((characterId, deltas) {
      final character = state.characters[characterId];
      if (character == null) return;
      deltas.forEach((emotion, delta) {
        final value = character.emotion[emotion];
        if (value == null) return;
        final before = value.value;
        final outcome = applyDelta(value, delta);
        recordValueChange(
          changeLog: changeLog,
          category: StateChangeCategory.nodeFiring,
          turn: state.turn,
          path: '$characterId.emotion.${emotion.name}',
          before: before,
          after: value.value,
          note: 'fired "$nodeId"',
        );
        if (outcome.shouldLockOpposite) {
          final opposite = character.emotion[emotion.opposite];
          if (opposite != null) setLockout(opposite, lockoutDurationTurns);
        }
      });
    });
    effects.physicalDeltas.forEach((characterId, deltas) {
      _applyEnumDeltas(
        characterId: characterId,
        category: 'physical',
        trackedMap: state.characters[characterId]?.physical,
        deltas: deltas,
        state: state,
        nodeId: nodeId,
        changeLog: changeLog,
      );
    });
    effects.relationshipDeltas.forEach((characterId, deltas) {
      _applyEnumDeltas(
        characterId: characterId,
        category: 'relationship',
        trackedMap: state.characters[characterId]?.relationship,
        deltas: deltas,
        state: state,
        nodeId: nodeId,
        changeLog: changeLog,
      );
    });
    effects.flagSet.forEach((key, value) {
      final before = state.flags[key];
      state.flags[key] = value;
      if (changeLog != null && before != value) {
        changeLog.add(StateChangeRecord(
          turn: state.turn,
          category: StateChangeCategory.nodeFiring,
          description:
              'flags.$key: ${before ?? 'null'} -> ${value ?? 'null'} '
              '(fired "$nodeId")',
        ));
      }
    });
    final goalChange = effects.goalChange;
    if (goalChange != null && goalChange != state.currentGoal) {
      final before = state.currentGoal;
      state.currentGoal = goalChange;
      changeLog?.add(StateChangeRecord(
        turn: state.turn,
        category: StateChangeCategory.nodeFiring,
        description: 'goal: "$before" -> "$goalChange" (fired "$nodeId")',
      ));
    }
    final phaseChange = effects.phaseChange;
    if (phaseChange != null && phaseChange != state.currentPhase) {
      final before = state.currentPhase;
      state.currentPhase = phaseChange;
      changeLog?.add(StateChangeRecord(
        turn: state.turn,
        category: StateChangeCategory.nodeFiring,
        description:
            'phase: ${before.name} -> ${phaseChange.name} (fired "$nodeId")',
      ));
    }
    effects.knowledgeWrites.forEach((characterId, records) {
      final character = state.characters[characterId];
      if (character == null) return;
      for (final record in records) {
        character.knowledge[record.topic] = record;
        changeLog?.add(StateChangeRecord(
          turn: state.turn,
          category: StateChangeCategory.nodeFiring,
          description:
              '$characterId.knowledge.${record.topic} = ${record.value ?? 'null'} '
              '(conf ${record.confidence.toStringAsFixed(2)}, fired "$nodeId")',
        ));
      }
    });
  }

  void _applyEnumDeltas<E extends Enum>({
    required String characterId,
    required String category,
    required Map<E, TrackedValue>? trackedMap,
    required Map<E, double> deltas,
    required SessionState state,
    required String nodeId,
    required StateChangeLog? changeLog,
  }) {
    if (trackedMap == null) return;
    deltas.forEach((key, delta) {
      final value = trackedMap[key];
      if (value == null) return;
      final before = value.value;
      applyDelta(value, delta);
      recordValueChange(
        changeLog: changeLog,
        category: StateChangeCategory.nodeFiring,
        turn: state.turn,
        path: '$characterId.$category.${key.name}',
        before: before,
        after: value.value,
        note: 'fired "$nodeId"',
      );
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

