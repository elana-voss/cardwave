/// Web and stub implementation that safely returns an empty string
/// since the Web uses IndexedDB domains instead of absolute paths. The
/// `Future<String>` return type matches the desktop implementations
/// (which do real filesystem I/O) so callers share one signature.
/// `appName` is unused here (web has no app-data folder concept) but
/// accepted to match the native signature.
/// Mirrors the native constant so shared code can reference it; web
/// ignores it (IndexedDB, no filesystem paths).
const String kAppDataDirEnvVar = 'CARDWAVE_APPDATA_DIR';

/// Mirrors the native constant so shared code can reference it; web
/// ignores it.
const String kLibraryDirEnvVar = 'CARDWAVE_LIBRARY_DIR';

Future<String> getNativeAppDataPath(String _) => Future.value('');

Future<String> getNativeDefaultCharacterPath(String _) => Future.value('');
