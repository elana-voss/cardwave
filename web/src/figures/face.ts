// Cardwave's own faces (`Face`), the one layer everything that moves a figure's face speaks: each figure is matched to
// them when it loads (`facesOf`), by the names of its face shapes, whatever its file. A VRM by its expressions (VRM
// 1.0's names; three-vrm gives a VRM 0.x's "joy" and "a" the same), any other figure by its shapes (morph targets)
// on every mesh that carries one, named as VRM names its expressions, as Apple's face tracking (ARKit) names its 52,
// or as the robot names its three ("Angry", "Sad", "Surprised"), regardless of case; DAZ Studio's Genesis 9 names
// its FACS dials as ARKit's with "facs_bs_" before them and ARKit's browInnerUp in two halves (`key`). Neutral is every face at 0.
//
// Traps: a face's names come in groups (`NAMES`), and the first group the figure has any name of is all it drives,
// so a figure with both ARKit's "eyeBlinkLeft" and VRM's "blinkLeft" or "blink" does not close its eyes twice
// (ARKit's and VRM's names are never one group); within a group each name the figure has moves, so a figure with only "EyeBlinkLeft" blinks that eye alone. A VRM's own shapes are left to its
// expressions, which set them; driving them too would fight them each frame.
import type { Mesh, Object3D } from "three";
import type { VRM } from "@pixiv/three-vrm";

/** Cardwave's faces: the feelings, the eyes shut, the mouth open, and where the eyes look (the figure's own left). */
export type Face = "happy" | "angry" | "sad" | "relaxed" | "surprised" | "blink" | "open" | "lookUp" | "lookDown" | "lookLeft" | "lookRight";

const both = (name: string) => [`${name}Left`, `${name}Right`];

/** Each face's names: a VRM's expressions, and the shapes' names in groups, the first the figure has taken. */
export const NAMES: Record<Face, { vrm: string[]; shapes: string[][] }> = {
  happy: { vrm: ["happy"], shapes: [[...both("mouthSmile"), ...both("cheekSquint")], ["happy"]] },
  angry: { vrm: ["angry"], shapes: [[...both("browDown"), ...both("noseSneer")], ["angry"]] },
  sad: { vrm: ["sad"], shapes: [both("mouthFrown"), ["sad"]] },
  relaxed: { vrm: ["relaxed"], shapes: [both("eyeSquint"), ["relaxed"]] },
  surprised: { vrm: ["surprised"], shapes: [["browInnerUp", ...both("browInnerUp"), ...both("browOuterUp"), ...both("eyeWide")], ["surprised"]] },
  blink: { vrm: ["blink"], shapes: [both("eyeBlink"), both("blink"), ["blink"]] },
  open: { vrm: ["aa"], shapes: [["jawOpen"], ["aa"]] },
  // A VRM's eyes are its look-at's (three-vrm), so it has no look here.
  lookUp: { vrm: [], shapes: [both("eyeLookUp")] },
  lookDown: { vrm: [], shapes: [both("eyeLookDown")] },
  lookLeft: { vrm: [], shapes: [["eyeLookOutLeft", "eyeLookInRight"]] },
  lookRight: { vrm: [], shapes: [["eyeLookInLeft", "eyeLookOutRight"]] },
};

/** A shape's name as it is matched: in lower case, without the prefix of DAZ's FACS dials ("facs_bs_JawOpen" is "jawopen"). */
export const key = (name: string): string => name.toLowerCase().replace(/^facs_bs_/, "");

/** What of a VRM the faces need. */
export type Expressions = { expressionManager?: { getExpression(name: string): unknown; setValue(name: string, weight: number): void } } | null;

/** A figure's faces: each sets every shape or expression it was matched to. */
export class Faces {
  private readonly setters = new Map<Face, ((weight: number) => void)[]>();

  constructor(root: Object3D | null, vrm: Expressions) {
    const manager = vrm?.expressionManager;
    if (manager) {
      for (const [face, { vrm: names }] of Object.entries(NAMES) as [Face, (typeof NAMES)[Face]][]) {
        const had = names.filter((name) => manager.getExpression(name));
        if (had.length) this.setters.set(face, had.map((name) => (weight: number) => manager.setValue(name, weight)));
      }
      return;
    }
    const meshes: { mesh: Mesh; shapes: Map<string, number[]> }[] = [];
    root?.traverse((part) => {
      const dictionary = (part as Mesh).morphTargetDictionary;
      if (!dictionary) return;
      const shapes = new Map<string, number[]>();
      for (const [name, at] of Object.entries(dictionary)) shapes.set(key(name), [...(shapes.get(key(name)) ?? []), at]);
      meshes.push({ mesh: part as Mesh, shapes });
    });
    for (const [face, { shapes: groups }] of Object.entries(NAMES) as [Face, (typeof NAMES)[Face]][]) {
      for (const group of groups) {
        const setters = group.flatMap((name) =>
          meshes.flatMap(({ mesh, shapes }) => {
            const at = shapes.get(key(name)) ?? [];
            return at.map((index) => (weight: number) => void (mesh.morphTargetInfluences![index] = weight));
          }),
        );
        if (setters.length) {
          this.setters.set(face, setters);
          break;
        }
      }
    }
  }

  /** Whether the figure has `face`. */
  has(face: Face): boolean {
    return this.setters.has(face);
  }

  /** Shows `face` at `weight` (0 to 1); a face the figure lacks shows nothing. */
  set(face: Face, weight: number): void {
    for (const set of this.setters.get(face) ?? []) set(weight);
  }
}
