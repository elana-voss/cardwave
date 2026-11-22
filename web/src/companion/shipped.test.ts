import { AnimationMixer, type Object3D, Quaternion } from "three";
import { describe, expect, it } from "vitest";
import { CARRIED } from "./clips";
import { clipsFor, type FigureKind, loadFigure } from "../figures/load";
import { withShippedFiles } from "../figures/shipped-files.test-support";
import woman from "../figures/woman.glb";
import man from "../figures/man.glb";

// The shipped clips (tools/companion_assets.py) on the shipped figures and on a user's own (e2e/figures, VRoid's
// names), the files read as figures/shipped-files.test-support.ts hands them to three.js.

withShippedFiles();

/** Every clip the companion plays: each state's, and each it is told to play. */
const PLAYED = Object.keys(CARRIED.moods ?? {});

const turns = (bones: Object3D[]) => bones.map((bone) => bone.quaternion.clone());

describe("the shipped clips", () => {
  it.each([
    ["the woman", woman, "glb"],
    ["the man", man, "glb"],
    ["a user's own figure", "own.vrm", "vrm"],
  ] as [string, string, FigureKind][])("move %s, each clip its arms and legs, never to a broken pose", async (_, url, kind) => {
    const model = await loadFigure(url, kind);
    expect(model.vrm !== null, "read as a VRM").toBe(kind === "vrm");
    const clips = await clipsFor(model);
    expect(clips.map((clip) => clip.name).sort()).toEqual([...PLAYED].sort());
    const limbs = (["leftUpperArm", "rightLowerArm", "leftUpperLeg", "rightLowerLeg"] as const).map((bone) => model.bones.get(bone)!);
    for (const clip of clips) {
      const mixer = new AnimationMixer(model.root);
      mixer.clipAction(clip).play();
      mixer.update(0);
      model.vrm?.update(0);
      const start = turns(limbs);
      mixer.update(clip.duration / 2);
      model.vrm?.update(0);
      const half = turns(limbs);
      expect(half.every((turn) => [turn.x, turn.y, turn.z, turn.w].every(Number.isFinite)), clip.name).toBe(true);
      expect(Math.max(...half.map((turn, at) => 1 - Math.abs(turn.dot(start[at] as Quaternion)))), clip.name).toBeGreaterThan(0);
      mixer.stopAllAction();
      mixer.uncacheRoot(model.root);
    }
  });
});
