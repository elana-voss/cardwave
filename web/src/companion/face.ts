// The companion's face alive (`LiveFace`), spoken only in figures/face.ts's faces: each feeling's face (`FACES`), the
// resting face relaxed, lightly (`RESTING`), a blink now and then (`Blink`), the mouth open as loud as the voice is
// heard, and the eyes on the user while the figure looks at the user (figures/gaze.ts's `Gaze`). A face the figure
// lacks shows nothing; a figure with none of them keeps a still face. Names no three.js (figures/ wraps it).
import type { Feeling } from "../api/generated/Feeling";
import { type Expressions, type Face, Faces } from "../figures/face";
import { Gaze, type LookAt, type Part } from "../figures/gaze";

/** Each feeling's face, the first of `faces` the figure has, and how strong. */
export const FACES: Record<Feeling, { faces: Face[]; weight: number }> = {
  happy: { faces: ["happy"], weight: 1 },
  // The robot has no happy face; it is surprised instead, as before.
  excited: { faces: ["happy", "surprised"], weight: 1 },
  surprised: { faces: ["surprised"], weight: 1 },
  sad: { faces: ["sad"], weight: 1 },
  angry: { faces: ["angry"], weight: 1 },
  agree: { faces: ["happy"], weight: 0.5 },
  disagree: { faces: ["angry"], weight: 0.4 },
  puzzled: { faces: ["surprised"], weight: 0.4 },
  afraid: { faces: ["surprised"], weight: 1 },
  playful: { faces: ["happy"], weight: 0.7 },
  bashful: { faces: ["happy"], weight: 0.4 },
  tired: { faces: ["sad"], weight: 0.4 },
};

/** How relaxed the face is with no feeling. */
export const RESTING = 0.3;
const FEELINGS: Face[] = ["happy", "angry", "sad", "relaxed", "surprised"];

/** The time between blinks, at least and at most (s), and how long the lids take to shut, stay and open. */
export const BLINK = { least: 2, most: 6, shut: 0.06, stay: 0.03, open: 0.1 };

/** When the eyes blink: now and then, at a time drawn from `random` between `BLINK.least` and `BLINK.most`. */
export class Blink {
  private wait: number;
  private time = 0;

  constructor(private readonly random: () => number = Math.random) {
    this.wait = this.next();
  }

  private next(): number {
    return BLINK.least + (BLINK.most - BLINK.least) * this.random();
  }

  /** How shut the eyes are after `dt` seconds more (0 open to 1 shut). */
  step(dt: number): number {
    this.time += dt;
    const into = this.time - this.wait;
    if (into < 0) return 0;
    const { shut, stay, open } = BLINK;
    if (into < shut) return into / shut;
    if (into < shut + stay) return 1;
    if (into < shut + stay + open) return 1 - (into - shut - stay) / open;
    this.time = 0;
    this.wait = this.next();
    return 0;
  }
}

/** A figure's face alive. */
export class LiveFace {
  readonly faces: Faces;
  private readonly blink: Blink;
  private readonly gaze: Gaze;

  /** The face of `root`, placed facing the user, and of its VRM where it is one, its head `head`. */
  constructor(root: Part, vrm: (Expressions & LookAt) | null, head: Part | null, random: () => number = Math.random) {
    this.faces = new Faces(root, vrm);
    this.blink = new Blink(random);
    this.gaze = new Gaze(root, vrm, head, this.faces);
  }

  /** Shows `feeling` (none: resting), the mouth `open` (0 to 1), a blink when one is due after `dt` seconds, and
   * the eyes on the user while the figure looks at the user (`atUser`); after the clips moved the figure, before a
   * VRM's update. */
  show(dt: number, feeling: Feeling | null, open: number, atUser: boolean): void {
    const look = feeling ? FACES[feeling] : null;
    const shown = look?.faces.find((face) => this.faces.has(face));
    for (const face of FEELINGS) this.faces.set(face, face === shown ? look!.weight : !look && face === "relaxed" ? RESTING : 0);
    this.faces.set("blink", this.blink.step(dt));
    this.faces.set("open", open);
    this.gaze.look(atUser);
  }
}
