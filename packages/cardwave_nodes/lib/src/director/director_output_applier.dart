import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/engine/value_math.dart';
import 'package:cardwave_nodes/src/models/character_state.dart';
import 'package:cardwave_nodes/src/models/event_log_entry.dart';
import 'package:cardwave_nodes/src/models/session_state.dart';
import 'package:cardwave_nodes/src/models/tracked_value.dart';
import 'package:cardwave_nodes/src/nodes/node_pool.dart';
import 'package:cardwave_nodes/src/observability/state_change_record.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

/// Applies a validated [DirectorOutput] to [state]: per-character
/// emotion / physical / relationship deltas (with lockout on opposite
/// emotion for large shifts), flag merges, knowledge writes, and event
/// log appends (engine stamps `turn` from the current state).
///
/// Generated nodes are added to [pool] when provided; if [pool] is null
/// they are dropped.
///
/// `directiveLines` are NOT applied here. They flow through
/// [SessionState.pendingDirectives]: the caller (orchestrator) stashes
/// them on state after applying the rest of the output, and the next
/// turn's prompt assembly consumes and clears them.
///
/// [changeLog] is optional; when supplied, every per-field mutation is
/// captured as a [StateChangeRecord] for the debug panel.
void applyDirectorOutput(
  DirectorOutput output,
  SessionState state, {
  NodePool? pool,
  StateChangeLog? changeLog,
}) {
  _forEachCharacter(output.emotionDeltas, state, (characterId, character, deltas) {
    deltas.forEach((emotion, delta) {
      final value = character.emotion[emotion];
      if (value == null) return;
      final before = value.value;
      final outcome = applyDelta(value, delta);
      recordValueChange(
        changeLog: changeLog,
        category: StateChangeCategory.director,
        turn: state.turn,
        path: '$characterId.emotion.${emotion.name}',
        before: before,
        after: value.value,
      );
      if (outcome.shouldLockOpposite) {
        final opposite = character.emotion[emotion.opposite];
        if (opposite != null) setLockout(opposite, lockoutDurationTurns);
      }
    });
  });

  _forEachCharacter(output.physicalDeltas, state, (characterId, character, deltas) {
    _applyTrackedDeltas(
      characterId: characterId,
      category: 'physical',
      trackedMap: character.physical,
      deltas: deltas,
      turn: state.turn,
      changeLog: changeLog,
    );
  });

  _forEachCharacter(output.relationshipDeltas, state, (characterId, character, deltas) {
    _applyTrackedDeltas(
      characterId: characterId,
      category: 'relationship',
      trackedMap: character.relationship,
      deltas: deltas,
      turn: state.turn,
      changeLog: changeLog,
    );
  });

  output.flagSet.forEach((key, value) {
    final before = state.flags[key];
    state.flags[key] = value;
    if (changeLog != null && before != value) {
      changeLog.add(StateChangeRecord(
        turn: state.turn,
        category: StateChangeCategory.director,
        description:
            'flags.$key: ${before ?? 'null'} -> ${value ?? 'null'}',
      ));
    }
  });

  _forEachCharacter(output.knowledgeWrites, state, (characterId, character, records) {
    for (final record in records) {
      character.knowledge[record.topic] = record;
      changeLog?.add(StateChangeRecord(
        turn: state.turn,
        category: StateChangeCategory.director,
        description:
            '$characterId.knowledge.${record.topic} = ${record.value ?? 'null'} '
            '(conf ${record.confidence.toStringAsFixed(2)})',
      ));
    }
  });

  for (final append in output.eventLogAppend) {
    state.eventLog.add(EventLogEntry(
      turn: state.turn,
      text: append.text,
      significance: append.significance,
    ));
    changeLog?.add(StateChangeRecord(
      turn: state.turn,
      category: StateChangeCategory.director,
      description: 'eventLog += "${append.text}" '
          '(sig ${append.significance.toStringAsFixed(2)})',
    ));
  }

  if (pool != null) {
    for (final node in output.generatedNodes) {
      pool.add(node);
      changeLog?.add(StateChangeRecord(
        turn: state.turn,
        category: StateChangeCategory.director,
        description: 'pool += node "${node.id}" (${node.type.name})',
      ));
    }
  }
}

/// Iterates a director map keyed by character id, looking up the
/// matching [CharacterState] in [state] and skipping ids the session
/// hasn't seeded (the director may reference an off-stage character).
void _forEachCharacter<V>(
  Map<String, V> byCharacterId,
  SessionState state,
  void Function(String characterId, CharacterState character, V value) action,
) {
  byCharacterId.forEach((characterId, value) {
    final character = state.characters[characterId];
    if (character == null) return;
    action(characterId, character, value);
  });
}

void _applyTrackedDeltas<E extends Enum>({
  required String characterId,
  required String category,
  required Map<E, TrackedValue> trackedMap,
  required Map<E, double> deltas,
  required int turn,
  required StateChangeLog? changeLog,
}) {
  deltas.forEach((key, delta) {
    final value = trackedMap[key];
    if (value == null) return;
    final before = value.value;
    applyDelta(value, delta);
    recordValueChange(
      changeLog: changeLog,
      category: StateChangeCategory.director,
      turn: turn,
      path: '$characterId.$category.${key.name}',
      before: before,
      after: value.value,
    );
  });
}
