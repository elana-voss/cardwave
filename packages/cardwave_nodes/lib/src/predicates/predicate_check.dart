import 'package:cardwave_nodes/src/predicates/predicate_parse_exception.dart';
import 'package:cardwave_nodes/src/predicates/predicate_parser.dart';
import 'package:cardwave_nodes/src/predicates/predicate_validator.dart';

/// Parses [source] as a predicate expression and validates field
/// references against `fieldSchema`. Returns a list of human-readable
/// problem messages — empty when the predicate is well-formed.
///
/// Used by both the director-output validator (for generated nodes)
/// and the card-extension loader (for authored nodes). Callers wrap
/// each message into their own domain-specific error type with the
/// appropriate path.
List<String> findPredicateProblems(String source) {
  try {
    final ast = parsePredicate(source);
    return validatePredicate(ast)
        .map((e) => 'unknown field path: ${e.path}')
        .toList();
  } on PredicateParseException catch (e) {
    return ['parse error: ${e.message}'];
  }
}
