/// Web and stub implementation that safely returns an empty string
/// since the Web uses IndexedDB domains instead of absolute paths. The
/// `Future<String>` return type matches the desktop implementations
/// (which do real filesystem I/O) so callers share one signature.
Future<String> getNativeAppDataPath() => Future.value('');

Future<String> getNativeDefaultCharacterPath() => Future.value('');
