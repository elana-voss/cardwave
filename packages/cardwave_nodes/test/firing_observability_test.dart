import 'dart:async';
import 'dart:math';

import 'package:cardwave_nodes/cardwave_nodes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

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
    );

SessionState _seedState({int turn = 0}) {
  final state = SessionState(turn: turn);
  state.characters['alice'] = CharacterState();
  return state;
}

/// Captures everything `cardwave.nodes` emits during a test. Saves and
/// restores `Logger.root.level` so other test files are not polluted.
class _LogCapture {
  _LogCapture() : _originalLevel = Logger.root.level {
    Logger.root.level = Level.ALL;
    _sub = Logger.root.onRecord.listen((record) {
      final obj = record.object;
      if (obj is FiringLogEvent) events.add(obj);
    });
  }

  final List<FiringLogEvent> events = [];
  final Level _originalLevel;
  late final StreamSubscription<LogRecord> _sub;

  void dispose() {
    Logger.root.level = _originalLevel;
    _sub.cancel();
  }
}

void main() {
  late _LogCapture capture;

  setUp(() => capture = _LogCapture());
  tearDown(() => capture.dispose());

  test('NodeFiredEvent emitted when a node fires', () {
    final pool = NodePool()..add(_node(id: 'a', narrativePayload: 'A beats'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState(turn: 5));
    final fired = capture.events.whereType<NodeFiredEvent>().toList();
    expect(fired, hasLength(1));
    expect(fired.first.nodeId, 'a');
    expect(fired.first.turn, 5);
    expect(fired.first.narrativePayload, 'A beats');
  });

  test('NodeRolledEvent records draw + outcome for eligible nodes', () {
    final pool = NodePool()..add(_node(triggerProb: 1.0));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final rolled = capture.events.whereType<NodeRolledEvent>().toList();
    expect(rolled, hasLength(1));
    expect(rolled.first.triggerProb, 1.0);
    expect(rolled.first.pressure, 0.0);
    expect(rolled.first.won, isTrue);
    expect(rolled.first.draw, lessThan(1.0));
  });

  test('NodeSkippedEvent with delayActive when delay > 0', () {
    final pool = NodePool()..add(_node(id: 'a', delay: 3));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final skipped = capture.events.whereType<NodeSkippedEvent>().toList();
    expect(skipped, hasLength(1));
    expect(skipped.first.reason, NodeSkipReason.delayActive);
  });

  test('NodeSkippedEvent with cooldownActive when cooldown > 0', () {
    final node = _node(id: 'a');
    node.currentCooldown = 2;
    final pool = NodePool()..add(node);
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final skipped = capture.events.whereType<NodeSkippedEvent>().toList();
    expect(skipped, hasLength(1));
    expect(skipped.first.reason, NodeSkipReason.cooldownActive);
  });

  test('NodeSkippedEvent with predicateFalse when predicate fails', () {
    final pool = NodePool()..add(_node(id: 'a', predicate: 'false'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final skipped = capture.events.whereType<NodeSkippedEvent>().toList();
    expect(skipped, hasLength(1));
    expect(skipped.first.reason, NodeSkipReason.predicateFalse);
  });

  test('skip events are emitted in eligibility-check order', () {
    // Two nodes: one delay-blocked, one predicate-false. Expect both skips,
    // each with the right reason.
    final pool = NodePool()
      ..add(_node(id: 'd', delay: 2))
      ..add(_node(id: 'p', predicate: 'false'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final skipped = capture.events.whereType<NodeSkippedEvent>().toList();
    expect(skipped, hasLength(2));
    expect(skipped.firstWhere((e) => e.nodeId == 'd').reason,
        NodeSkipReason.delayActive);
    expect(skipped.firstWhere((e) => e.nodeId == 'p').reason,
        NodeSkipReason.predicateFalse);
  });

  test('rolled-but-lost is recorded but not fired', () {
    // triggerProb 0 → won is always false; no fire.
    final pool = NodePool()..add(_node(id: 'a', triggerProb: 0.0));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    final rolled = capture.events.whereType<NodeRolledEvent>().toList();
    final fired = capture.events.whereType<NodeFiredEvent>().toList();
    expect(rolled, hasLength(1));
    expect(rolled.first.won, isFalse);
    expect(fired, isEmpty);
  });
}
