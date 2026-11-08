// A card's 3D figure read from its file (`loadFigure`): a VRM (three-vrm), a GLB or an FBX of a rigged human, its
// skeleton matched by its bones' names (skeleton.ts; a VRM names its own), and the carrier (animations.glb,
// tools/companion_assets.py), whose Mixamo clips every figure is given (`clipsFor`, retarget.ts). One that has no human
// skeleton is refused with `Refused`, whose message the dialog shows.
//
// Traps: a VRM is moved by its normalized bones and `update` copies them to the bones it draws, each frame. A VRM
// 0.x looks the other way and is turned (`rotateVRM0`). The figure's root is a group around what the file holds,
// which the companion turns; the rests the clips are made from are taken before it is turned.
import { type AnimationClip, Group, type Object3D } from "three";
import { FBXLoader } from "three/addons/loaders/FBXLoader.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { type VRM, type VRMHumanBoneName, VRMLoaderPlugin, VRMUtils } from "@pixiv/three-vrm";
import carrierUrl from "./animations.glb";
import { retarget, type Rig } from "./retarget";
import { type HumanBone, matchBones } from "./skeleton";
import { wording } from "../language/language";

/** The kinds of file a figure can be, by their ending. */
export const FIGURE_FILES = ".vrm,.glb,.fbx";
export type FigureKind = "vrm" | "glb" | "fbx";

/** A figure no animation can move; its message says why, for the user. */
export class Refused extends Error {}

const refused = () => (wording("load-this-figure-has-no"));

/** A figure read: its rig, and its VRM where it is one. */
export interface Model extends Rig {
  vrm: VRM | null;
}

/** The kind of a file by its name's ending, or none. */
export function kindOf(name: string): FigureKind | null {
  const ending = /\.(vrm|glb|fbx)$/i.exec(name)?.[1]?.toLowerCase();
  return (ending as FigureKind | undefined) ?? null;
}

/** Reads the figure at `url`; `Refused` where its skeleton is not human. */
export async function loadFigure(url: string, kind: FigureKind): Promise<Model> {
  const root = new Group();
  if (kind === "fbx") {
    const object = await new FBXLoader().loadAsync(url);
    root.add(object);
    return { root, bones: named(object), vrm: null };
  }
  const loader = new GLTFLoader();
  loader.register((parser) => new VRMLoaderPlugin(parser));
  const gltf = await loader.loadAsync(url);
  const vrm = (gltf.userData.vrm as VRM | undefined) ?? null;
  if (!vrm) {
    root.add(gltf.scene);
    return { root, bones: named(gltf.scene), vrm: null };
  }
  VRMUtils.rotateVRM0(vrm);
  root.add(vrm.scene);
  const bones = new Map<HumanBone, Object3D>();
  for (const name of Object.keys(vrm.humanoid.humanBones) as VRMHumanBoneName[]) {
    const node = vrm.humanoid.getNormalizedBoneNode(name);
    // VRM's names are those of `HumanBone`.
    if (node) bones.set(name as HumanBone, node);
  }
  if (!bones.has("hips")) throw new Refused(refused());
  return { root, bones, vrm };
}

/** The bones of `object` by their human names; `Refused` where the names make no human skeleton. */
function named(object: Object3D): Map<HumanBone, Object3D> {
  const nodes: Object3D[] = [];
  object.traverse((node) => {
    if ((node as Object3D & { isBone?: boolean }).isBone) nodes.push(node);
  });
  const matched = matchBones(nodes.map((node) => node.name));
  if (!matched) throw new Refused(refused());
  // Each name matched is a node's: `matchBones` was given these nodes' names.
  return new Map([...matched].map(([bone, name]) => [bone, nodes.find((node) => node.name === name)!]));
}

let carrier: Promise<{ rig: Rig; clips: AnimationClip[] }> | null = null;

/** The carrier: its skeleton and clips, read once. */
function loadCarrier(): Promise<{ rig: Rig; clips: AnimationClip[] }> {
  carrier ??= new GLTFLoader().loadAsync(carrierUrl).then((gltf) => {
    const root = new Group();
    root.add(gltf.scene);
    return { rig: { root, bones: named(gltf.scene) }, clips: gltf.animations };
  });
  return carrier;
}

/** The carrier's clips, made the figure's. */
export async function clipsFor(model: Model): Promise<AnimationClip[]> {
  const { rig, clips } = await loadCarrier();
  return retarget(clips, rig, model);
}
