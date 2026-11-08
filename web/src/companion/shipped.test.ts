import { readFileSync } from "node:fs";
import { join } from "node:path";
import { AnimationMixer, Cache, type Object3D, Quaternion } from "three";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { CARRIED } from "./clips";
import { clipsFor, type FigureKind, loadFigure } from "../figures/load";
import carrier from "../figures/animations.glb";
import woman from "../figures/woman.glb";
import man from "../figures/man.glb";

// The shipped clips (tools/companion_assets.py) on the shipped figures and on a user's own (e2e/figures, VRoid's
// names): the files are handed to three.js through its cache, as a test has no server; the figures' pictures are
// dropped, as nothing here draws them.

/** The GLB `bytes` without its pictures. */
function withoutPictures(bytes: Buffer): ArrayBuffer {
  const length = bytes.readUInt32LE(12);
  const json = JSON.parse(bytes.subarray(20, 20 + length).toString("utf8")) as Record<string, unknown> & { materials?: unknown[] };
  for (const key of ["images", "textures", "samplers", "extensionsUsed", "extensionsRequired"]) delete json[key];
  if (json.materials) json.materials = json.materials.map(() => ({}));
  let text = JSON.stringify(json);
  text += " ".repeat((4 - (text.length % 4)) % 4);
  const head = Buffer.alloc(20);
  const rest = bytes.subarray(20 + length);
  head.writeUInt32LE(0x46546c67, 0);
  head.writeUInt32LE(2, 4);
  head.writeUInt32LE(20 + text.length + rest.length, 8);
  head.writeUInt32LE(text.length, 12);
  head.writeUInt32LE(0x4e4f534a, 16);
  const whole = Buffer.concat([head, Buffer.from(text, "utf8"), rest]);
  return whole.buffer.slice(whole.byteOffset, whole.byteOffset + whole.byteLength);
}

/** A file by its path from the folder `web`, where the tests run. */
const file = (...path: string[]) => readFileSync(join(process.cwd(), ...path));

beforeAll(() => {
  Cache.enabled = true;
  Cache.add(carrier, withoutPictures(file("src", "figures", "animations.glb")));
  Cache.add(woman, withoutPictures(file("src", "figures", "woman.glb")));
  Cache.add(man, withoutPictures(file("src", "figures", "man.glb")));
  Cache.add("own.vrm", withoutPictures(file("..", "e2e", "figures", "mannequin.vrm")));
});
afterAll(() => {
  Cache.clear();
  Cache.enabled = false;
});

/** Every clip the companion plays: each state's, and each it is told to play. */
const PLAYED = [...new Set([...Object.values(CARRIED.states).map((state) => state.clip), ...Object.values(CARRIED.clips)])];

const turns = (bones: Object3D[]) => bones.map((bone) => bone.quaternion.clone());

describe("the shipped clips", () => {
  it.each([
    ["the woman", woman, "glb"],
    ["the man", man, "glb"],
    ["a user's own figure", "own.vrm", "vrm"],
  ] as [string, string, FigureKind][])("move %s, each clip its arms and legs, never to a broken pose", async (_, url, kind) => {
    const model = await loadFigure(url, kind);
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
