import 'package:cardwave_nodes/src/predicates/field_schema.dart';
import 'package:cardwave_nodes/src/predicates/predicate_ast.dart';
import 'package:cardwave_nodes/src/predicates/predicate_validation_error.dart';

/// Walks [predicate] and returns one [PredicateValidationError] per
/// field reference whose path matches no entry in [fieldSchema]. An
/// empty list means the predicate is well-formed.
List<PredicateValidationError> validatePredicate(PredicateNode predicate) {
  final errors = <PredicateValidationError>[];
  _collectErrors(predicate, errors);
  return errors;
}

void _collectErrors(
  PredicateNode node,
  List<PredicateValidationError> errors,
) {
  switch (node) {
    case AndNode(:final left, :final right) ||
          OrNode(:final left, :final right) ||
          ComparisonNode(:final left, :final right):
      _collectErrors(left, errors);
      _collectErrors(right, errors);
    case NotNode(:final operand):
      _collectErrors(operand, errors);
    case FieldRefNode(:final path):
      if (lookupPath(path) == null) {
        errors.add(PredicateValidationError(path));
      }
    case LiteralNode():
      break;
  }
}
