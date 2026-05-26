import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/engine/value_math.dart';
import 'package:cardwave_nodes/src/models/event_log_entry.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/nodes/node_pool.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// Applies a validated [DirectorOutput] to [state]: per-character
/// emotion / physical / relationship deltas (with lockout on opposite
/// emotion for large shifts), flag merges, knowledge writes, and event
/// log appends (engine stamps `turn` from the current state).
///
/// Generated nodes are added to [pool] when provided; if [pool] is null
/// they are dropped (callers without pool access — e.g. preview / dry
/// run — get state-only application).
///
/// `directiveLines` are NOT applied here — the caller (orchestrator)
/// hands them to the actor's prompt assembly for the same turn.
void applyDirectorOutput(
  DirectorOutput output,
  SessionState state, {
  NodePool? pool,
}) {
  output.emotionDeltas.forEach((characterId, deltas) {
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

  output.physicalDeltas.forEach((characterId, deltas) {
    final character = state.characters[characterId];
    if (character == null) return;
    deltas.forEach((field, delta) {
      final value = character.physical[field];
      if (value != null) applyDelta(value, delta);
    });
  });

  output.relationshipDeltas.forEach((characterId, deltas) {
    final character = state.characters[characterId];
    if (character == null) return;
    deltas.forEach((field, delta) {
      final value = character.relationship[field];
      if (value != null) applyDelta(value, delta);
    });
  });

  state.flags.addAll(output.flagSet);

  output.knowledgeWrites.forEach((characterId, records) {
    final character = state.characters[characterId];
    if (character == null) return;
    for (final record in records) {
      character.knowledge[record.topic] = record;
    }
  });

  for (final append in output.eventLogAppend) {
    state.eventLog.add(EventLogEntry(
      turn: state.turn,
      text: append.text,
      significance: append.significance,
    ));
  }

  if (pool != null) {
    for (final node in output.generatedNodes) {
      pool.add(node);
    }
  }
}
