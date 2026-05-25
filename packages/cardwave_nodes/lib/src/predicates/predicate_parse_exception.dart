/// Thrown when a predicate string cannot be parsed.
class PredicateParseException implements Exception {
  PredicateParseException(this.message, [this.position]);
  final String message;
  final int? position;

  @override
  String toString() => position == null
      ? 'PredicateParseException: $message'
      : 'PredicateParseException at $position: $message';
}
