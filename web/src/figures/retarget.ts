// The carrier's clips made the clips of another figure (`retarget`): each bone's turn, as the carrier's skeleton
// has it, turned into the same turn of the figure's bone of that human name, from the rotations both have at rest,
// which are a T-pose in both (Mixamo, VRM and the other common skeletons stand so).
//
// The turn of a bone away from rest, measured in the figure's own frame, is `parentRest · local · rest⁻¹`
// (world rotations at rest, relative to the figure's root); the figure's bone then takes
// `itsParentRest⁻¹ · turn · itsRest`. Bones between two the names match keep their rest. A VRM's bones are its
// normalized ones (three-vrm's), whose rest is no rotation, so the turn is theirs as it is.
//
// Of the hips' place only the height is kept, scaled by how high the two hips are: the companion moves the figure
// over the screen itself, so a clip that walks forward walks on the spot.
import { AnimationClip, Matrix4, type Object3D, Quaternion, QuaternionKeyframeTrack, Vector3, VectorKeyframeTrack, type KeyframeTrack } from "three";
import type { HumanBone } from "./skeleton";

/** A figure's skeleton: its root, which the clips play on, and its bone of each human name it has. */
export interface Rig {
  root: Object3D;
  bones: Map<HumanBone, Object3D>;
}

/** A bone at rest, relative to the rig's root: its rotation, its parent's, and its parent's whole place. */
interface Rest {
  bone: HumanBone;
  rotation: Quaternion;
  parent: Quaternion;
  parentMatrix: Matrix4;
  position: Vector3;
}

/** Each bone's rest of the rig, by the node's name and by its human name. */
function rests(rig: Rig): Map<string, Rest> {
  rig.root.updateMatrixWorld(true);
  const toRoot = rig.root.matrixWorld.clone().invert();
  const found = new Map<string, Rest>();
  for (const [bone, node] of rig.bones) {
    const parentMatrix = node.parent ? toRoot.clone().multiply(node.parent.matrixWorld) : new Matrix4();
    const rest: Rest = { bone, rotation: new Quaternion(), parent: new Quaternion(), parentMatrix, position: new Vector3() };
    toRoot.clone().multiply(node.matrixWorld).decompose(rest.position, rest.rotation, new Vector3());
    parentMatrix.decompose(new Vector3(), rest.parent, new Vector3());
    found.set(node.name, rest);
    found.set(bone, rest);
  }
  return found;
}

/** The carrier's clips made `to`'s, each under its own name. */
export function retarget(clips: readonly AnimationClip[], from: Rig, to: Rig): AnimationClip[] {
  const source = rests(from);
  const target = rests(to);
  // Every rig has hips: `matchBones` refuses one without them (REQUIRED).
  const hipsFrom = source.get("hips")!.position.y;
  const hipsTo = target.get("hips")!.position.y;
  const scale = hipsFrom > 0 ? hipsTo / hipsFrom : 1;
  return clips.map((clip) => {
    const tracks: KeyframeTrack[] = [];
    for (const track of clip.tracks) {
      const dot = track.name.lastIndexOf(".");
      const [node, property] = [track.name.slice(0, dot), track.name.slice(dot + 1)];
      const rest = source.get(node);
      const bone = rest && to.bones.get(rest.bone);
      if (!rest || !bone) continue;
      // `rest` is of a bone the target has (`bone`), and its rests are taken from its bones.
      const own = target.get(rest.bone)!;
      if (property === "quaternion") tracks.push(turned(track, rest, own, bone));
      else if (property === "position" && rest.bone === "hips") tracks.push(raised(track, rest, own, bone, scale));
    }
    return new AnimationClip(clip.name, clip.duration, tracks);
  });
}

function turned(track: KeyframeTrack, from: Rest, to: Rest, bone: Object3D): KeyframeTrack {
  const values = new Float32Array(track.values.length);
  const restInverse = from.rotation.clone().invert();
  const toParentInverse = to.parent.clone().invert();
  const q = new Quaternion();
  for (let at = 0; at < values.length; at += 4) {
    q.fromArray(track.values, at);
    // The turn away from rest, then the figure's bone so turned.
    q.premultiply(from.parent).multiply(restInverse);
    q.premultiply(toParentInverse).multiply(to.rotation);
    q.toArray(values, at);
  }
  return new QuaternionKeyframeTrack(`${bone.uuid}.quaternion`, Array.from(track.times), Array.from(values));
}

function raised(track: KeyframeTrack, from: Rest, to: Rest, bone: Object3D, scale: number): KeyframeTrack {
  const values = new Float32Array(track.values.length);
  const back = to.parentMatrix.clone().invert();
  const v = new Vector3();
  for (let at = 0; at < values.length; at += 3) {
    v.fromArray(track.values, at).applyMatrix4(from.parentMatrix);
    const rise = (v.y - from.position.y) * scale;
    v.copy(to.position).setY(to.position.y + rise).applyMatrix4(back);
    v.toArray(values, at);
  }
  return new VectorKeyframeTrack(`${bone.uuid}.position`, Array.from(track.times), Array.from(values));
}
