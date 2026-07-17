import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3, SqliteExtension;

/// Opens a drift database on native platforms (Windows, macOS, Linux,
/// Android, iOS). The file lives at [nativePath] — inside the current card
/// library's disposable cache folder — so switching libraries moves the
/// database with them. [webName] is ignored here.
Future<QueryExecutor> openDriftConnection({
  required String nativePath,
  // Required by the signature connection_web.dart shares via conditional
  // import; a named parameter cannot be renamed to `_` on one side only.
  // ignore: qcheck/avoid_unused_parameters
  required String webName,
}) async {
  final file = File(nativePath);
  await file.parent.create(recursive: true);
  return NativeDatabase.createInBackground(
    file,
    isolateSetup: _registerVecExtension,
  );
}

/// Registers the sqlite-vec add-on on the database helper isolate before any
/// connection opens, so every connection it opens exposes the `vec0` virtual
/// table and the vector functions used by the approximate-search fast path.
///
/// Windows-only and best-effort. The bundled `vec0.dll` sits beside the app
/// exe. `ensureExtensionLoaded` registers through a C function pointer
/// (`sqlite3_auto_extension`), so it works even though this sqlite3 build has
/// runtime extension loading compiled out. If the binary or its entrypoint
/// can't be loaded, the add-on stays unregistered and search uses the exact
/// brute-force scan — nothing here reports back to the main isolate, so the
/// outcome is detected later by probing the open connection for the functions.
///
/// Must be a top-level function: drift sends it to the helper isolate, which
/// can only receive top-level or static references.
void _registerVecExtension() {
  if (!Platform.isWindows) return;
  try {
    final library = DynamicLibrary.open('vec0.dll');
    sqlite3.ensureExtensionLoaded(
      SqliteExtension.inLibrary(library, 'sqlite3_vec_init'),
    );
  } on ArgumentError {
    // vec0.dll or its sqlite3_vec_init symbol could not be loaded (missing
    // file or system runtime). Leave the add-on unregistered.
  } on SqliteException {
    // sqlite3 rejected the entrypoint. Leave the add-on unregistered.
  }
}
