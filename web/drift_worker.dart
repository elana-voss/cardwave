// Web worker entry point for the on-device search database. Compiled to
// `web/drift_worker.js` (committed) and referenced by `WasmDatabase.open`
// in the search connection. Hosts sqlite3 (WebAssembly) off the main
// thread. Recompile after a drift major bump:
//   dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart
import 'package:drift/wasm.dart';

void main() {
  WasmDatabase.workerMainForOpen();
}
