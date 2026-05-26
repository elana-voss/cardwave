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

/// Captures every [TurnFiringEvent] the firing engine emits during a
/// test. Saves and restores `Logger.root.level` so other test files
/// are not polluted.
class _LogCapture {
  _LogCapture() : _originalLevel = Logger.root.level {
    Logger.root.level = Level.ALL;
    _sub = Logger.root.onRecord.listen((record) {
      final obj = record.object;
      if (obj is TurnFiringEvent) events.add(obj);
    });
  }

  final List<TurnFiringEvent> events = [];
  final Level _originalLevel;
  late final StreamSubscription<LogRecord> _sub;

  /// The last (and usually only) event the test captured.
  TurnFiringEvent get last => events.last;

  void dispose() {
    Logger.root.level = _originalLevel;
    _sub.cancel();
  }
}

void main() {
  late _LogCapture capture;

  setUp(() => capture = _LogCapture());
  tearDown(() => capture.dispose());

  test('exactly one TurnFiringEvent per runTurn', () {
    final pool = NodePool()..add(_node(id: 'a'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.events, hasLength(1),
        reason: 'runTurn should emit one debounced summary, not per-event records');
  });

  test('fired list populated when a node fires', () {
    final pool = NodePool()..add(_node(id: 'a', narrativePayload: 'A beats'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState(turn: 5));
    expect(capture.last.turn, 5);
    expect(capture.last.fired, hasLength(1));
    expect(capture.last.fired.first.nodeId, 'a');
    expect(capture.last.fired.first.narrativePayload, 'A beats');
  });

  test('rolled list records draw + outcome for eligible nodes', () {
    final pool = NodePool()..add(_node(triggerProb: 1.0));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.rolled, hasLength(1));
    expect(capture.last.rolled.first.triggerProb, 1.0);
    expect(capture.last.rolled.first.pressure, 0.0);
    expect(capture.last.rolled.first.won, isTrue);
    expect(capture.last.rolled.first.draw, lessThan(1.0));
  });

  test('skipped list carries delayActive when delay > 0', () {
    final pool = NodePool()..add(_node(id: 'a', delay: 3));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.skipped, hasLength(1));
    expect(capture.last.skipped.first.reason, NodeSkipReason.delayActive);
  });

  test('skipped list carries cooldownActive when cooldown > 0', () {
    final node = _node(id: 'a');
    node.currentCooldown = 2;
    final pool = NodePool()..add(node);
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.skipped, hasLength(1));
    expect(capture.last.skipped.first.reason, NodeSkipReason.cooldownActive);
  });

  test('skipped list carries predicateFalse when predicate fails', () {
    final pool = NodePool()..add(_node(id: 'a', predicate: 'false'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.skipped, hasLength(1));
    expect(capture.last.skipped.first.reason, NodeSkipReason.predicateFalse);
  });

  test('skipped list keeps eligibility-check order with mixed reasons', () {
    // Two nodes: one delay-blocked, one predicate-false. Both skips land
    // on the same TurnFiringEvent, each with the right reason.
    final pool = NodePool()
      ..add(_node(id: 'd', delay: 2))
      ..add(_node(id: 'p', predicate: 'false'));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.skipped, hasLength(2));
    expect(capture.last.skipped.firstWhere((e) => e.nodeId == 'd').reason,
        NodeSkipReason.delayActive);
    expect(capture.last.skipped.firstWhere((e) => e.nodeId == 'p').reason,
        NodeSkipReason.predicateFalse);
  });

  test('rolled-but-lost is recorded; fired list stays empty', () {
    // triggerProb 0 → won is always false; no fire.
    final pool = NodePool()..add(_node(id: 'a', triggerProb: 0.0));
    FiringEngine(random: Random(1)).runTurn(pool, _seedState());
    expect(capture.last.rolled, hasLength(1));
    expect(capture.last.rolled.first.won, isFalse);
    expect(capture.last.fired, isEmpty);
  });
}
