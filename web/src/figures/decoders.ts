// What a compressed glTF figure is read with (`withDecoders`): meshopt's decoder for its geometry
// (EXT_meshopt_compression) and three.js's KTX2 loader for its textures (KHR_texture_basisu), whose Basis transcoder
// runs in a worker of the app's own (ktx2-worker.ts), given the transcoder's WebAssembly (three's, imported by address
// so the build keeps it). One KTX2 loader per set of formats, so its workers, told the formats at their start, are made once.
//
// Traps: both run WebAssembly, which the pages' content policy allows only by 'wasm-unsafe-eval'
// (server/src/lib.rs). The loader's own worker, made from a blob, would take the page's policy, which refuses the
// transcoder's eval: `Ktx2` starts ktx2-worker.ts instead, which the server answers with a policy of its own. The
// KTX2 loader picks the format a texture is transcoded to by what the renderer can show, so it needs a renderer that
// has started (drawer.ts's `ready`); without one a KTX2 texture is refused by three's GLTFLoader, and the figure with it.
// On WebGPU's WebGL 2 fallback three's choice is made by that fallback's extensions (`Ktx2.detectSupport`), or it
// picks a format the fallback cannot show (BC7 for BC1-3; BC1-3 without its sRGB). Three's worker pool waits forever
// on a worker that never answers, so a failed worker is `guarded`.
import { FileLoader } from "three";
import type { WebGPURenderer } from "three/webgpu";
import type { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { KTX2Loader } from "three/addons/loaders/KTX2Loader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";
import transcoderBinary from "three/addons/libs/basis/basis_transcoder.wasm?url";
import workerAddress from "./ktx2-worker?worker&url";

/** `worker`, which answers a task it cannot do, as three's KTX2 loader waits for an answer forever: once it failed to
 * start (an 'error' event) or its transcoder to load ('broken', from ktx2-worker.ts), it is stopped, the task it had is
 * answered with an error and so is every later one, so the texture and the figure with it are refused. */
export function guarded(worker: Worker): Worker {
  const fail = (error: string) => worker.dispatchEvent(new MessageEvent("message", { data: { type: "error", error, data: {} } }));
  const broken = (error: string) => {
    console.error(`The KTX2 transcoder's worker failed: ${error}`);
    worker.terminate();
    worker.postMessage = () => void queueMicrotask(() => fail(error));
    fail(error);
  };
  // Added before the pool's own listener, so a 'broken' message stops here.
  worker.addEventListener("message", (event: MessageEvent) => {
    if (event.data?.type !== "broken") return;
    event.stopImmediatePropagation();
    broken(String(event.data.error));
  });
  worker.addEventListener("error", (event: Event) => {
    event.preventDefault();
    broken((event as ErrorEvent).message || "it did not start");
  });
  return worker;
}

/** Three's KTX2 loader whose workers are ktx2-worker.ts, each given the transcoder's WebAssembly as three's own. */
class Ktx2 extends KTX2Loader {
  override init(): Promise<void> {
    this.transcoderPending ??= new FileLoader(this.manager)
      .setResponseType("arraybuffer")
      .loadAsync(transcoderBinary)
      .then((loaded) => {
        const binary = loaded as ArrayBuffer;
        this.workerPool.setWorkerCreator(() => {
          const worker = guarded(new Worker(workerAddress));
          const copy = binary.slice(0);
          worker.postMessage({ type: "init", config: this.workerConfig, transcoderBinary: copy }, [copy]);
          return worker;
        });
      });
    return this.transcoderPending;
  }

  /** Three's choice, but on WebGPU's WebGL 2 fallback by the extensions that fallback shows each format with: three
   * takes BC7 from BC1-3's, ETC1 from ETC2's, and a colour texture (sRGB) in BC1-3 needs one more. */
  override detectSupport(renderer: WebGPURenderer): this {
    super.detectSupport(renderer);
    const backend = renderer.backend as { isWebGLBackend?: boolean; extensions?: { has(name: string): boolean } };
    if (backend.isWebGLBackend && backend.extensions) {
      const has = (name: string) => backend.extensions!.has(name);
      Object.assign(this.workerConfig, {
        bptcSupported: has("EXT_texture_compression_bptc"),
        etc1Supported: has("WEBGL_compressed_texture_etc1"),
        dxtSupported: has("WEBGL_compressed_texture_s3tc") && has("WEBGL_compressed_texture_s3tc_srgb"),
      });
    }
    return this;
  }
}

/** The page's KTX2 loader and the formats its workers were told, which they keep from their start. */
let ktx2: { loader: Ktx2; formats: string } | null = null;

/** `loader` able to read meshopt geometry, and KTX2 textures where `renderer` (started) is given. */
export function withDecoders(loader: GLTFLoader, renderer?: WebGPURenderer): GLTFLoader {
  loader.setMeshoptDecoder(MeshoptDecoder);
  if (renderer) {
    const next = new Ktx2().detectSupport(renderer);
    const formats = JSON.stringify(next.workerConfig);
    // A renderer showing other formats (WebGPU beside its fallback) gets a loader of its own; the earlier one is not
    // disposed, as a figure may still be transcoding in its workers.
    if (ktx2?.formats !== formats) ktx2 = { loader: next, formats };
    loader.setKTX2Loader(ktx2.loader);
  }
  return loader;
}
