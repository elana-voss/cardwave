import { AnimationClip, AnimationMixer, Bone, Euler, Group, Quaternion, QuaternionKeyframeTrack, Vector3, VectorKeyframeTrack } from "three";
import { describe, expect, it } from "vitest";
import { retarget, type Rig } from "./retarget";
import type { HumanBone } from "./skeleton";

/** A rig of hips, spine and head: the hips `high` above the root, each bone's rest turned by its Euler angles. */
function rig(prefix: string, high: number, turns: [number, number, number][], scale = 1): Rig {
  const root = new Group();
  const holder = new Group();
  holder.scale.setScalar(scale);
  root.add(holder);
  const names: HumanBone[] = ["hips", "spine", "head"];
  const bones = new Map<HumanBone, Bone>();
  let parent: Group | Bone = holder;
  names.forEach((name, at) => {
    const bone = new Bone();
    bone.name = `${prefix}${name}`;
    bone.position.set(0, at === 0 ? high / scale : 0.2 / scale, 0);
    bone.quaternion.setFromEuler(new Euler(...turns[at]!));
    parent.add(bone);
    bones.set(name, bone);
    parent = bone;
  });
  return { root, bones };
}

/** The world rotation of a bone relative to the root. */
const world = (r: Rig, bone: HumanBone) => {
  r.root.updateMatrixWorld(true);
  return r.bones.get(bone)!.getWorldQuaternion(new Quaternion());
};

describe("the carrier's clips made another figure's", () => {
  it("turn each bone as the carrier's turns away from its rest, and raise the hips in proportion", () => {
    const carrier = rig("mixamorig", 1, [[0.3, 0, 0], [0, 0.5, 0.2], [0.1, 0.1, 0]], 0.01);
    const figure = rig("J_Bip_", 0.5, [[0, -0.4, 0], [0.2, 0, 0], [0, 0, -0.6]]);
    const rest = { carrier: world(carrier, "spine"), figure: world(figure, "spine") };
    const turn = new Quaternion().setFromEuler(new Euler(0.4, -0.2, 0.7));
    const spine = carrier.bones.get("spine")!.quaternion.clone().multiply(turn);
    const hips = carrier.bones.get("hips")!.position;
    const clip = new AnimationClip("idle", 1, [
      new QuaternionKeyframeTrack("mixamorigspine.quaternion", [0, 1], [...spine.toArray(), ...spine.toArray()]),
      // Forward and up by 0.2 of the carrier's metres, in its bones' hundredths.
      new VectorKeyframeTrack("mixamorighips.position", [0, 1], [hips.x, hips.y + 20, hips.z + 20, hips.x, hips.y + 20, hips.z + 20]),
    ]);

    const [made] = retarget([clip], carrier, figure);
    expect(made!.name).toBe("idle");
    figure.root.updateMatrixWorld(true);
    const before = figure.bones.get("hips")!.getWorldPosition(new Vector3()).y;
    new AnimationMixer(figure.root).clipAction(made!).play().getMixer().update(0.5);
    new AnimationMixer(carrier.root).clipAction(clip).play().getMixer().update(0.5);

    // The same turn away from rest, in the root's frame.
    const moved = (r: Rig, at: Quaternion) => world(r, "spine").multiply(at.clone().invert());
    expect(moved(figure, rest.figure).angleTo(moved(carrier, rest.carrier))).toBeLessThan(1e-5);
    // Up by half as much, as its hips are half as high; not forward.
    figure.root.updateMatrixWorld(true);
    const hipsNow = figure.bones.get("hips")!.getWorldPosition(new Vector3());
    expect(hipsNow.y - before).toBeCloseTo(0.1, 5);
    expect(hipsNow.z).toBeCloseTo(0, 5);
  });
});
