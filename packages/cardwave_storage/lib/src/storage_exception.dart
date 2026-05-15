/// Thrown by [AppStorage] implementations on any IO failure.
///
/// Wraps `fs_shim`'s `FileSystemException` (which does not implement Dart's
/// `Exception`) so callers can use narrow `on Exception` catches without
/// letting storage errors slip through. The original cause is preserved in
/// [cause] / [causeStackTrace] for diagnostics.
class StorageException implements Exception {
  const StorageException(this.message, {this.cause, this.causeStackTrace});

  final String message;
  final Object? cause;
  final StackTrace? causeStackTrace;

  @override
  String toString() => 'StorageException: $message';
}
