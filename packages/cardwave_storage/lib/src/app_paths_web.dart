/// Web and stub implementation that safely returns an empty string
/// since the Web uses IndexedDB domains instead of absolute paths. The
/// `Future<String>` return type matches the desktop implementations
/// (which do real filesystem I/O) so callers share one signature.
/// `appName` is unused here (web has no app-data folder concept) but
/// accepted to match the native signature.
Future<String> getNativeAppDataPath(String _) => Future.value('');

Future<String> getNativeDefaultCharacterPath(String _) => Future.value('');
