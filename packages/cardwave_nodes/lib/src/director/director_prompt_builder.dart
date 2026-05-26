import 'dart:convert';

import 'package:cardwave_nodes/src/models/session_state.dart';

const _systemPreamble = '''
# Role

You are the DIRECTOR of an interactive character chat. Your job is to
read what just happened and update the character's internal state so the
next reply feels alive.

You do NOT write character dialogue. You return a JSON object describing:
  - emotion_deltas / physical_deltas / relationship_deltas per character
  - flag_set (flat key/value flags)
  - directive_lines (short authorial nudges for the actor's prompt this turn)
  - event_log_append (new event-log entries; engine stamps the turn)

# Constraints

  - Deltas are SMALL by default (0.05 - 0.30). Save large jumps for big moments.
  - Bounds: deltas in [-1, 1]; significance in [0, 1].
  - Directives are SHORT and AUTHORIAL ("she's still cool toward him,
    softening only slightly"). NOT scripted dialogue.
  - You CANNOT change goal, phase, or scene — those move only when a node fires.
  - Omit any field you have no change for.
''';

/// Initial draft of the director system prompt. The system prompt opens
/// with [_systemPreamble], then dumps the current session state as JSON,
/// then the actor's last output, then the user's current input.
///
/// To be reviewed and tuned by the project owner before shipping.
String buildDirectorPrompt({
  required SessionState state,
  required String actorLastOutput,
  required String userInput,
}) {
  final stateJson = const JsonEncoder.withIndent('  ').convert(state.toJson());
  return '''
$_systemPreamble

# Current state

$stateJson

# Actor's last output

$actorLastOutput

# User input

$userInput

# Output

Return a single JSON object matching the schema. Omit fields you have
no change for.
''';
}
