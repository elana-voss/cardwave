// A figure's eyes on the user (`Gaze`), spoken by companion/face.ts's `LiveFace`: a VRM's by its look-at
// (three-vrm), else its eye bones turned (`Eyes`), else its eye shapes (face.ts's look faces), each as far as an eye
// reaches (`REACH`). A figure with none of them keeps its eyes still. `Part` and `LookAt` name three.js's and
// three-vrm's types for areas outside figures/, which name neither library.
//
// Traps: the user is straight in front of the figure (the camera is orthographic, along -z), so the eyes look along
// +z, not at the camera's point, which stands at the floor's height. An eye bone's forward is taken when the figure
// is placed, facing the user, and no clip moves an eye, so its rest is put back each frame before it is turned.
import { Object3D, Quaternion, Vector3 } from "three";
import type { VRM } from "@pixiv/three-vrm";
import type { Faces } from "./face";

/** A part of a figure, its root or a bone. */
export type Part = Object3D;
/** What a VRM's eyes look by. */
export type LookAt = Pick<VRM, "lookAt">;

/** How far an eye turns from where the head looks, at most (radians). */
const REACH = 0.35;
/** Where the user is, from the figure: straight ahead. */
const AHEAD = new Vector3(0, 0, 1);

/** The eye bones of a figure that is no VRM, turned to look at the user. */
class Eyes {
  private readonly eyes: { bone: Object3D; rest: Quaternion; forward: Vector3 }[] = [];

  /** The eye bones under `root`, which is placed facing the user. */
  constructor(root: Object3D) {
    const found = new Map<string, Object3D>();
    root.traverse((part) => {
      const name = part.name.toLowerCase().replace(/[^a-z]/g, "");
      const side = /(left|^l)eye$/.test(name) ? "left" : /(right|^r)eye$/.test(name) ? "right" : null;
      if (side && (part as Object3D & { isBone?: boolean }).isBone && !found.has(side)) found.set(side, part);
    });
    root.updateMatrixWorld(true);
    for (const bone of found.values()) {
      const world = bone.getWorldQuaternion(new Quaternion());
      this.eyes.push({ bone, rest: bone.quaternion.clone(), forward: AHEAD.clone().applyQuaternion(world.invert()) });
    }
  }

  get any(): boolean {
    return this.eyes.length > 0;
  }

  /** Turns each eye to the user, as far as it reaches, or back to its rest. */
  look(atUser: boolean): void {
    for (const { bone, rest, forward } of this.eyes) {
      bone.quaternion.copy(rest);
      if (!atUser) continue;
      bone.updateWorldMatrix(true, false);
      const world = bone.getWorldQuaternion(new Quaternion());
      const turn = new Quaternion().setFromUnitVectors(forward.clone().applyQuaternion(world), AHEAD);
      const angle = 2 * Math.acos(Math.min(1, Math.abs(turn.w)));
      if (angle > REACH) turn.slerp(new Quaternion(), 1 - REACH / angle);
      // The turn, made in the world, made the bone's own: rest · world⁻¹ · turn · world.
      bone.quaternion.multiply(world.clone().invert().multiply(turn).multiply(world));
    }
  }
}

/** A figure's eyes, on the user or not. */
export class Gaze {
  private readonly eyes: Eyes | null;
  /** Where the head looks at the user, in the head's own frame, taken as the figure is placed. */
  private readonly forward: Vector3 | null;
  /** What a VRM's look-at looks at: a point straight ahead of its head. */
  private readonly user = new Object3D();

  /** The eyes of `root`, placed facing the user, and of its VRM where it is one, its head `head`; the eye shapes
   * are set on `faces`. */
  constructor(
    root: Object3D,
    private readonly vrm: LookAt | null,
    private readonly head: Object3D | null,
    private readonly faces: Faces,
  ) {
    this.eyes = vrm ? null : new Eyes(root);
    this.forward = head && !vrm ? AHEAD.clone().applyQuaternion(head.getWorldQuaternion(new Quaternion()).invert()) : null;
  }

  /** Turns the eyes to the user (`atUser`) or back; after the clips moved the figure, before a VRM's update. */
  look(atUser: boolean): void {
    const lookAt = this.vrm?.lookAt;
    if (lookAt) {
      if (atUser && this.head) {
        this.head.getWorldPosition(this.user.position).add(AHEAD.clone().multiplyScalar(10));
        this.user.updateMatrixWorld();
        lookAt.target = this.user;
      } else if (lookAt.target) {
        lookAt.target = null;
        lookAt.reset();
      }
      return;
    }
    if (this.eyes?.any) return this.eyes.look(atUser);
    // Eye shapes: the head's turn from the user, undone by the eyes as far as they reach.
    let yaw = 0;
    let pitch = 0;
    if (atUser && this.head && this.forward) {
      const ahead = this.forward.clone().applyQuaternion(this.head.getWorldQuaternion(new Quaternion()));
      yaw = -Math.atan2(ahead.x, ahead.z);
      pitch = Math.asin(Math.max(-1, Math.min(1, ahead.y)));
    }
    const share = (angle: number) => Math.min(1, Math.max(0, angle / REACH));
    this.faces.set("lookLeft", share(yaw));
    this.faces.set("lookRight", share(-yaw));
    this.faces.set("lookDown", share(pitch));
    this.faces.set("lookUp", share(-pitch));
  }
}
