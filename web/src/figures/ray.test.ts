import { Bone, BoxGeometry, type BufferGeometry, DoubleSide, Float32BufferAttribute, FrontSide, Group, MeshBasicMaterial, PlaneGeometry, Raycaster, Skeleton, SkinnedMesh, type Side, Uint16BufferAttribute, Vector3 } from "three";
import { describe, expect, it } from "vitest";
import { meet } from "./ray";

/** A joint: an upper bone at the origin and a lower one at (0, 1), with `geometry` skinned to the lower by `lower`
 * of its weight and to the upper by the rest. */
function joint(geometry: BufferGeometry, lower = 1, side: Side = FrontSide) {
  const root = new Group();
  const [upper, below] = [new Bone(), new Bone()];
  below.position.set(0, 1, 0);
  upper.add(below);
  root.add(upper);
  const count = geometry.attributes.position!.count;
  geometry.setAttribute("skinIndex", new Uint16BufferAttribute(Array.from({ length: count * 4 }, (_, i) => [1, 0, 0, 0][i % 4]!), 4));
  geometry.setAttribute("skinWeight", new Float32BufferAttribute(Array.from({ length: count * 4 }, (_, i) => [lower, 1 - lower, 0, 0][i % 4]!), 4));
  const mesh = new SkinnedMesh(geometry, new MeshBasicMaterial({ side }));
  root.add(mesh);
  root.updateMatrixWorld(true);
  mesh.bind(new Skeleton([upper, below]));
  return { root, below, mesh };
}

/** Whether a ray along z through (x, y), from `z`, meets something of `root`. */
function met(root: Group, x: number, y: number, z = 5): boolean {
  return meet(new Raycaster(new Vector3(x, y, z), new Vector3(0, 0, -Math.sign(z))), root).length > 0;
}

describe("meet", () => {
  it("meets a corner pulled by two bones where the bent joint puts it, between where each would carry it", () => {
    const { root, below } = joint(new BoxGeometry(0.1, 0.1, 0.1).translate(0, 1.5, 0), 0.6);
    below.rotation.z = Math.PI / 2;
    root.updateMatrixWorld(true);
    // The lower bone alone would carry it to (-0.5, 1), the upper to (0, 1.5); 0.6 and 0.4 of each.
    expect(met(root, -0.3, 1.2)).toBe(true);
  });

  it("meets corners where a face shape moves them", () => {
    const geometry = new BoxGeometry(0.1, 0.1, 0.1).translate(0, 1.5, 0);
    const moved = geometry.attributes.position!.array.map((_, i) => (i % 3 === 0 ? 0.5 : 0));
    geometry.morphAttributes.position = [new Float32BufferAttribute(moved, 3)];
    geometry.morphTargetsRelative = true;
    const { root, mesh } = joint(geometry);
    mesh.updateMorphTargets();
    mesh.morphTargetInfluences![0] = 1;
    expect(met(root, 0.5, 1.5)).toBe(true);
  });

  it("meets the back of a look drawn on one side only not at all, of one drawn on both sides", () => {
    const front = joint(new PlaneGeometry(0.2, 0.2).translate(0, 1.5, 0));
    expect(met(front.root, 0, 1.5)).toBe(true);
    expect(met(front.root, 0, 1.5, -5)).toBe(false);
    const both = joint(new PlaneGeometry(0.2, 0.2).translate(0, 1.5, 0), 1, DoubleSide);
    expect(met(both.root, 0, 1.5, -5)).toBe(true);
  });
});
