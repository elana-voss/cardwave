import 'package:cardwave_nodes/src/loading/card_extension_load_error.dart';
import 'package:cardwave_nodes/src/loading/card_nodes_extension.dart';
import 'package:cardwave_nodes/src/predicates/predicate_check.dart';
import 'package:cardwave_nodes/src/utils/value_bounds.dart';

/// Parsed extension paired with any problems found.
typedef CardExtensionLoadResult = ({
  CardNodesExtension extension,
  List<CardExtensionLoadError> errors,
});

/// Parses [json] (the value at `extensions.cardwave_nodes` in a
/// SillyTavern v3 card) into a [CardNodesExtension] and returns it
/// alongside a list of validation problems. An empty error list means
/// the card extension is well-formed.
///
/// Validation covers:
///   - JSON shape (caught by `fromJson`; reported as a single root-level
///     `parse failed` error if the JSON is mis-shaped)
///   - every authored node's predicate parses + references only valid
///     field paths from `fieldSchema`
///   - emotion-baseline values are in `[0.0, 1.0]`
CardExtensionLoadResult loadCardNodesExtension(Map<String, dynamic> json) {
  final errors = <CardExtensionLoadError>[];
  final CardNodesExtension extension;
  try {
    extension = CardNodesExtension.fromJson(json);
  } on Exception catch (e) {
    return _rootError('parse failed: $e');
  } on TypeError catch (e) {
    // `json_serializable`'s fromJson casts fields with `as`; a
    // mis-shaped value (e.g. `authored_nodes: 42` where a list is
    // expected) throws TypeError, which is an Error not an Exception.
    // Reporting it as a load error keeps the loader tolerant of bad
    // card input.
    return _rootError('parse failed: type mismatch — $e');
  }

  for (var i = 0; i < extension.authoredNodes.length; i++) {
    final node = extension.authoredNodes[i];
    final path = 'authoredNodes[$i]';
    for (final problem in findPredicateProblems(node.predicate)) {
      errors.add(CardExtensionLoadError(
        path: '$path.predicate',
        message: problem,
      ));
    }
  }

  extension.emotionBaseline.forEach((emotion, value) {
    final problem = boundsProblem(value, 0.0, 1.0);
    if (problem != null) {
      errors.add(CardExtensionLoadError(
        path: 'emotionBaseline.${emotion.name}',
        message: problem,
      ));
    }
  });

  return (extension: extension, errors: errors);
}

CardExtensionLoadResult _rootError(String message) => (
      extension: CardNodesExtension(),
      errors: [CardExtensionLoadError(path: 'root', message: message)],
    );
