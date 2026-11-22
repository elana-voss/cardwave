// Which part of a figure's body a click lands on (`bodyPartAt`), the companion's told to the server as the touch
// (`Occasion::Touched`, `BodyPart`). The ray through the click meets the figure's skin, posed as it is drawn now;
// the point it meets belongs to the nearest stretch of its skeleton (`Stretch`: a bone to the next, each a part of
// the body, thick as a person's is), measured across the bone and, beyond its ends, along it. A mesh or look named
// for hair is the hair wherever it lies; on the head, the front below its top is the face; on the chest and belly,
// what lies behind the spine is the back; the chin, in front of the neck, is the face. A figure without a chest or
// a neck bone has them where they would be. Where the ray meets no skin (a pixel of an outline), the point is where it
// passes the figure's middle, and only a part close by counts.
//
// Traps: the ray is cast by ray.ts (`meet`), not three.js's, which on a large skinned figure takes half a second a
// click. The sizes are shares of the hips to the head (`unit`), so a figure in centimetres is measured as one in
// metres. The figure faces +Z of its root, as glTF and VRM have it (a VRM 0.x is turned to it on load).
import { type Camera, type Intersection, type Material, type Mesh, type Object3D, Plane, Raycaster, Vector2, Vector3 } from "three";
import type { BodyPart } from "../api/generated/BodyPart";
import type { HumanBone, Side } from "./skeleton";
import { meet } from "./ray";

/** A bone to the next, as a part of the body as thick as `radius`. */
interface Stretch {
  part: BodyPart;
  from: Vector3;
  to: Vector3;
  radius: number;
}

/** How thick each part is, as a share of the hips to the head. */
const THICK: Record<BodyPart, number> = { head: 0.17, hair: 0.17, face: 0.17, neck: 0.09, shoulder: 0.12, chest: 0.22, belly: 0.2, back: 0.22, arm: 0.08, hand: 0.07, hip: 0.22, leg: 0.12, foot: 0.08 };
/** How far the head reaches above its bone, the hand past its bone and a foot without toes, as shares of the unit. */
const HEAD_LENGTH = 0.4;
const HAND_LENGTH = 0.35;
const FOOT_LENGTH = 0.2;
/** How long a neck without its bone is, as a share of the unit. */
const NECK_LENGTH = 0.17;
/** How far past a bone's end counts as much as the part's thickness, as a share of the unit. */
const PAST = 0.05;
/** The nearest stretch counts beside the skin only this near (in thicknesses). */
const NEAR = 1.5;
/** The face: the head's front, up to this share of its length above its bone. */
const BROW = 0.75;
const FRONT = 0.3;
/** The chin: in front of the neck past this many of its thicknesses. */
const CHIN = 1.5;
const HAIR = /hair/i;

const SIDES: readonly Side[] = ["left", "right"];
const raycaster = new Raycaster();

/** The part of the body at the click `x`, `y` (the canvas's -1 to 1, y up) on `root` seen by `camera`, its human
 * `bones` as figures/load.ts names them; null beside the figure or where it has no hips and head. */
export function bodyPartAt(root: Object3D, bones: ReadonlyMap<HumanBone, Object3D>, camera: Camera, x: number, y: number): BodyPart | null {
  const hips = bones.get("hips");
  const head = bones.get("head");
  if (!hips || !head) return null;
  root.updateMatrixWorld(true);
  camera.updateMatrixWorld();
  raycaster.setFromCamera(new Vector2(x, y), camera);
  const hit = meet(raycaster, root).find((one) => shown(one.object)) ?? null;
  if (hit && named(hit, HAIR)) return "hair";
  const point = hit?.point ?? raycaster.ray.intersectPlane(new Plane().setFromNormalAndCoplanarPoint(camera.getWorldDirection(new Vector3()), at(hips)), new Vector3());
  if (!point) return null;
  const unit = at(hips).distanceTo(at(head));
  const stretches = skeleton(bones, unit);
  let best: { stretch: Stretch; score: number; along: number; across: Vector3 } | null = null;
  for (const stretch of stretches) {
    const measured = measure(stretch, point, unit);
    if (!best || measured.score < best.score) best = { stretch, ...measured };
  }
  if (!best || (!hit && best.score > NEAR)) return null;
  const forward = new Vector3(0, 0, 1).transformDirection(root.matrixWorld);
  const { stretch, along, across } = best;
  if (stretch.part === "head") {
    const length = stretch.from.distanceTo(stretch.to);
    return along < length * BROW && across.dot(forward) > FRONT * across.length() ? "face" : "head";
  }
  // The chin juts out in front of the neck's top half, past its thickness.
  if (stretch.part === "neck" && along > stretch.from.distanceTo(stretch.to) / 2 && across.dot(forward) > CHIN * stretch.radius) return "face";
  if ((stretch.part === "chest" || stretch.part === "belly") && across.dot(forward) < 0) return "back";
  return stretch.part;
}

