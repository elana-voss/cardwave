/// One semantic problem found in a [DirectorOutput] after parsing.
/// [path] locates the offending field in dotted form, e.g.
/// `emotionDeltas.alice.anger` or `generatedNodes[2].predicate`.
class DirectorOutputValidationError {
  const DirectorOutputValidationError({
    required this.path,
    required this.message,
  });

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}
