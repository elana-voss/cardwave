import { AnimationMixer, BoxGeometry, Mesh, MeshStandardMaterial, Object3D } from "three";
import { describe, expect, it, vi } from "vitest";
import { letGo, mouthOf, newest, showFace, turned } from "./figure";

describe("the figure turned", () => {
  it("turns to where it goes over a moment, not at once, and the short way round", () => {
    const now = turned(0, Math.PI / 2, 0.05);
    expect(now).toBeGreaterThan(0);
    expect(now).toBeLessThan(Math.PI / 2);
    expect(turned(now, Math.PI / 2, 5)).toBeCloseTo(Math.PI / 2);
    expect(turned(Math.PI * 0.9, -Math.PI * 0.9, 0.01)).toBeGreaterThan(Math.PI * 0.9);
  });
});

describe("the face", () => {
  it("opens a VRM's mouth with the voice's loudness, and moves no face that has no mouth shapes", () => {
    const set = vi.fn();
    showFace(null, { expressionManager: { setValue: set } }, null, 0.6);
    expect(set).toHaveBeenCalledWith("aa", 0.6);
    // The robot's faces are feelings, none of them a mouth: a voice leaves them as they are.
    const robot = Object.assign(new Mesh(), { morphTargetDictionary: { Angry: 0, Sad: 1, Surprised: 2 }, morphTargetInfluences: [0, 0, 0] });
    showFace(robot, null, null, 1);
    expect(robot.morphTargetInfluences).toEqual([0, 0, 0]);
    showFace(robot, null, "sad", 1);
    expect(robot.morphTargetInfluences).toEqual([0, 1, 0]);
  });

  it("opens the mouth as loud as the voice is, over a moment, and shuts it in silence", () => {
    const opening = mouthOf(0, 0.15, 1 / 60);
    expect(opening).toBeGreaterThan(0);
    let open = opening;
    for (let frame = 0; frame < 30; frame++) open = mouthOf(open, 0.15, 1 / 60);
    expect(open).toBeGreaterThan(0.5);
    expect(mouthOf(open, 1, 1)).toBeLessThanOrEqual(1);
    for (let frame = 0; frame < 30; frame++) open = mouthOf(open, 0, 1 / 60);
    expect(open).toBeLessThan(0.05);
  });
});

describe("the figure changed", () => {
  it("is the newest one asked for, however long an earlier one took to load", async () => {
    let finish: (name: string) => void = () => {};
    const load = newest((name: string) => (name === "slow" ? new Promise<string>((done) => (finish = done)) : Promise.resolve(name)));
    const slow = load("slow");
    expect(await load("fast")).toBe("fast");
    finish("slow");
    expect(await slow).toBeUndefined();
  });

  it("lets go of what the one before held", () => {
    const model = new Object3D();
    const geometry = new BoxGeometry();
    const material = new MeshStandardMaterial();
    model.add(new Mesh(geometry, material));
    const [shape, look] = [vi.spyOn(geometry, "dispose"), vi.spyOn(material, "dispose")];
    letGo(model, new AnimationMixer(model));
    expect([shape, look].map((spy) => spy.mock.calls.length)).toEqual([1, 1]);
  });
});
