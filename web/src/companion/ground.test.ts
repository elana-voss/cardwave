import { AnimationMixer } from "three";
import { describe, expect, it } from "vitest";
import { CARRIED } from "./clips";
import { standing } from "./figure";
import { Ground, Soles } from "./ground";
import { clipsFor, loadFigure } from "../figures/load";
import { withShippedFiles } from "../figures/shipped-files.test-support";
import woman from "../figures/woman.glb";

withShippedFiles();

describe("the figure on the floor", () => {
  it("rests lying or getting up on the floor as standing, neither hovering nor sinking, and still leaves it in a jump; each walk's feet have their own pace", { timeout: 120_000 }, async () => {
    const model = await loadFigure(woman, "glb");
    const clips = await clipsFor(model);
    const mixer = new AnimationMixer(model.root);
    const stood = standing(model.root, mixer, clips, CARRIED, model.vrm);
    const height = stood.max.y - stood.min.y;
    const ground = new Ground(model.root, stood, model.vrm?.humanoid ?? null);
    const soles = new Soles(model.root);
    const clip = (name: string) => clips.find((one) => one.name === name)!;
    /** The least and largest gap of the lowest point over the floor through `name`, as shares of the height. */
    const gaps = (name: string): [number, number] => {
      const action = mixer.clipAction(clip(name)).play();
      let [low, high] = [Infinity, -Infinity];
      for (let frame = 0; frame <= clip(name).duration * 10; frame++) {
        mixer.setTime(frame / 10);
        model.vrm?.update(0);
        ground.settle(new Map([[action, 1]]));
        const gap = (soles.lowest() - stood.min.y) / height;
        [low, high] = [Math.min(low, gap), Math.max(high, gap)];
      }
      action.stop();
      return [low, high];
    };
    for (const name of ["laying_idle", "getting_up", "falling_down"]) {
      const [low] = gaps(name);
      expect(Math.abs(low), name).toBeLessThan(0.01);
    }
    expect(gaps("jump")[1]).toBeGreaterThan(0.2);
    // Measured by the feet's bones before (.checklists/160-clips.txt): walking 0.51-0.55, walking_2 0.15.
    expect(ground.paceOf(clip("walking"))).toBeGreaterThan(0.4);
    expect(ground.paceOf(clip("walking"))).toBeLessThan(0.65);
    expect(ground.paceOf(clip("walking_2"))).toBeLessThan(0.25);
  });
});
