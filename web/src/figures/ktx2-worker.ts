// The KTX2 transcoder's worker (decoders.ts starts it): three.js's Basis transcoder and the worker body of its
// KTX2 loader, built as a file of the app's own, as the loader's own worker, made from a blob, would take the
// page's content policy.
//
// Traps: the transcoder (Emscripten's embind) makes its functions by `Function(…)`, an eval the page's policy
// refuses; the server answers this file, by its name `ktx2-worker-*.js`, with a policy of its own that allows it
// (server/src/lib.rs, `WORKER_POLICY`), for this worker alone. The loader's worker body reads its constants and
// `BASIS` as globals, which it had in the blob. A transcoder that fails to load is told to the page ('broken').
import BASIS from "three/addons/libs/basis/basis_transcoder.js";
import { KTX2Loader } from "three/addons/loaders/KTX2Loader.js";

const loader = KTX2Loader as typeof KTX2Loader & Record<"EngineFormat" | "EngineType" | "TranscoderFormat" | "BasisFormat", object> & { BasisWorker: () => void };
Object.assign(globalThis, {
  BASIS,
  _EngineFormat: loader.EngineFormat,
  _EngineType: loader.EngineType,
  _TranscoderFormat: loader.TranscoderFormat,
  _BasisFormat: loader.BasisFormat,
});
loader.BasisWorker();
// The transcoder failing to load leaves the loader's worker waiting forever, never answering a task: it is told to
// the page, whose `guarded` (decoders.ts) answers the tasks with an error.
const broken = (error: unknown) => self.postMessage({ type: "broken", error: String(error) });
self.addEventListener("unhandledrejection", (event) => broken(event.reason));
self.addEventListener("error", (event) => broken(event.message));
