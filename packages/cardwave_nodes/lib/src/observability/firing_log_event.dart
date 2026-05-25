/// Sealed family of firing-domain log payloads carried as `LogRecord.object`.
/// The app subscribes to `Logger.root.onRecord` and dispatches on the runtime
/// type — same pattern as the memory and embeddings domains.
sealed class FiringLogEvent {
  const FiringLogEvent({required this.turn, required this.nodeId});

  final int turn;
  final String nodeId;
}

/// Why a node did not get rolled this turn.
enum NodeSkipReason {
  /// Node's `currentDelay > 0`.
  delayActive,

  /// Node's `currentCooldown > 0`.
  cooldownActive,

  /// Node's predicate evaluated to false against the current state.
  predicateFalse,
}

/// Node was not rolled because an eligibility gate stopped it.
class NodeSkippedEvent extends FiringLogEvent {
  const NodeSkippedEvent({
    required super.turn,
    required super.nodeId,
    required this.reason,
  });

  final NodeSkipReason reason;
}

/// Eligible node was rolled. Records the effective probability
/// (`triggerProb + pressure`) and the random draw so the debug view can
/// show "0.42 ≤ 0.55 → won."
class NodeRolledEvent extends FiringLogEvent {
  const NodeRolledEvent({
    required super.turn,
    required super.nodeId,
    required this.triggerProb,
    required this.pressure,
    required this.draw,
    required this.won,
  });

  final double triggerProb;
  final double pressure;
  final double draw;
  final bool won;
}

/// Node was the winner picked from this turn's eligible+won set and its
/// effects were applied to state.
class NodeFiredEvent extends FiringLogEvent {
  const NodeFiredEvent({
    required super.turn,
    required super.nodeId,
    required this.narrativePayload,
  });

  final String narrativePayload;
}
