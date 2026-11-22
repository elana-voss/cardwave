// The companion's figure as a spec reads it: `watchFigure` has the page keep what three.js draws (its scenes announce
// themselves to `__THREE_DEVTOOLS__`, its renderer too, whose `render` is wrapped to keep the camera), and
// `headAndHand` finds where its head's crown and its left hand are drawn now. Shared by 55-companion and 97-seen.
import type { Page } from "@playwright/test";

/** A point of the page. */
export interface At {
  x: number;
  y: number;
}

/** Has the page keep what three.js draws, as `window.__figure` (its scenes and the camera last drawn with). */
export async function watchFigure(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const kept: { scenes: any[]; camera: any } = { scenes: [], camera: null };
    const hook = new EventTarget();
    hook.addEventListener("observe", (e) => {
      const it = (e as CustomEvent).detail;
      if (it?.isScene) kept.scenes.push(it);
      if (typeof it?.render === "function" && it?.domElement) {
        const render = it.render.bind(it);
        it.render = (scene: unknown, camera: unknown) => ((kept.camera = camera), render(scene, camera));
      }
    });
    Object.assign(window, { __THREE_DEVTOOLS__: hook, __figure: kept });
  });
}

/** Where the figure's head and left hand are drawn now, in the page (after `watchFigure`): the head just under the
 * top of its outline (its crown, never the face), read off the canvas's opaque pixels; the hand at its fingers' roots
 * (its knuckles), its bones as the camera draws them, by Mixamo's, VRoid's or Blender's name of the left hand
 * (`bone`); the hand's own bone where it has no finger. */
export async function headAndHand(page: Page): Promise<{ head: At; hand: At; bone: string }> {
  const canvas = page.locator("canvas.companion-figure");
  const box = (await canvas.boundingBox())!;
  const shot = (await canvas.screenshot({ omitBackground: true })).toString("base64");
  const found = await page.evaluate(async (data) => {
    const img = new Image();
    img.src = `data:image/png;base64,${data}`;
    await img.decode();
    const c = document.createElement("canvas");
    [c.width, c.height] = [img.width, img.height];
    const g = c.getContext("2d")!;
    g.drawImage(img, 0, 0);
    const px = g.getImageData(0, 0, c.width, c.height).data;
    const row = (y: number) => [...Array(c.width).keys()].filter((x) => px[(y * c.width + x) * 4 + 3]! > 200);
    const rows = [...Array(c.height).keys()].filter((y) => row(y).length > 0);
    const [top, bottom] = [rows[0]!, rows.at(-1)!];
    const high = top + Math.round((bottom - top) * 0.02);
    const head = row(high);
    // The hand's bone and its children's (the fingers' roots), as the camera draws them, as shares of the canvas.
    const { scenes, camera } = (window as any).__figure;
    const name = /(left_?hand|l_hand|hand_l|hand\.l)$/i;
    let hand: any = null;
    for (const scene of scenes) scene.traverse((o: any) => void (hand ??= o.isBone && name.test(o.name) ? o : null));
    const drawn = (o: any) => o.getWorldPosition(o.position.clone()).project(camera);
    const wrist = drawn(hand);
    const roots = hand.children.filter((o: any) => o.isBone).map(drawn);
    const palm = roots.length ? roots.reduce((sum: any, v: any) => sum.add(v), wrist.clone().multiplyScalar(0)).divideScalar(roots.length) : wrist;
    return { head: { x: (head[0]! + head.at(-1)!) / 2 / c.width, y: high / c.height }, hand: { x: (palm.x + 1) / 2, y: (1 - palm.y) / 2 }, bone: hand.name as string };
  }, shot);
  const at = ({ x, y }: At) => ({ x: box.x + x * box.width, y: box.y + y * box.height });
  return { head: at(found.head), hand: at(found.hand), bone: found.bone };
}
