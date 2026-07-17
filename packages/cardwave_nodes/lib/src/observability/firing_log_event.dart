/// Why a node did not get rolled this turn.
enum NodeSkipReason {
  /// Node's `currentDelay > 0`.
  delayActive,

  /// Node's `currentCooldown > 0`.
  cooldownActive,

  /// Node's predicate evaluated to false against the current state.
  predicateFalse,

  /// Node's predicate failed to parse. Authored nodes with bad
  /// predicates are filtered out at load, so this is a belt-and-braces
  /// guard (persisted or director-spawned nodes) — the node is skipped
  /// instead of the parse error killing the whole turn.
  predicateInvalid,
}

/// Node was not rolled this turn because an eligibility gate stopped
/// it (delay countdown, cooldown, or predicate false). The reason
/// tells the debug view which gate fired.
class NodeSkipRecord {
  const NodeSkipRecord({required this.nodeId, required this.reason});

  final String nodeId;
  final NodeSkipReason reason;
}

/// Eligible node was rolled. Records the effective probability
/// (`triggerProb + pressure`) and the random draw so the debug view
/// can show "0.42 ≤ 0.55 → won."
class NodeRollRecord {
  const NodeRollRecord({
    required this.nodeId,
    required this.triggerProb,
    required this.pressure,
    required this.draw,
    required this.won,
  });

  final String nodeId;
  final double triggerProb;
  final double pressure;
  final double draw;
  final bool won;
}

/// Node was the winner picked from this turn's eligible+won set and
/// its effects were applied to state.
class NodeFireRecord {
  const NodeFireRecord({required this.nodeId, required this.narrativePayload});

  final String nodeId;
  final String narrativePayload;
}

/// Per-turn firing summary, emitted ONCE by `FiringEngine.runTurn` as
/// the `LogRecord.object` of a single `Logger('cardwave.nodes')` info
/// record. Bundles every eligibility decision and every firing for
/// the turn so the host sees one log entry per turn instead of one
/// per node — a 10-node pool no longer floods the log viewer with
/// 10+ entries per turn.
class TurnFiringEvent {
  const TurnFiringEvent({
    required this.turn,
    required this.skipped,
    required this.rolled,
    required this.fired,
  });

  final int turn;
  final List<NodeSkipRecord> skipped;
  final List<NodeRollRecord> rolled;
  final List<NodeFireRecord> fired;
}
