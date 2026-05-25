import 'package:cardwave_nodes/src/observability/firing_log_event.dart';
import 'package:logging/logging.dart';

/// Package-wide logger. Each record carries a [FiringLogEvent] as its
/// `LogRecord.object`, which the app routes to its debug panel. The name
/// sits under the `cardwave.` namespace that the app's log router
/// forwards; a plain `cardwave_nodes` would be filtered out.
final Logger _logger = Logger('cardwave.nodes');

/// Skip/roll events are noisy (one per node per turn). The level guard
/// short-circuits before the event is constructed so production builds
/// with default log level pay no allocation cost.
void logNodeSkipped({
  required int turn,
  required String nodeId,
  required NodeSkipReason reason,
}) {
  if (!_logger.isLoggable(Level.FINE)) return;
  _logger.fine(NodeSkippedEvent(turn: turn, nodeId: nodeId, reason: reason));
}

void logNodeRolled({
  required int turn,
  required String nodeId,
  required double triggerProb,
  required double pressure,
  required double draw,
  required bool won,
}) {
  if (!_logger.isLoggable(Level.FINE)) return;
  _logger.fine(NodeRolledEvent(
    turn: turn,
    nodeId: nodeId,
    triggerProb: triggerProb,
    pressure: pressure,
    draw: draw,
    won: won,
  ));
}

/// Fire events are user-meaningful (drive the debug panel's narrative
/// log); logged at info level — typically observed.
void logNodeFired({
  required int turn,
  required String nodeId,
  required String narrativePayload,
}) {
  _logger.info(NodeFiredEvent(
    turn: turn,
    nodeId: nodeId,
    narrativePayload: narrativePayload,
  ));
}
