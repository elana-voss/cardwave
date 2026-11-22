// A figure's still (`stillOf`): read from its file and drawn once, from the front, as it stands at the start of its idle clip, when it is
// added from a file ("Add a 3D figure"), and kept with it on the server as a PNG with a see-through ground.
//
// Traps: drawn by drawer.ts's renderer, WebGPU or WebGL 2; the picture is read in the task that drew it, as
// neither keeps the frame after, and the renderer is let go of at once (`letGoOf`), as a page has few at a time. The
// figure is read once the renderer has started, which a KTX2 texture needs (decoders.ts).
import { AnimationMixer, Box3, PerspectiveCamera, Scene, Vector3 } from "three";
import { drawer, letGoOf, lit } from "./drawer";
import { clipsFor, type FigureKind, loadFigure, type Model } from "./load";

/** The still's side, in pixels. */
const SIDE = 192;

/** The figure at `url`, of `kind`, drawn, as a PNG in base64; `Refused` as `loadFigure`. */
export async function stillOf(url: string, kind: FigureKind): Promise<string> {
  const canvas = document.createElement("canvas");
  const { renderer, ready } = drawer(canvas);
  try {
    renderer.setSize(SIDE, SIDE, false);
    await ready;
    // Awaited here, or `finally` lets the renderer go before the figure is drawn.
    return await drawn(await loadFigure(url, kind, renderer), (scene, camera) => {
      renderer.render(scene, camera);
      return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
    });
  } finally {
    letGoOf(renderer);
  }
}

/** `model` as it stands at the start of its idle clip, framed from the front, given to `draw`. */
async function drawn(model: Model, draw: (scene: Scene, camera: PerspectiveCamera) => string): Promise<string> {
  const idle = (await clipsFor(model)).find((clip) => clip.name === "idle");
  if (idle) new AnimationMixer(model.root).clipAction(idle).play().getMixer().update(0);
  model.vrm?.update(0);
  const scene = new Scene();
  lit(scene);
  scene.add(model.root);
  model.root.updateMatrixWorld(true);
  const box = new Box3().setFromObject(model.root, true);
  const size = box.getSize(new Vector3());
  const middle = box.getCenter(new Vector3());
  const camera = new PerspectiveCamera(30, 1, 1, 2);
  const view = Math.max(size.x, size.y) * 1.1;
  const distance = view / 2 / Math.tan((camera.fov * Math.PI) / 360) + size.z;
  camera.position.set(middle.x, middle.y, middle.z + distance);
  camera.near = distance / 100;
  camera.far = distance * 10;
  camera.lookAt(middle);
  camera.updateProjectionMatrix();
  return draw(scene, camera);
}
