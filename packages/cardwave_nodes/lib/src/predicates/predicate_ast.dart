/// Comparison operator in a predicate expression.
enum ComparisonOp {
  eq, // ==
  ne, // !=
  lt, // <
  le, // <=
  gt, // >
  ge, // >=
}

/// Predicate AST node. Sealed so the evaluator and validator can exhaust
/// every case at compile time.
sealed class PredicateNode {
  const PredicateNode();
}

class AndNode extends PredicateNode {
  const AndNode(this.left, this.right);
  final PredicateNode left;
  final PredicateNode right;
}

class OrNode extends PredicateNode {
  const OrNode(this.left, this.right);
  final PredicateNode left;
  final PredicateNode right;
}

class NotNode extends PredicateNode {
  const NotNode(this.operand);
  final PredicateNode operand;
}

class ComparisonNode extends PredicateNode {
  const ComparisonNode(this.left, this.op, this.right);
  final PredicateNode left;
  final ComparisonOp op;
  final PredicateNode right;
}

/// A literal number, string, or boolean from the source expression.
class LiteralNode extends PredicateNode {
  const LiteralNode(this.value);
  final Object value;
}

/// A dotted-path reference into the state namespace, e.g.
/// `character.alice.emotion.anger`. [segments] is the path pre-split at
/// parse time so the evaluator does not re-split on every evaluation.
class FieldRefNode extends PredicateNode {
  FieldRefNode(this.path) : segments = path.split('.');
  final String path;
  final List<String> segments;
}
