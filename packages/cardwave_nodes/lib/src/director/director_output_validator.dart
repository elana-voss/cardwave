import 'package:cardwave_nodes/src/director/director_output.dart';
import 'package:cardwave_nodes/src/director/director_output_validation_error.dart';
import 'package:cardwave_nodes/src/director/event_log_append.dart';
import 'package:cardwave_nodes/src/models/knowledge_record.dart';
import 'package:cardwave_nodes/src/nodes/node.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parse_exception.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parser.dart';
import 'package:cardwave_nodes/src/predicates/predicate_validator.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';

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
      if (value < directorDeltaMin || value > directorDeltaMax) {
        errors.add(DirectorOutputValidationError(
          path: '$basePath.$characterId.${field.name}',
          message: 'value $value is out of bounds [$directorDeltaMin, $directorDeltaMax]',
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
      if (record.confidence < 0.0 || record.confidence > 1.0) {
        errors.add(DirectorOutputValidationError(
          path: '$path.confidence',
          message:
              'confidence ${record.confidence} is out of bounds [0.0, 1.0]',
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
    if (entry.significance < 0.0 || entry.significance > 1.0) {
      errors.add(DirectorOutputValidationError(
        path: '$path.significance',
        message:
            'significance ${entry.significance} is out of bounds [0.0, 1.0]',
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
    if (node.triggerProb < 0.0 || node.triggerProb > 1.0) {
      errors.add(DirectorOutputValidationError(
        path: '$path.triggerProb',
        message:
            'triggerProb ${node.triggerProb} is out of bounds [0.0, 1.0]',
      ));
    }
    try {
      final ast = parsePredicate(node.predicate);
      final predicateErrors = validatePredicate(ast);
      for (final pe in predicateErrors) {
        errors.add(DirectorOutputValidationError(
          path: '$path.predicate',
          message: 'unknown field path: ${pe.path}',
        ));
      }
    } on PredicateParseException catch (e) {
      errors.add(DirectorOutputValidationError(
        path: '$path.predicate',
        message: 'parse error: ${e.message}',
      ));
    }
  }
}
