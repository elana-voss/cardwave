import { Bone, Mesh, Object3D, Quaternion, Vector3 } from "three";
import { describe, expect, it } from "vitest";
import { BLINK, Blink, LiveFace, RESTING } from "./face";

const shaped = (...names: string[]) =>
  Object.assign(new Mesh(), { morphTargetDictionary: Object.fromEntries(names.map((name, at) => [name, at])), morphTargetInfluences: names.map(() => 0) });

/** The influence of `name` on `mesh`. */
const weight = (mesh: Mesh, name: string) => mesh.morphTargetInfluences![mesh.morphTargetDictionary![name]!]!;

describe("the blink", () => {
  it("shuts and opens the eyes once in a while, at a time drawn between the least and the most", () => {
    const blink = new Blink(() => 0);
    expect(blink.step(BLINK.least - 0.01)).toBe(0);
    expect(blink.step(0.01 + BLINK.shut / 2)).toBeCloseTo(0.5);
    expect(blink.step(BLINK.shut / 2 + BLINK.stay / 2)).toBe(1);
    expect(blink.step(BLINK.stay / 2 + BLINK.open / 2)).toBeCloseTo(0.5);
    expect(blink.step(BLINK.open)).toBe(0);
    // The next one comes no sooner than the least wait.
    expect(blink.step(BLINK.least - 0.01)).toBe(0);
    const late = new Blink(() => 1);
    expect(late.step(BLINK.most - 0.01)).toBe(0);
    expect(late.step(0.01 + BLINK.shut)).toBe(1);
  });
});

describe("the face alive", () => {
  it("rests relaxed, lightly, and shows each feeling's face in its place", () => {
    const face = shaped("relaxed", "mouthSmileLeft", "jawOpen");
    const root = new Object3D().add(face);
    const live = new LiveFace(root, null, null, () => 0.5);
    live.show(0.01, null, 0.3, false);
    expect([weight(face, "relaxed"), weight(face, "mouthSmileLeft"), weight(face, "jawOpen")]).toEqual([RESTING, 0, 0.3]);
    live.show(0.01, "playful", 0, false);
    expect([weight(face, "relaxed"), weight(face, "mouthSmileLeft")]).toEqual([0, 0.7]);
  });

  it("shows the robot surprised when excited, as it has no happy face", () => {
    const head = shaped("Angry", "Sad", "Surprised");
    const live = new LiveFace(new Object3D().add(head), null, null);
    live.show(0.01, "excited", 1, false);
    expect(head.morphTargetInfluences).toEqual([0, 0, 1]);
  });

  it("leaves a face without shapes still", () => {
    const face = shaped("Smile_Big");
    new LiveFace(new Object3D().add(face), null, null).show(0.01, "happy", 1, true);
    expect(face.morphTargetInfluences).toEqual([0]);
  });

  it("turns the eye shapes back to the user as far as the head is turned from them, whatever the head bone's axes", () => {
    const root = new Object3D();
    const head = new Bone();
    // A Mixamo head: the bone's own y along the neck, its z not where the face looks.
    head.quaternion.setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    const face = shaped("eyeLookOutLeft", "eyeLookInRight", "eyeLookInLeft", "eyeLookOutRight", "eyeLookUpLeft", "eyeLookDownLeft");
    root.add(head, face);
    const live = new LiveFace(root, null, head);
    live.show(0.01, null, 0, true);
    expect(face.morphTargetInfluences).toEqual([0, 0, 0, 0, 0, 0]);
    // The figure turned to its own left: its eyes turn to its right.
    root.quaternion.copy(new Quaternion().setFromAxisAngle(new Vector3(0, 1, 0), 0.2));
    root.updateMatrixWorld(true);
    live.show(0.01, null, 0, true);
    expect(weight(face, "eyeLookOutLeft")).toBe(0);
    expect(weight(face, "eyeLookInLeft")).toBeCloseTo(0.2 / 0.35);
    expect(weight(face, "eyeLookUpLeft")).toBe(0);
    live.show(0.01, null, 0, false);
    expect(weight(face, "eyeLookInLeft")).toBe(0);
  });

  it("turns eye bones to the user, as far as they reach", () => {
    const root = new Object3D();
    const eye = Object.assign(new Bone(), { name: "mixamorig:LeftEye" });
    eye.quaternion.setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2);
    root.add(eye);
    const live = new LiveFace(root, null, null);
    root.quaternion.setFromAxisAngle(new Vector3(0, 1, 0), 0.2);
    root.updateMatrixWorld(true);
    live.show(0.01, null, 0, true);
    eye.updateWorldMatrix(true, false);
    const looks = new Vector3(0, 0, 1).applyQuaternion(eye.getWorldQuaternion(new Quaternion()).multiply(new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), Math.PI / 2)));
    expect(looks.x).toBeCloseTo(0);
    live.show(0.01, null, 0, false);
    expect(eye.quaternion.angleTo(new Quaternion().setFromAxisAngle(new Vector3(1, 0, 0), -Math.PI / 2))).toBeCloseTo(0);
  });
});
