import 'dart:convert';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';

Node _node({
  String id = 'n1',
  NodeTypeEnum type = NodeTypeEnum.characterBehavior,
  NodeScopeEnum scope = NodeScopeEnum.session,
  int delay = 0,
  int cooldown = 0,
  int sticky = 0,
  int alive = -1,
}) =>
    Node(
      id: id,
      origin: NodeOriginEnum.authored,
      type: type,
      triggerProb: 0.5,
      delay: delay,
      cooldown: cooldown,
      sticky: sticky,
      alive: alive,
      scope: scope,
      predicate: 'true',
      narrativePayload: 'something happens',
    );

void main() {
  group('Node construction', () {
    test('defaults: currentDelay = delay, currentAlive = alive', () {
      final n = _node(delay: 3, alive: 10);
      expect(n.currentDelay, 3);
      expect(n.currentAlive, 10);
      expect(n.currentCooldown, 0);
      expect(n.currentSticky, 0);
    });

    test('delay -1 is normalized to currentDelay 0', () {
      final n = _node(delay: -1);
      expect(n.currentDelay, 0);
    });

    test('alive -1 is preserved as currentAlive -1', () {
      final n = _node(alive: -1);
      expect(n.currentAlive, -1);
    });
  });

  group('NodePool.tick', () {
    test('decrements positive countdowns', () {
      final pool = NodePool()..add(_node(delay: 3, alive: 10));
      pool.tick();
      expect(pool.active.first.currentDelay, 2);
      expect(pool.active.first.currentAlive, 9);
    });

    test('does not decrement zero countdowns', () {
      final pool = NodePool()..add(_node(delay: 0, alive: -1));
      pool.tick();
      expect(pool.active.first.currentDelay, 0);
    });

    test('does not decrement -1 (no-TTL) alive', () {
      final pool = NodePool()..add(_node(alive: -1));
      pool.tick();
      expect(pool.active.first.currentAlive, -1);
    });

    test('removes nodes whose alive reached zero', () {
      final pool = NodePool()..add(_node(alive: 1));
      pool.tick();
      expect(pool.active, isEmpty);
    });

    test('does not remove nodes with alive=-1 even after many ticks', () {
      final pool = NodePool()..add(_node(alive: -1));
      for (var i = 0; i < 100; i++) {
        pool.tick();
      }
      expect(pool.active, hasLength(1));
    });

    test('decrements sticky when set', () {
      final n = _node(sticky: 5);
      n.currentSticky = 3;
      final pool = NodePool()..add(n);
      pool.tick();
      expect(pool.active.first.currentSticky, 2);
    });
  });

  group('NodePool.removeByScope', () {
    test('removes only nodes with matching scope', () {
      final pool = NodePool()
        ..add(_node(id: 'a', scope: NodeScopeEnum.scene))
        ..add(_node(id: 'b', scope: NodeScopeEnum.session))
        ..add(_node(id: 'c', scope: NodeScopeEnum.scene));
      pool.removeByScope(NodeScopeEnum.scene);
      expect(pool.active.map((n) => n.id), ['b']);
    });
  });

  group('NodePool pressure', () {
    test('increments and clamps at pressureCap', () {
      final pool = NodePool();
      for (var i = 0; i < 100; i++) {
        pool.incrementPressure(NodeTypeEnum.characterBehavior, step: 0.1);
      }
      expect(pool.pressureFor(NodeTypeEnum.characterBehavior), pressureCap);
    });

    test('resetPressure returns to 0', () {
      final pool = NodePool()
        ..incrementPressure(NodeTypeEnum.event, step: 0.2)
        ..resetPressure(NodeTypeEnum.event);
      expect(pool.pressureFor(NodeTypeEnum.event), 0.0);
    });

    test('pressure tracked per type independently', () {
      final pool = NodePool()
        ..incrementPressure(NodeTypeEnum.characterBehavior, step: 0.2)
        ..incrementPressure(NodeTypeEnum.environmental, step: 0.05);
      expect(pool.pressureFor(NodeTypeEnum.characterBehavior), closeTo(0.2, 1e-9));
      expect(pool.pressureFor(NodeTypeEnum.environmental), closeTo(0.05, 1e-9));
      expect(pool.pressureFor(NodeTypeEnum.event), 0.0);
    });
  });

  group('JSON round-trip', () {
    test('Node with default effects', () {
      final original = _node(id: 'n1', delay: 3, alive: 10);
      final restored = Node.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, 'n1');
      expect(restored.delay, 3);
      expect(restored.alive, 10);
      expect(restored.currentDelay, 3);
      expect(restored.currentAlive, 10);
      expect(restored.predicate, 'true');
    });

    test('NodeEffects with nested enum-keyed maps', () {
      final original = NodeEffects(
        emotionDeltas: {
          'alice': {EmotionEnum.anger: 0.2, EmotionEnum.joy: -0.1},
          'bob': {EmotionEnum.fear: 0.3},
        },
        flagSet: {'hasApologized': true, 'drinkCount': 3},
        goalChange: 'leave the room',
        phaseChange: PhaseEnum.sequel,
        sceneTransition: true,
      );
      final restored = NodeEffects.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.emotionDeltas['alice']?[EmotionEnum.anger], 0.2);
      expect(restored.emotionDeltas['alice']?[EmotionEnum.joy], -0.1);
      expect(restored.emotionDeltas['bob']?[EmotionEnum.fear], 0.3);
      expect(restored.flagSet['hasApologized'], true);
      expect(restored.goalChange, 'leave the room');
      expect(restored.phaseChange, PhaseEnum.sequel);
      expect(restored.sceneTransition, true);
    });

    test('Node with spawn links and non-default runtime state', () {
      final parent = _node(id: 'parent', delay: 5, alive: 20)
        ..currentDelay = 2
        ..currentAlive = 15
        ..currentCooldown = 3
        ..currentSticky = 4
        ..spawnIds.add('child');
      final restored = Node.fromJson(
        jsonDecode(jsonEncode(parent.toJson())) as Map<String, dynamic>,
      );
      expect(restored.currentDelay, 2);
      expect(restored.currentAlive, 15);
      expect(restored.currentCooldown, 3);
      expect(restored.currentSticky, 4);
      expect(restored.spawnIds, ['child']);
    });
  });
}
