import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/engine/value_math.dart';
import 'package:cardwave_nodes/src/models/character_state.dart';
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
/// they are dropped.
///
/// `directiveLines` are NOT applied here — the caller (orchestrator)
/// hands them to the actor's prompt assembly for the same turn.
void applyDirectorOutput(
  DirectorOutput output,
  SessionState state, {
  NodePool? pool,
}) {
  _forEachCharacter(output.emotionDeltas, state, (character, deltas) {
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

  _forEachCharacter(output.physicalDeltas, state, (character, deltas) {
    deltas.forEach((field, delta) {
      final value = character.physical[field];
      if (value != null) applyDelta(value, delta);
    });
  });

  _forEachCharacter(output.relationshipDeltas, state, (character, deltas) {
    deltas.forEach((field, delta) {
      final value = character.relationship[field];
      if (value != null) applyDelta(value, delta);
    });
  });

  state.flags.addAll(output.flagSet);

  _forEachCharacter(output.knowledgeWrites, state, (character, records) {
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

/// Iterates a director map keyed by character id, looking up the
/// matching [CharacterState] in [state] and skipping ids the session
/// hasn't seeded (the director may reference an off-stage character).
void _forEachCharacter<V>(
  Map<String, V> byCharacterId,
  SessionState state,
  void Function(CharacterState character, V value) action,
) {
  byCharacterId.forEach((characterId, value) {
    final character = state.characters[characterId];
    if (character == null) return;
    action(character, value);
  });
}
