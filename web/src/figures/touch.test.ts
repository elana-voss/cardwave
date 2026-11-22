import { Bone, BoxGeometry, BufferGeometry, Float32BufferAttribute, Group, Mesh, MeshBasicMaterial, OrthographicCamera, Skeleton, SkinnedMesh, Uint16BufferAttribute, Vector3 } from "three";
import { describe, expect, it, vi } from "vitest";
import type { HumanBone } from "./skeleton";
import { prepare } from "./ray";
import { bodyPartAt } from "./touch";

/** A small figure of boxes, 1.84 tall, facing the camera, its human bones where a person's are (its left arm only),
 * but those `without`; with a `chin` in front below its head bone. */
function figure({ without = [] as HumanBone[], chin = false } = {}) {
  const root = new Group();
  const bones = new Map<HumanBone, Bone>();
  const joints: [HumanBone, number, number, number][] = [
    ["hips", 0, 1, 0],
    ["spine", 0, 1.1, 0],
    ["chest", 0, 1.3, 0],
    ["neck", 0, 1.5, 0],
    ["head", 0, 1.6, 0],
    ["leftShoulder", 0.08, 1.45, 0],
    ["leftUpperArm", 0.2, 1.45, 0],
    ["leftLowerArm", 0.25, 1.15, 0],
    ["leftHand", 0.28, 0.9, 0],
    ["leftUpperLeg", 0.1, 0.95, 0],
    ["leftLowerLeg", 0.1, 0.5, 0],
    ["leftFoot", 0.1, 0.08, 0],
    ["leftToes", 0.1, 0, 0.12],
  ];
  for (const [name, x, y, z] of joints.filter(([name]) => !without.includes(name))) {
    const bone = Object.assign(new Bone(), { name });
    bone.position.set(x, y, z);
    root.add(bone);
    bones.set(name, bone);
  }
  const box = (name: string, [x, y, z]: number[], [w, h, d]: number[]) => {
    const mesh = new Mesh(new BoxGeometry(w, h, d), new MeshBasicMaterial());
    Object.assign(mesh, { name }).position.set(x!, y!, z!);
    root.add(mesh);
  };
  box("Head", [0, 1.72, 0], [0.2, 0.24, 0.2]);
  box("Hair", [0, 1.83, 0], [0.22, 0.04, 0.22]);
  box("Neck", [0, 1.55, 0], [0.1, 0.1, 0.1]);
  box("Torso", [0, 1.25, 0], [0.3, 0.5, 0.22]);
  box("Shoulder", [0.13, 1.45, 0], [0.14, 0.08, 0.12]);
  box("UpperArm", [0.235, 1.3, 0], [0.1, 0.3, 0.1]);
  box("LowerArm", [0.265, 1.03, 0], [0.08, 0.26, 0.08]);
  box("Hand", [0.29, 0.83, 0], [0.08, 0.14, 0.04]);
  box("Legs", [0.1, 0.5, 0], [0.16, 0.9, 0.16]);
  box("Foot", [0.1, 0.03, 0.05], [0.1, 0.06, 0.22]);
  if (chin) box("Chin", [0, 1.57, 0.06], [0.12, 0.06, 0.08]);
  const camera = new OrthographicCamera(-1, 1, 2, 0, 0.1, 20);
  camera.position.set(0, 0, 10);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
  /** The part a click lands on, at a point of the figure seen from the front. */
  const at = (x: number, y: number) => {
    root.updateMatrixWorld(true);
    const ndc = new Vector3(x, y, 0).project(camera);
    return bodyPartAt(root, bones, camera, ndc.x, ndc.y);
  };
  return { root, bones, at };
}

