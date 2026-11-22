import { AnimationClip, AnimationMixer, Bone, Box3, BoxGeometry, Float32BufferAttribute, Mesh, MeshStandardMaterial, Object3D, Skeleton, SkinnedMesh, Uint16BufferAttribute, Vector3, VectorKeyframeTrack } from "three";
import { describe, expect, it, vi } from "vitest";
import { FILL } from "./body";
import { ROBOT } from "./clips";
import { facing, framing, letGo, mouthOf, newest, standing, turned } from "./figure";

describe("the figure turned", () => {
  it("turns to where it goes over a moment, not at once, and the short way round", () => {
    const now = turned(0, Math.PI / 2, 0.05);
    expect(now).toBeGreaterThan(0);
    expect(now).toBeLessThan(Math.PI / 2);
    expect(turned(now, Math.PI / 2, 5)).toBeCloseTo(Math.PI / 2);
    expect(turned(Math.PI * 0.9, -Math.PI * 0.9, 0.01)).toBeGreaterThan(Math.PI * 0.9);
  });

  it("faces the user however often it has turned round", () => {
    expect(facing(0.1)).toBe(true);
    expect(facing(Math.PI * 2 + 0.1)).toBe(true);
    expect(facing(-Math.PI * 4)).toBe(true);
    expect(facing(Math.PI)).toBe(false);
  });
});

describe("the face", () => {
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

describe("the figure framed", () => {
  it("stands its feet on the canvas's foot, at every depth of its feet and in metres or centimetres", () => {
    for (const unit of [1, 100]) {
      const stood = new Box3(new Vector3(-0.4, 0, -0.15).multiplyScalar(unit), new Vector3(0.4, 1.7, 0.15).multiplyScalar(unit));
      const camera = framing(stood, 200 / 260);
      camera.updateMatrixWorld();
      for (const z of [-0.15, 0, 0.15]) expect(new Vector3(0, 0, z * unit).project(camera).y).toBeCloseTo(-1, 3);
      // The figure standing takes FILL of the canvas's height.
      expect(new Vector3(0, 1.7 * unit, 0).project(camera).y).toBeCloseTo(-1 + 2 * FILL, 3);
    }
  });
});

describe("the figure standing", () => {
  it("is measured as its idle clip poses it, not as its file left it", () => {
    // A box of skin on one bone, which the idle clip moves 0.2 down: the feet the clips stand on are there.
    const geometry = new BoxGeometry(0.4, 1, 0.2).translate(0, 0.5, 0);
    const count = geometry.getAttribute("position").count;
    geometry.setAttribute("skinIndex", new Uint16BufferAttribute(new Array(count * 4).fill(0), 4));
    geometry.setAttribute("skinWeight", new Float32BufferAttribute(Array.from({ length: count * 4 }, (_, i) => (i % 4 === 0 ? 1 : 0)), 4));
    const bone = new Bone();
    bone.name = "hips";
    const skin = new SkinnedMesh(geometry, new MeshStandardMaterial());
    const model = new Object3D().add(bone, skin);
    skin.bind(new Skeleton([bone]));
    const idle = new AnimationClip("Idle", 1, [new VectorKeyframeTrack("hips.position", [0, 1], [0, -0.2, 0, 0, -0.2, 0])]);
    const box = standing(model, new AnimationMixer(model), [idle], ROBOT, null);
    expect(box.min.y).toBeCloseTo(-0.2, 3);
    expect(box.max.y).toBeCloseTo(0.8, 3);
  });
});
