/// One problem found while loading a card's `cardwave_nodes` extension.
/// [path] locates the offending field in dotted form, e.g.
/// `authoredNodes[2].predicate` or `emotionBaseline.trust`.
class CardExtensionLoadError {
  const CardExtensionLoadError({
    required this.path,
    required this.message,
  });

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}
