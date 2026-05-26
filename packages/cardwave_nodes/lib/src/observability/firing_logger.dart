import 'package:cardwave_nodes/src/observability/firing_log_event.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger(packageLoggerName);

/// Emits the single per-turn [TurnFiringEvent] the firing engine
/// builds at the end of `runTurn`. Info-level — debounced into one
/// record so the host's log viewer sees one entry per turn, not one
/// per node.
void logTurnFiring(TurnFiringEvent event) {
  _logger.info(event);
}
