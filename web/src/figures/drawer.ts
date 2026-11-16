// What every 3D figure is drawn by: three.js's WebGPURenderer (`drawer`), which draws through WebGPU where the browser
// offers an adapter (the desktop app's WebView2) and through its own WebGL 2 backend where it does not, chosen by
// itself, with no setting and no word to the user; it draws once its `ready` has settled, and the console names the
// path taken ("renderer: WebGPU" or "renderer: WebGL 2"); the light every figure shares (`lit`); and the renderer let
// go of with its device or context (`letGoOf`). Made after the mixamo viewer's src/scene/renderer.ts.
//
// Traps: `three` and `three/webgpu` share one core (three.core.js, since three 0.171), so only what draws comes from
// `three/webgpu`. A VRM's MToon is a ShaderMaterial, which this renderer does not draw: it is `MToonNodeMaterial`
// (load.ts). A frame is read (`toDataURL`, `drawImage`) in the task that drew it, as neither backend keeps it after.
import { Color, DirectionalLight, HemisphereLight, type Scene } from "three";
import { WebGPURenderer } from "three/webgpu";

/** A renderer drawing on `canvas` with a see-through ground; it draws once `ready` has settled. */
export function drawer(canvas: HTMLCanvasElement): { renderer: WebGPURenderer; ready: Promise<void> } {
  const renderer = new WebGPURenderer({ canvas, antialias: true, alpha: true });
  renderer.setClearColor(new Color(0x000000), 0);
  const ready = renderer.init().then(() => {
    const backend = (renderer.backend as { isWebGPUBackend?: boolean }).isWebGPUBackend ? "WebGPU" : "WebGL 2";
    console.info(`renderer: ${backend}`);
  });
  return { renderer, ready };
}

/** Lights `scene` from the sky and the sun, as every figure is lit. */
export function lit(scene: Scene): void {
  scene.add(new HemisphereLight(0xffffff, 0x444444, 2.5));
  const sun = new DirectionalLight(0xffffff, 2);
  sun.position.set(3, 10, 5);
  scene.add(sun);
}

/** What of a backend is let go of: WebGPU's device, WebGL's context. */
interface Ends {
  device?: { destroy(): void };
  gl?: WebGL2RenderingContext;
}

/** Lets go of `renderer` and ends its device or context at once, as a page has few of them at a time. */
export function letGoOf(renderer: WebGPURenderer): void {
  // Its end is wanted, so it is not told as a loss.
  renderer.onDeviceLost = () => {};
  renderer.dispose();
  const backend = renderer.backend as unknown as Ends;
  backend.device?.destroy();
  backend.gl?.getExtension("WEBGL_lose_context")?.loseContext();
}
