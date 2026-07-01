import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a drift database on the web. drift hosts sqlite3 (compiled to
/// WebAssembly, FTS5 included) in a worker, persisting to OPFS when the
/// page is cross-origin isolated and falling back to IndexedDB otherwise.
/// The `sqlite3.wasm` and `drift_worker.js` assets must sit at the top of
/// `web/`; the single worker serves every database by [webName]. [nativePath]
/// is ignored here.
Future<QueryExecutor> openDriftConnection({
  required String nativePath,
  required String webName,
}) async {
  final result = await WasmDatabase.open(
    databaseName: webName,
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  return result.resolvedExecutor;
}