/** How far `point` is from `stretch`: across it in its thicknesses, plus how far past its ends; how far along it the
 * point lies and the way across from its bone. */
function measure(stretch: Stretch, point: Vector3, unit: number): { score: number; along: number; across: Vector3 } {
  const axis = stretch.to.clone().sub(stretch.from);
  const length = axis.length();
  const way = length > 0 ? axis.clone().divideScalar(length) : axis;
  const along = point.clone().sub(stretch.from).dot(way);
  const across = point.clone().sub(stretch.from).sub(way.clone().multiplyScalar(along));
  const past = Math.max(0, -along, along - length);
  return { score: across.length() / stretch.radius + past / (PAST * unit), along, across };
}

/** The stretches of the skeleton's bones there are, each its part. */
function skeleton(bones: ReadonlyMap<HumanBone, Object3D>, unit: number): Stretch[] {
  const where = (bone: HumanBone): Vector3 | null => {
    const node = bones.get(bone);
    return node ? at(node) : null;
  };
  const stretches: Stretch[] = [];
  const add = (part: BodyPart, from: Vector3 | null, to: Vector3 | null) => {
    if (from && to) stretches.push({ part, from, to, radius: THICK[part] * unit });
  };
  const beyond = (from: Vector3, to: Vector3, share: number) => to.clone().add(to.clone().sub(from).setLength(share * unit));
  // The middle, bottom to top: each stretch the part of its lower bone.
  const middle: [HumanBone, BodyPart][] = [["hips", "hip"], ["spine", "belly"], ["chest", "chest"], ["upperChest", "chest"], ["neck", "neck"], ["head", "head"]];
  const there = middle.flatMap(([bone, part]) => {
    const point = where(bone);
    return point ? [{ point, part }] : [];
  });
  // A figure without a chest bone has its chest above the middle of its spine to the next; one without a neck
  // bone, its neck the last `NECK_LENGTH` below its head.
  const between = (i: number, share: number) => there[i]!.point.clone().lerp(there[i + 1]!.point, share);
  const spine = there.findIndex(({ part }) => part === "belly");
  if (!bones.has("chest") && !bones.has("upperChest") && spine >= 0 && spine + 1 < there.length) there.splice(spine + 1, 0, { point: between(spine, 0.5), part: "chest" });
  const last = there.length - 1;
  if (!bones.has("neck") && last > 0) {
    const below = there[last]!.point.distanceTo(there[last - 1]!.point);
    there.splice(last, 0, { point: between(last - 1, Math.max(0, 1 - (NECK_LENGTH * unit) / below)), part: "neck" });
  }
  for (let i = 0; i + 1 < there.length; i++) add(there[i]!.part, there[i]!.point, there[i + 1]!.point);
  const head = where("head")!;
  add("head", head, beyond(where("neck") ?? where("hips")!, head, HEAD_LENGTH));
  for (const side of SIDES) {
    const of = (bone: string) => where(`${side}${bone}` as HumanBone);
    const [upperArm, lowerArm, hand] = [of("UpperArm"), of("LowerArm"), of("Hand")];
    add("shoulder", of("Shoulder") ?? where("neck"), upperArm);
    add("arm", upperArm, lowerArm);
    add("arm", lowerArm, hand);
    if (hand) add("hand", hand, of("MiddleDistal") ?? of("MiddleIntermediate") ?? (lowerArm ? beyond(lowerArm, hand, HAND_LENGTH) : null));
    const [upperLeg, lowerLeg, foot] = [of("UpperLeg"), of("LowerLeg"), of("Foot")];
    add("hip", where("hips"), upperLeg);
    add("leg", upperLeg, lowerLeg);
    add("leg", lowerLeg, foot);
    if (foot) add("foot", foot, of("Toes") ?? foot.clone().add(new Vector3(0, -FOOT_LENGTH * unit, 0)));
  }
  return stretches;
}

/** Where `node` is in the world. */
function at(node: Object3D): Vector3 {
  return node.getWorldPosition(new Vector3());
}

/** Whether `object` and all it hangs in are shown (a ray meets hidden meshes too). */
function shown(object: Object3D | null): boolean {
  for (let node = object; node; node = node.parent) if (!node.visible) return false;
  return true;
}

/** Whether the mesh met, or its look there, is named by `pattern`. */
function named(hit: Intersection, pattern: RegExp): boolean {
  const material = (hit.object as Mesh).material as Material | Material[] | undefined;
  const look = Array.isArray(material) ? material[hit.face?.materialIndex ?? 0] : material;
  return pattern.test(hit.object.name) || pattern.test(look?.name ?? "");
}
