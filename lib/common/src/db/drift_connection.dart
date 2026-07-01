// Conditional export: resolves `openDriftConnection` to the native or web
// backend at compile time. Native opens a file with `NativeDatabase`; web
// opens a worker-hosted WebAssembly database with `WasmDatabase`. Shared by
// every on-device drift database in the app (search index, card library).
export 'connection_unsupported.dart'
    if (dart.library.io) 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
