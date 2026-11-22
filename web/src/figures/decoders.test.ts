import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { WorkerPool } from "three/addons/utils/WorkerPool.js";
import type { WebGPURenderer } from "three/webgpu";
import { describe, expect, it, vi } from "vitest";
import { guarded, withDecoders } from "./decoders";

/** A renderer on WebGL 2 (WebGPU's fallback) whose GPU has only the extensions `has`. */
const onWebGl = (...has: string[]) => {
  const features: Record<string, string> = { WEBGL_compressed_texture_s3tc: "texture-compression-bc", WEBGL_compressed_texture_etc: "texture-compression-etc2" };
  const extensions = { has: (name: string) => has.includes(name) };
  const hasFeature = (feature: string) => has.some((name) => features[name] === feature);
  return { isWebGPURenderer: true, backend: { isWebGLBackend: true, extensions }, hasFeature } as unknown as WebGPURenderer;
};

describe("the KTX2 textures' format", () => {
  it("is one the WebGL fallback can show: BC7 and ETC1 only with their own extensions, BC1-3 only with sRGB", () => {
    const config = (...has: string[]) => (withDecoders(new GLTFLoader(), onWebGl(...has)) as unknown as { ktx2Loader: { workerConfig: Record<string, boolean> } }).ktx2Loader.workerConfig;
    expect(config("WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_etc")).toMatchObject({ dxtSupported: false, bptcSupported: false, etc2Supported: true, etc1Supported: false });
    expect(config("WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_s3tc_srgb")).toMatchObject({ dxtSupported: true, bptcSupported: false });
  });

  it("is told to the workers: a renderer showing other formats gets a loader of its own, one showing the same shares it", () => {
    const ktx2 = (...has: string[]) => (withDecoders(new GLTFLoader(), onWebGl(...has)) as unknown as { ktx2Loader: object }).ktx2Loader;
    const bc = ktx2("WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_s3tc_srgb");
    expect(ktx2("WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_s3tc_srgb")).toBe(bc);
    expect(ktx2("WEBGL_compressed_texture_etc")).not.toBe(bc);
  });
});

describe("the KTX2 transcoder's worker failing", () => {
  /** A worker that takes tasks and answers none, as one whose transcoder never loaded. */
  const silent = () => Object.assign(new EventTarget(), { postMessage: vi.fn(), terminate: vi.fn() }) as unknown as Worker;

  it("answers its task and every later one with an error, once it did not start or its transcoder did not load", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    for (const fails of [(worker: Worker) => worker.dispatchEvent(new Event("error")), (worker: Worker) => worker.dispatchEvent(new MessageEvent("message", { data: { type: "broken", error: "no wasm" } }))]) {
      const worker = silent();
      const pool = new WorkerPool(1);
      pool.setWorkerCreator(() => guarded(worker));
      const first = pool.postMessage({ type: "transcode" }, []);
      const second = pool.postMessage({ type: "transcode" }, []);
      fails(worker);
      for (const answer of await Promise.all([first, second])) expect((answer as MessageEvent).data).toMatchObject({ type: "error" });
      expect(worker.terminate).toHaveBeenCalled();
    }
  });
});
