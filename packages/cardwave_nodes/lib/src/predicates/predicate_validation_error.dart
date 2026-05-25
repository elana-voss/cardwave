/// One validation error: a field reference whose path is not in the
/// declared schema.
class PredicateValidationError {
  PredicateValidationError(this.path);
  final String path;

  @override
  String toString() => 'Unknown field path: $path';
}
