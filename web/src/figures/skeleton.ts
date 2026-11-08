// A figure's skeleton told by its bones' names: each name matched to a bone of the human skeleton VRM names
// (`HumanBone`), for the common skeletons: Mixamo's ("mixamorig:LeftForeArm", which three.js reads as
// "mixamorigLeftForeArm"), Ready Player Me's (Mixamo's without the prefix), VRoid's ("J_Bip_L_LowerArm"), Unity's
// and VRChat's ("LeftLowerArm", "Left elbow", "LowerArm_L"), and Blender's ("forearm.L", read as "forearmL"). A skeleton without all of `REQUIRED` is
// not one the animations can move, and the figure is refused (`matchBones` answers null).
//
// Traps: "leg" alone is the upper leg in VRChat's names ("Left leg", then "Left knee") but the lower one in
// Mixamo's ("LeftUpLeg", then "LeftLeg"): which it is depends on whether the skeleton has an "upleg".

export type Side = "left" | "right";
type Limb = "Shoulder" | "UpperArm" | "LowerArm" | "Hand" | "UpperLeg" | "LowerLeg" | "Foot" | "Toes";
type Finger = "Thumb" | "Index" | "Middle" | "Ring" | "Little";
type Joint = "Metacarpal" | "Proximal" | "Intermediate" | "Distal";
/** A bone of the human skeleton, as VRM 1.0 names it. */
export type HumanBone = "hips" | "spine" | "chest" | "upperChest" | "neck" | "head" | `${Side}${Limb}` | `${Side}${Finger}${Joint}`;

/** The bones a figure must have to be moved by the animations. */
export const REQUIRED: readonly HumanBone[] = [
  "hips",
  "spine",
  "head",
  ...(["left", "right"] as const).flatMap((side) => (["UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"] as const).map((limb) => `${side}${limb}` as HumanBone)),
];

/** The bone of the body each name stands for, once its side and its separators are gone. */
const CENTRE: Record<string, HumanBone> = { hips: "hips", hip: "hips", pelvis: "hips", spine: "spine", spine1: "chest", chest: "chest", spine2: "upperChest", upperchest: "upperChest", neck: "neck", head: "head" };
const LIMBS: Record<string, Limb> = {
  shoulder: "Shoulder",
  clavicle: "Shoulder",
  arm: "UpperArm",
  upperarm: "UpperArm",
  forearm: "LowerArm",
  lowerarm: "LowerArm",
  elbow: "LowerArm",
  hand: "Hand",
  wrist: "Hand",
  upleg: "UpperLeg",
  upperleg: "UpperLeg",
  thigh: "UpperLeg",
  lowerleg: "LowerLeg",
  knee: "LowerLeg",
  calf: "LowerLeg",
  shin: "LowerLeg",
  foot: "Foot",
  ankle: "Foot",
  toebase: "Toes",
  toes: "Toes",
  toe: "Toes",
};
/** Mixamo's fingers, "LeftHandIndex1" to 3 (the thumb's 1 the metacarpal). */
const FINGERS: Record<string, Finger> = { thumb: "Thumb", index: "Index", middle: "Middle", ring: "Ring", pinky: "Little" };

/** A name without its rig's prefix, in lower case, its side apart. */
function parts(name: string): { side: Side | null; core: string } {
  let s = name.toLowerCase().replace(/^.*:/, "").replace(/^mixamorig\d*_?/, "").replace(/^j_bip_/, "").replace(/^c_/, "").replace(/^def[-_]/, "");
  let side: Side | null = null;
  const take = (pattern: RegExp, found: Side) => {
    if (side || !pattern.test(s)) return;
    side = found;
    s = s.replace(pattern, "");
  };
  take(/^left[\s_.-]*/, "left");
  take(/^right[\s_.-]*/, "right");
  take(/^l[\s_.-]+/, "left");
  take(/^r[\s_.-]+/, "right");
  take(/[\s_.-]*left$/, "left");
  take(/[\s_.-]*right$/, "right");
  take(/[\s_.-]+l$/, "left");
  take(/[\s_.-]+r$/, "right");
  s = s.replace(/[\s_.-]/g, "");
  // Blender's "thigh.L", which three.js reads without its dot (the pattern's groups always match: `!`).
  const glued = /^(.+)([lr])$/.exec(s);
  if (!side && glued && (LIMBS[glued[1]!] || glued[1] === "leg")) return { side: glued[2] === "l" ? "left" : "right", core: glued[1]! };
  return { side, core: s };
}

/** The human bone a name stands for, or none; `mixamoLegs` says "leg" is the lower leg. */
export function humanBoneOf(name: string, mixamoLegs = true): HumanBone | null {
  const { side, core } = parts(name);
  if (!side) return CENTRE[core] ?? null;
  if (core === "leg") return `${side}${mixamoLegs ? "LowerLeg" : "UpperLeg"}`;
  const limb = LIMBS[core];
  if (limb) return `${side}${limb}`;
  const finger = /^hand(thumb|index|middle|ring|pinky)([1-3])$/.exec(core);
  if (!finger) return null;
  const joints: Joint[] = finger[1] === "thumb" ? ["Metacarpal", "Proximal", "Distal"] : ["Proximal", "Intermediate", "Distal"];
  return `${side}${FINGERS[finger[1]!]!}${joints[Number(finger[2]) - 1]!}`;
}

/** Each human bone the names stand for, with the first name that does; null where one of `REQUIRED` is missing. */
export function matchBones(names: readonly string[]): Map<HumanBone, string> | null {
  const mixamoLegs = names.some((name) => parts(name).core === "upleg");
  const found = new Map<HumanBone, string>();
  for (const name of names) {
    const bone = humanBoneOf(name, mixamoLegs);
    if (bone && !found.has(bone)) found.set(bone, name);
  }
  return REQUIRED.every((bone) => found.has(bone)) ? found : null;
}
