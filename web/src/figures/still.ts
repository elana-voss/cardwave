// A figure's still (`stillOf`): drawn once, from the front, as it stands at the start of its idle clip, when it is
// added from a file ("Add a 3D figure"), and kept with it on the server as a PNG with a see-through ground.
//
// Traps: a page has few WebGL drawings at once, so the one used here is let go of at once (`forceContextLoss`).
import { AnimationMixer, Box3, DirectionalLight, HemisphereLight, PerspectiveCamera, Scene, Vector3, WebGLRenderer } from "three";
import { clipsFor, type Model } from "./load";

/** The still's side, in pixels. */
const SIDE = 192;

/** The figure drawn, as a PNG in base64. */
export async function stillOf(model: Model): Promise<string> {
  const idle = (await clipsFor(model)).find((clip) => clip.name === "idle");
  if (idle) new AnimationMixer(model.root).clipAction(idle).play().getMixer().update(0);
  model.vrm?.update(0);
  const scene = new Scene();
  scene.add(new HemisphereLight(0xffffff, 0x444444, 2.5));
  const sun = new DirectionalLight(0xffffff, 2);
  sun.position.set(3, 10, 5);
  scene.add(sun, model.root);
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
  const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
  try {
    renderer.setClearColor(0x000000, 0);
    renderer.setSize(SIDE, SIDE, false);
    renderer.render(scene, camera);
    return canvas.toDataURL("image/png").replace(/^data:image\/png;base64,/, "");
  } finally {
    renderer.dispose();
    renderer.forceContextLoss();
  }
}
