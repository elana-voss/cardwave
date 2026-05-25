import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/director/director_output_validation_error.dart';
import 'package:cardwave_nodes/src/director/event_log_append.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/predicates/predicate_check.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:cardwave_nodes/src/utils/value_bounds.dart';

/// Walks [output] and returns every semantic problem found. An empty
/// list means the output is well-formed and can be applied as-is. Type
/// errors are caught at parse time by `DirectorOutput.fromJson`; this
/// validator catches bounds violations and broken predicate strings.
List<DirectorOutputValidationError> validateDirectorOutput(
  DirectorOutput output,
) {
  final errors = <DirectorOutputValidationError>[];
  _checkEnumDeltas(output.emotionDeltas, 'emotionDeltas', errors);
  _checkEnumDeltas(output.physicalDeltas, 'physicalDeltas', errors);
  _checkEnumDeltas(output.relationshipDeltas, 'relationshipDeltas', errors);
  _checkKnowledgeWrites(output.knowledgeWrites, errors);
  _checkEventLogAppend(output.eventLogAppend, errors);
  _checkGeneratedNodes(output.generatedNodes, errors);
  return errors.isEmpty
      ? const <DirectorOutputValidationError>[]
      : errors;
}

void _checkEnumDeltas<E extends Enum>(
  Map<String, Map<E, double>> outer,
  String basePath,
  List<DirectorOutputValidationError> errors,
) {
  outer.forEach((characterId, deltas) {
    deltas.forEach((field, value) {
      final problem = boundsProblem(value, directorDeltaMin, directorDeltaMax);
      if (problem != null) {
        errors.add(DirectorOutputValidationError(
          path: '$basePath.$characterId.${field.name}',
          message: problem,
        ));
      }
    });
  });
}

void _checkKnowledgeWrites(
  Map<String, List<KnowledgeRecord>> writes,
  List<DirectorOutputValidationError> errors,
) {
  writes.forEach((characterId, records) {
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final path = 'knowledgeWrites.$characterId[$i]';
      if (record.topic.isEmpty) {
        errors.add(DirectorOutputValidationError(
          path: '$path.topic',
          message: 'topic must not be empty',
        ));
      }
      final confidenceProblem = boundsProblem(record.confidence, 0.0, 1.0);
      if (confidenceProblem != null) {
        errors.add(DirectorOutputValidationError(
          path: '$path.confidence',
          message: confidenceProblem,
        ));
      }
    }
  });
}

void _checkEventLogAppend(
  List<EventLogAppend> entries,
  List<DirectorOutputValidationError> errors,
) {
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final path = 'eventLogAppend[$i]';
    if (entry.text.isEmpty) {
      errors.add(DirectorOutputValidationError(
        path: '$path.text',
        message: 'text must not be empty',
      ));
    }
    final significanceProblem = boundsProblem(entry.significance, 0.0, 1.0);
    if (significanceProblem != null) {
      errors.add(DirectorOutputValidationError(
        path: '$path.significance',
        message: significanceProblem,
      ));
    }
  }
}

void _checkGeneratedNodes(
  List<Node> nodes,
  List<DirectorOutputValidationError> errors,
) {
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final path = 'generatedNodes[$i]';
    final triggerProblem = boundsProblem(node.triggerProb, 0.0, 1.0);
    if (triggerProblem != null) {
      errors.add(DirectorOutputValidationError(
        path: '$path.triggerProb',
        message: triggerProblem,
      ));
    }
    for (final problem in findPredicateProblems(node.predicate)) {
      errors.add(DirectorOutputValidationError(
        path: '$path.predicate',
        message: problem,
      ));
    }
  }
}
