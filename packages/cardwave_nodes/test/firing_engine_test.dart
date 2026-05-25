import 'dart:math';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

Node _node({
  String id = 'n',
  NodeTypeEnum type = NodeTypeEnum.characterBehavior,
  NodeScopeEnum scope = NodeScopeEnum.session,
  double triggerProb = 1.0,
  int delay = 0,
  int cooldown = 0,
  int sticky = 0,
  int alive = -1,
  String predicate = 'true',
  String narrativePayload = 'beat',
  NodeEffects? effects,
  List<Node>? spawns,
}) =>
    Node(
      id: id,
      origin: NodeOriginEnum.authored,
      type: type,
      triggerProb: triggerProb,
      delay: delay,
      cooldown: cooldown,
      sticky: sticky,
      alive: alive,
      scope: scope,
      predicate: predicate,
      narrativePayload: narrativePayload,
      effects: effects,
      spawns: spawns,
    );

SessionState _seedState() {
  final state = SessionState();
  state.characters['alice'] = CharacterState();
  state.characters['bob'] = CharacterState();
  return state;
}

void main() {
  group('eligibility', () {
    test('node with delay > 0 does not fire', () {
      final pool = NodePool()..add(_node(delay: 2));
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      expect(result.fired, isEmpty);
    });

    test('node with cooldown > 0 does not fire', () {
      final node = _node();
      node.currentCooldown = 2;
      final pool = NodePool()..add(node);
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      expect(result.fired, isEmpty);
    });

    test('predicate false suppresses firing', () {
      final pool = NodePool()..add(_node(predicate: 'false'));
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      expect(result.fired, isEmpty);
    });

    test('predicate true + triggerProb 1.0 fires', () {
      final pool = NodePool()..add(_node(triggerProb: 1.0));
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      expect(result.fired, hasLength(1));
    });
  });

  group('per-pool winner selection', () {
    test('only one character_behavior fires per turn', () {
      final pool = NodePool()
        ..add(_node(id: 'a', triggerProb: 1.0))
        ..add(_node(id: 'b', triggerProb: 1.0))
        ..add(_node(id: 'c', triggerProb: 1.0));
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      expect(result.fired, hasLength(1));
    });

    test('one per pool across mixed types', () {
      final pool = NodePool()
        ..add(_node(id: 'ch1', type: NodeTypeEnum.characterBehavior))
        ..add(_node(id: 'ch2', type: NodeTypeEnum.characterBehavior))
        ..add(_node(id: 'ev1', type: NodeTypeEnum.environmental))
        ..add(_node(id: 'pa1', type: NodeTypeEnum.pacing));
      final engine = FiringEngine(random: Random(1));
      final result = engine.runTurn(pool, _seedState());
      // Up to 3 fires: one each from the three pools represented.
      expect(result.fired.length, lessThanOrEqualTo(3));
      final firedTypes = result.fired.map((n) => n.type).toSet();
      expect(firedTypes, contains(NodeTypeEnum.characterBehavior));
    });
  });

  group('effects application', () {
    test('emotion delta applied with resistance', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(emotionDeltas: {
          'alice': {EmotionEnum.anger: 0.30},
        })));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      // From 0 with resistance factor 0.8, full effect: 0.30.
      expect(state.characters['alice']!.emotion[EmotionEnum.anger]!.value,
          closeTo(0.30, 1e-9));
    });

    test('large emotion delta locks opposite for 3 turns', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(emotionDeltas: {
          'alice': {EmotionEnum.anger: 0.60},
        })));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      expect(state.characters['alice']!.emotion[EmotionEnum.fear]!
          .lockoutTurnsRemaining, lockoutDurationTurns);
    });

    test('flagSet applied to global flags', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(flagSet: {'gateLocked': true})));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      expect(state.flags['gateLocked'], true);
    });

    test('goalChange replaces currentGoal', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(goalChange: 'leave the room')));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      expect(state.currentGoal, 'leave the room');
    });

    test('phaseChange transitions phase', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(phaseChange: PhaseEnum.sequel)));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      expect(state.currentPhase, PhaseEnum.sequel);
    });

    test('knowledgeWrites upserts records', () {
      final state = _seedState();
      final pool = NodePool()
        ..add(_node(effects: NodeEffects(knowledgeWrites: {
          'alice': [
            const KnowledgeRecord(
              topic: 'user_name',
              value: 'Alice',
              confidence: 0.9,
            ),
          ],
        })));
      FiringEngine(random: Random(1)).runTurn(pool, state);
      expect(state.characters['alice']!.knowledge['user_name']!.value,
          'Alice');
    });
  });

  group('post-fire state on the node', () {
    test('cooldown set to node.cooldown', () {
      final node = _node(cooldown: 5);
      final pool = NodePool()..add(node);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(node.currentCooldown, 5);
    });

    test('cooldown -1 normalized to currentCooldown 0', () {
      final node = _node(cooldown: -1);
      final pool = NodePool()..add(node);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(node.currentCooldown, 0);
    });

    test('sticky -1 set as permanent', () {
      final node = _node(sticky: -1);
      final pool = NodePool()..add(node);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(node.currentSticky, -1);
    });

    test('oneShot node removed after firing', () {
      final node = _node(scope: NodeScopeEnum.oneShot);
      final pool = NodePool()..add(node);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(pool.active, isEmpty);
    });

    test('session-scoped node stays in pool after firing', () {
      final node = _node(scope: NodeScopeEnum.session);
      final pool = NodePool()..add(node);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(pool.active, hasLength(1));
    });
  });

  group('spawns', () {
    test('spawn added to pool when parent fires', () {
      final parent = _node(
        id: 'parent',
        spawns: [_node(id: 'child', delay: 2)],
      );
      final pool = NodePool()..add(parent);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(pool.active.map((n) => n.id),
          containsAll(['parent', 'child']));
    });

    test('spawn starts with fresh runtime countdowns', () {
      final spawn = _node(id: 'child', delay: 3, alive: 10);
      spawn.currentDelay = 1; // pretend something pre-set this
      final parent = _node(spawns: [spawn]);
      final pool = NodePool()..add(parent);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      final child = pool.active.firstWhere((n) => n.id == 'child');
      expect(child.currentDelay, 3);
      expect(child.currentAlive, 10);
      expect(child.currentCooldown, 0);
      expect(child.currentSticky, 0);
    });
  });

  group('pressure update', () {
    test('reset on fire, increment on no-fire pool', () {
      final pool = NodePool()
        ..add(_node(id: 'ch', type: NodeTypeEnum.characterBehavior));
      // No environmental node; that pool gets pressure incremented.
      // Existing pressure on character_behavior should be reset by firing.
      pool.incrementPressure(NodeTypeEnum.characterBehavior, step: 0.2);
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      expect(pool.pressureFor(NodeTypeEnum.characterBehavior), 0.0);
      expect(pool.pressureFor(NodeTypeEnum.environmental),
          greaterThan(0.0));
    });

    test('quiet turn increments all pool pressures', () {
      final pool = NodePool();
      FiringEngine(random: Random(1)).runTurn(pool, _seedState());
      for (final t in NodeTypeEnum.values) {
        expect(pool.pressureFor(t), greaterThan(0.0));
      }
    });
  });

  group('pressure boost', () {
    test('pressure raises effective triggerProb above the random draw', () {
      // FakeRandom returns 0.25. triggerProb 0.05 alone → 0.25 < 0.05
      // false, no fire. With max pressure 0.3 added → 0.25 < 0.35
      // true, fires.
      final state = _seedState();

      final coldPool = NodePool()..add(_node(triggerProb: 0.05));
      final coldResult = FiringEngine(random: _ConstantRandom(0.25))
          .runTurn(coldPool, state);
      expect(coldResult.fired, isEmpty);

      final hotPool = NodePool()..add(_node(triggerProb: 0.05));
      for (var i = 0; i < 100; i++) {
        hotPool.incrementPressure(
          NodeTypeEnum.characterBehavior,
          step: 0.1,
        );
      }
      final hotResult = FiringEngine(random: _ConstantRandom(0.25))
          .runTurn(hotPool, state);
      expect(hotResult.fired, hasLength(1));
    });
  });
}

/// Random that always returns the same double from [nextDouble]. Lets
/// tests pin the random draw and isolate trigger-probability math.
class _ConstantRandom implements Random {
  _ConstantRandom(this._value);
  final double _value;
  @override
  double nextDouble() => _value;
  @override
  int nextInt(int max) => (_value * max).floor();
  @override
  bool nextBool() => _value < 0.5;
}
