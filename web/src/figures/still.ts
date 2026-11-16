// A figure's still (`stillOf`): drawn once, from the front, as it stands at the start of its idle clip, when it is
// added from a file ("Add a 3D figure"), and kept with it on the server as a PNG with a see-through ground.
//
// Traps: drawn by drawer.ts's renderer, WebGPU or WebGL 2; the picture is read in the task that drew it, as
// neither keeps the frame after, and the renderer is let go of at once (`letGoOf`), as a page has few at a time.
import { AnimationMixer, Box3, PerspectiveCamera, Scene, Vector3 } from "three";
import { drawer, letGoOf, lit } from "./drawer";
import { clipsFor, type Model } from "./load";

/** The still's side, in pixels. */
const SIDE = 192;

/** The figure drawn, as a PNG in base64. */
export async function stillOf(model: Model): Promise<string> {
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
  const canvas = document.createElement("canvas");
  const { renderer, ready } = drawer(canvas);
  try {
    renderer.setSize(SIDE, SIDE, false);
    await ready;
    renderer.render(scene, camera);
    return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
  } finally {
    letGoOf(renderer);
  }
}
