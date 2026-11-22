import { Mesh, Object3D } from "three";
import { describe, expect, it, vi } from "vitest";
import { Faces } from "./face";

/** A mesh carrying the shapes `names`, each at 0. */
const shaped = (...names: string[]) =>
  Object.assign(new Mesh(), { morphTargetDictionary: Object.fromEntries(names.map((name, at) => [name, at])), morphTargetInfluences: names.map(() => 0) });

const figure = (...meshes: Mesh[]) => {
  const root = new Object3D();
  for (const mesh of meshes) root.add(mesh);
  return root;
};

describe("the faces matched to a figure's shapes", () => {
  it("matches Apple's face tracking names regardless of case, and only those the figure has", () => {
    const face = shaped("JawOpen", "EYEBLINKLEFT", "mouthsmileleft", "browInnerUp", "Unrelated");
    const faces = new Faces(figure(face), null);
    faces.set("open", 0.5);
    faces.set("blink", 1);
    faces.set("happy", 0.7);
    faces.set("surprised", 0.3);
    expect(face.morphTargetInfluences).toEqual([0.5, 1, 0.7, 0.3, 0]);
    expect(faces.has("angry")).toBe(false);
  });

  it("matches DAZ Studio's names of Genesis 9's dials, ARKit's with facs_bs_ before them, the inner brows in halves", () => {
    const face = shaped("facs_bs_EyeBlinkLeft", "facs_bs_EyeBlinkRight", "facs_bs_JawOpen", "facs_bs_MouthSmileLeft", "facs_bs_BrowInnerUpLeft", "facs_bs_BrowInnerUpRight", "facs_bs_JawOpen_NoJaw");
    const faces = new Faces(figure(face), null);
    faces.set("blink", 1);
    faces.set("open", 0.4);
    faces.set("happy", 0.6);
    faces.set("surprised", 0.2);
    expect(face.morphTargetInfluences).toEqual([1, 1, 0.4, 0.6, 0.2, 0.2, 0]);
  });

  it("matches the robot's three and VRM-named shapes", () => {
    const robot = shaped("Angry", "Sad", "Surprised");
    const faces = new Faces(figure(robot), null);
    faces.set("sad", 1);
    expect(robot.morphTargetInfluences).toEqual([0, 1, 0]);
    expect(faces.has("happy")).toBe(false);
    const named = shaped("Blink", "aa", "Relaxed");
    const other = new Faces(figure(named), null);
    for (const face of ["blink", "open", "relaxed"] as const) other.set(face, 1);
    expect(named.morphTargetInfluences).toEqual([1, 1, 1]);
  });

  it("drives the shape on every mesh that carries it, not one", () => {
    const meshes = [shaped("EyeBlinkLeft"), shaped("BrowInnerUp", "EyeBlinkLeft"), shaped("eyeblinkleft")];
    new Faces(figure(...meshes), null).set("blink", 1);
    expect(meshes.map((mesh) => mesh.morphTargetInfluences)).toEqual([[1], [0, 1], [1]]);
  });

  it("drives only the first group the figure has, so a blink does not shut the eyes twice", () => {
    const face = shaped("blink", "eyeBlinkLeft", "eyeBlinkRight");
    new Faces(figure(face), null).set("blink", 1);
    expect(face.morphTargetInfluences).toEqual([0, 1, 1]);
  });

  it("drives ARKit's names alone where a figure has VRM's names for the same face too", () => {
    const face = shaped("mouthSmileLeft", "happy", "eyeBlinkLeft", "blinkLeft", "blinkRight");
    const faces = new Faces(figure(face), null);
    faces.set("happy", 1);
    faces.set("blink", 1);
    expect(face.morphTargetInfluences).toEqual([1, 0, 1, 0, 0]);
  });

  it("leaves a figure with none of the shapes still", () => {
    const face = shaped("Fcl_MTH_A", "Smile_Big");
    const faces = new Faces(figure(face), null);
    faces.set("happy", 1);
    expect(face.morphTargetInfluences).toEqual([0, 0]);
  });

  it("speaks a VRM's expressions and leaves its own shapes to them", () => {
    const setValue = vi.fn();
    const had = new Set(["happy", "aa", "blink", "relaxed"]);
    const face = shaped("happy");
    const faces = new Faces(figure(face), { expressionManager: { getExpression: (name) => had.has(name) || undefined, setValue } });
    faces.set("open", 0.4);
    faces.set("angry", 1);
    expect(setValue).toHaveBeenCalledWith("aa", 0.4);
    expect(setValue).toHaveBeenCalledTimes(1);
    faces.set("happy", 1);
    expect(face.morphTargetInfluences).toEqual([0]);
    expect(faces.has("relaxed")).toBe(true);
  });
});