describe("which part of the body a click lands on", () => {
  it("tells the face, the hair, the neck, the hand, the arm, the shoulder and the others where they are", () => {
    const { at } = figure();
    expect(at(0, 1.7)).toBe("face");
    expect(at(0, 1.835)).toBe("hair");
    expect(at(0, 1.53)).toBe("neck");
    expect(at(0.17, 1.46)).toBe("shoulder");
    expect(at(0, 1.38)).toBe("chest");
    expect(at(0, 1.15)).toBe("belly");
    expect(at(0.06, 1.02)).toBe("hip");
    expect(at(0.24, 1.3)).toBe("arm");
    expect(at(0.29, 0.83)).toBe("hand");
    expect(at(0.1, 0.7)).toBe("leg");
    expect(at(0.1, 0.03)).toBe("foot");
  });

  it("tells the head and the back of a figure turned away", () => {
    const { root, at } = figure();
    root.rotation.y = Math.PI;
    expect(at(0, 1.7)).toBe("head");
    expect(at(0, 1.38)).toBe("back");
    expect(at(-0.29, 0.83)).toBe("hand");
  });

  it("tells the chest and the neck of a figure without their bones, and its chin below the head bone as the face", () => {
    const { at } = figure({ without: ["chest", "neck"] });
    expect(at(0, 1.38)).toBe("chest");
    expect(at(0, 1.53)).toBe("neck");
    expect(at(0, 1.15)).toBe("belly");
    expect(figure({ chin: true }).at(0, 1.57)).toBe("face");
  });

  it("finds a skinned part where it is posed now, not where it was first measured", () => {
    const { root, bones, at } = figure();
    const hand = bones.get("leftHand")!;
    // A glove 0.3 wide reaching out from the hand, skinned to it alone.
    const glove = new BoxGeometry(0.3, 0.14, 0.04).translate(0.44, 0.83, 0);
    const count = glove.attributes.position!.count;
    glove.setAttribute("skinIndex", new Uint16BufferAttribute(new Array(count * 4).fill(0), 4));
    glove.setAttribute("skinWeight", new Float32BufferAttribute(Array.from({ length: count * 4 }, (_, i) => (i % 4 === 0 ? 1 : 0)), 4));
    const skinned = new SkinnedMesh(glove, new MeshBasicMaterial());
    root.add(skinned);
    root.updateMatrixWorld(true);
    skinned.bind(new Skeleton([hand]));
    skinned.computeBoundingSphere();
    const measured = skinned.boundingSphere!.center.x;
    hand.position.x += 0.4;
    expect(at(0.95, 0.83)).toBe("hand");
    expect(skinned.boundingSphere!.center.x).toBe(measured);
  });

  it("skins only the triangles of the bones the ray passes, not the whole skinned figure", () => {
    const { root, bones, at } = figure();
    // A glove on the hand and a boot on the foot, in one mesh skinned to both.
    const glove = new BoxGeometry(0.1, 0.14, 0.06).translate(0.29, 0.83, 0).toNonIndexed();
    const boot = new BoxGeometry(0.12, 0.1, 0.24).translate(0.1, 0.05, 0.05).toNonIndexed();
    const corners = [...glove.attributes.position!.array, ...boot.attributes.position!.array];
    const count = corners.length / 3;
    const both = new BufferGeometry().setAttribute("position", new Float32BufferAttribute(corners, 3));
    both.setAttribute("skinIndex", new Uint16BufferAttribute(Array.from({ length: count * 4 }, (_, i) => (i % 4 === 0 && i / 4 >= glove.attributes.position!.count ? 1 : 0)), 4));
    both.setAttribute("skinWeight", new Float32BufferAttribute(Array.from({ length: count * 4 }, (_, i) => (i % 4 === 0 ? 1 : 0)), 4));
    const skinned = new SkinnedMesh(both, new MeshBasicMaterial());
    root.add(skinned);
    root.updateMatrixWorld(true);
    skinned.bind(new Skeleton([bones.get("leftHand")!, bones.get("leftFoot")!]));
    const skinning = vi.spyOn(skinned, "getVertexPosition");
    expect(at(0.29, 0.83)).toBe("hand");
    expect(skinning.mock.calls.length).toBeLessThanOrEqual(glove.attributes.position!.count);
  });

  it("groups a skinned figure's triangles when it is placed, not at its first click", () => {
    const { root, bones, at } = figure();
    const glove = new BoxGeometry(0.1, 0.14, 0.06).translate(0.29, 0.83, 0).toNonIndexed();
    const count = glove.attributes.position!.count;
    glove.setAttribute("skinIndex", new Uint16BufferAttribute(new Array(count * 4).fill(0), 4));
    glove.setAttribute("skinWeight", new Float32BufferAttribute(Array.from({ length: count * 4 }, (_, i) => (i % 4 === 0 ? 1 : 0)), 4));
    const skinned = new SkinnedMesh(glove, new MeshBasicMaterial());
    root.add(skinned);
    root.updateMatrixWorld(true);
    skinned.bind(new Skeleton([bones.get("leftHand")!]));
    prepare(root);
    const grouping = vi.spyOn(glove.attributes.skinWeight as Float32BufferAttribute, "getComponent");
    expect(at(0.29, 0.83)).toBe("hand");
    expect(grouping).not.toHaveBeenCalled();
  });

  it("finds no part beside the figure, nor where it has no human bones", () => {
    const { root, at } = figure();
    expect(at(0.8, 1)).toBeNull();
    expect(bodyPartAt(root, new Map(), new OrthographicCamera(), 0, 0)).toBeNull();
  });
});
