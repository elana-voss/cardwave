/// Single typed failure surface from the embeddings module. Wraps native
/// FFI / model-load failures so callers can write
/// `on EmbeddingsException catch (e)` instead of catching every `Exception`.
class EmbeddingsException implements Exception {
  const EmbeddingsException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message (cause: $cause)';
}
