// The companion's figure drawn in 3D (three.js) on a canvas of its own, which main.ts places where the body's feet
// are: the 3D figure of its card and mode, else the base figure picked (`baseSource`: the woman or man of
// web/src/figures/, tools/companion_assets.py), each given the carrier's clips (`CARRIED`), else, and where that
// does not load, the robot robot.glb ("RobotExpressive" by Tomás Laulhé, modified by Don McCurdy, CC0 1.0, from
// three.js's examples) with its own clips (`ROBOT`). What plays is clips.ts's `Clips`; the figure turns over a
// moment to where it goes or looks (`turned`), shows a feeling on its face and opens a VRM's mouth as loud as the
// voice is heard (`showFace`, `mouthOf`): a figure without mouth shapes moves no lips.
//
// Traps: the canvas keeps what it drew (`preserveDrawingBuffer`), as `opaqueAt` reads a pixel of it to say whether
// the cursor is on the figure, which is what lets a click through everywhere else (the desktop's cursor poll).
// Until the model has come, nothing is drawn and no pixel is the figure's. A figure replaced is let go of
// (`letGo`), and one whose load a later change overtook is never shown (`newest`).
import { AnimationMixer, Box3, type AnimationClip, type Bone, DirectionalLight, HemisphereLight, PerspectiveCamera, Scene, Vector3, WebGLRenderer, type Mesh, type Object3D } from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { type VRM, VRMUtils } from "@pixiv/three-vrm";
import type { Clip } from "../api/generated/Clip";
import type { Feeling } from "../api/generated/Feeling";
import { clipsFor, type FigureKind, loadFigure } from "../figures/load";
import { FILL, SIZE, type State } from "./body";
import { CARRIED, type ClipTable, Clips, ROBOT } from "./clips";
import robot from "./robot.glb";
import woman from "../figures/woman.glb";
import man from "../figures/man.glb";
import type { BaseFigure } from "../api/generated/BaseFigure";


/** Each feeling on the face: a VRM's expression and the robot's shape key, and how strong. */
const FACES: Record<Feeling, { vrm: string; robot: string | null; weight: number }> = {
  happy: { vrm: "happy", robot: null, weight: 1 },
  excited: { vrm: "happy", robot: "Surprised", weight: 1 },
  surprised: { vrm: "surprised", robot: "Surprised", weight: 1 },
  sad: { vrm: "sad", robot: "Sad", weight: 1 },
  angry: { vrm: "angry", robot: "Angry", weight: 1 },
  agree: { vrm: "happy", robot: null, weight: 0.5 },
  disagree: { vrm: "angry", robot: "Angry", weight: 0.4 },
  puzzled: { vrm: "surprised", robot: "Surprised", weight: 0.4 },
};

/** How far the head turns up or down to where it looks, at most (radians). */
const PITCH = 0.45;
/** How fast the figure and its head turn to where they are to face: the share of the way left gone in a second
 * is 1 - e^-TURN. */
const TURN = 8;
/** How fast the mouth follows the voice, likewise, and how far a loudness (its root mean square) opens it. */
const LIPS = 30;
const OPENS = 6;

/** The angle `now` turned toward `want` (radians) by `dt` seconds, the short way round. */
export function turned(now: number, want: number, dt: number): number {
  const way = Math.atan2(Math.sin(want - now), Math.cos(want - now));
  return now + way * (1 - Math.exp(-TURN * dt));
}

/** How open the mouth is after `dt` seconds of a voice heard as loud as `loudness`, from `now` (0 shut to 1). */
export const mouthOf = (now: number, loudness: number, dt: number): number =>
  now + (Math.min(1, loudness * OPENS) - now) * (1 - Math.exp(-LIPS * dt));

/** What of a VRM the face needs. */
type Expressions = { expressionManager?: { setValue(name: string, weight: number): void } } | null;

/** Shows `feeling` on the face, the robot's shape keys or a VRM's expressions, and opens a VRM's mouth by `open`
 * (its "aa"): a figure without mouth shapes moves no lips. */
export function showFace(face: Mesh | null, vrm: Expressions, feeling: Feeling | null, open: number): void {
  const look = feeling ? FACES[feeling] : null;
  const shapes = face?.morphTargetDictionary;
  const weights = face?.morphTargetInfluences;
  if (shapes && weights) {
    for (const name of ["Angry", "Sad", "Surprised"]) {
      const at = shapes[name];
      if (at !== undefined) weights[at] = look?.robot === name ? look.weight : 0;
    }
  }
  for (const name of ["happy", "angry", "sad", "surprised"]) vrm?.expressionManager?.setValue(name, look?.vrm === name ? look.weight : 0);
  vrm?.expressionManager?.setValue("aa", open);
}

/** The base figure's file, or none for the robot. */
export function baseSource(base: BaseFigure): FigureSource | null {
  if (base === "robot") return null;
  return { url: base === "woman" ? woman : man, kind: "glb" };
}

/** A card's figure: its file and kind. */
export interface FigureSource {
  url: string;
  kind: FigureKind;
}

/** A model to place: what it draws, its clips and which of them is which. */
interface Placed {
  model: Object3D;
  clips: AnimationClip[];
  table: ClipTable;
  vrm: VRM | null;
}

/** `load` whose answer is used only for the newest call: an earlier call answers undefined once a later began. */
export function newest<A, T>(load: (arg: A) => Promise<T>): (arg: A) => Promise<T | undefined> {
  let turn = 0;
  return async (arg) => {
    const mine = ++turn;
    const answer = await load(arg);
    return mine === turn ? answer : undefined;
  };
}

/** Lets go of a model no longer shown: its clips, and its shapes, looks and pictures on the graphics card. */
export function letGo(model: Object3D, mixer: AnimationMixer): void {
  mixer.stopAllAction();
  mixer.uncacheRoot(model);
  VRMUtils.deepDispose(model);
}


export class Figure {
  readonly canvas: HTMLCanvasElement;
  private readonly renderer: WebGLRenderer;
  private readonly scene = new Scene();
  private readonly camera = new PerspectiveCamera(30, SIZE.width / SIZE.height, 0.1, 100);
  private model: Object3D | null = null;
  private mixer: AnimationMixer | null = null;
  private clips: Clips | null = null;
  private face: Mesh | null = null;
  private vrm: VRM | null = null;
  /** The head, which turns up or down to where the figure looks, and how far it is turned now. */
  private head: Object3D | null = null;
  private turned = 0;
  private yaw = 0;
  private pitch = 0;
  private feeling: Feeling | null = null;
  /** Where the figure is to face (radians about its height), how far it leans, and how open its mouth is. */
  private facing = 0;
  private lean = 0;
  private mouth = 0;
  readonly ready: Promise<void>;

  /** The figure of `source`, else the robot. */
  constructor(source: FigureSource | null) {
    this.canvas = document.createElement("canvas");
    this.canvas.className = "companion-figure";
    this.renderer = new WebGLRenderer({ canvas: this.canvas, antialias: true, alpha: true, premultipliedAlpha: true, preserveDrawingBuffer: true });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.renderer.setSize(SIZE.width, SIZE.height);
    this.scene.add(new HemisphereLight(0xffffff, 0x444444, 2.5));
    const sun = new DirectionalLight(0xffffff, 2);
    sun.position.set(3, 10, 5);
    this.scene.add(sun);
    this.ready = this.change(source);
  }

  /** Draws on a canvas of `SIZE` as it is now, the figure framed as before, so it grows or shrinks with it. */
  resize(): void {
    this.renderer.setSize(SIZE.width, SIZE.height);
  }

  /** Shows the figure of `source` in place of the one shown, else the robot. */
  async change(source: FigureSource | null): Promise<void> {
    const placed = await this.load(source);
    if (placed) this.place(placed);
  }

  /** The figure of `source`, else the robot; a slow load overtaken by a later change is not shown. */
  private readonly load = newest(async (source: FigureSource | null): Promise<Placed> => {
    if (source) {
      try {
        const model = await loadFigure(source.url, source.kind);
        return { model: model.root, clips: await clipsFor(model), table: CARRIED, vrm: model.vrm };
      } catch (error) {
        console.warn("The companion's figure did not load; the robot stands in.", error);
      }
    }
    const gltf = await new GLTFLoader().loadAsync(robot);
    return { model: gltf.scene, clips: gltf.animations, table: ROBOT, vrm: null };
  });

  private place({ model, clips, table, vrm }: Placed): void {
    if (this.model && this.mixer) {
      this.scene.remove(this.model);
      letGo(this.model, this.mixer);
    }
    this.model = model;
    this.vrm = vrm;
    this.face = null;
    this.head = vrm?.humanoid?.getNormalizedBoneNode("head") ?? null;
    this.turned = 0;
    model.traverse((part) => {
      if ((part as Mesh).morphTargetDictionary?.Surprised !== undefined) this.face = part as Mesh;
      if (!this.head && (part as Bone).isBone && /head/i.test(part.name)) this.head = part;
    });
    this.scene.add(model);
    this.mixer = new AnimationMixer(model);
    this.clips = new Clips(this.mixer, clips, table);
    // The figure standing takes the lower part of the canvas, its feet near the foot, with room above and at the
    // sides for a jump and for raised arms.
    const box = new Box3().setFromObject(model);
    const view = (box.max.y - box.min.y) / FILL;
    const middle = box.min.y - view * 0.04 + view / 2;
    const distance = view / 2 / Math.tan((this.camera.fov * Math.PI) / 360);
    this.camera.position.set(0, middle, distance);
    this.camera.lookAt(new Vector3(0, middle, 0));
    // A figure in centimetres (an FBX of Mixamo's) is as far away as one in metres is near.
    this.camera.near = distance / 100;
    this.camera.far = distance * 10;
    this.camera.updateProjectionMatrix();
  }

  /** Plays the clip of `state`, turned to `heading` (-1 left, 1 right, 0 the user), or to the edge it climbs. */
  show(state: State, heading: number, toward = 0): void {
    if (!this.model) return;
    this.facing = state === "climbing" ? Math.PI : state === "walking" ? (heading * Math.PI) / 2 : (state === "listening" ? toward * 0.5 : 0) + this.yaw;
    this.lean = state === "thinking" ? 0.12 : 0;
    this.clips?.show(state);
  }

  /** Plays `clip` over what plays, once or for `ms`; answers how long, in ms. */
  play(clip: Clip, ms?: number): number {
    return this.clips?.play(clip, ms) ?? 0;
  }

  /** Whether it plays a clip between two poses, standing up or getting up, before it can go anywhere. */
  get rising(): boolean {
    return this.clips?.between ?? false;
  }

  /** The model's clip that plays now, by its name in the model. */
  get clip(): string | null {
    return this.clips?.current ?? null;
  }

  /** Turns the figure by `yaw` and its head by `pitch` (radians; 0, 0: at the user), but while it walks or climbs. */
  look(yaw: number, pitch: number): void {
    this.yaw = yaw;
    this.pitch = Math.max(-PITCH, Math.min(PITCH, pitch));
  }

  /** Shows `feeling` on the face, or none. */
  feel(feeling: Feeling | null): void {
    this.feeling = feeling;
  }

  /** Moves the clips on by `dt` seconds, turns the figure to where it is to face, opens its mouth as loud as the
   * voice is heard (`loudness`, 0 to 1), and draws. */
  draw(dt: number, loudness: number): void {
    if (!this.clips || !this.model) return;
    this.model.rotation.y = turned(this.model.rotation.y, this.facing, dt);
    this.model.rotation.z = turned(this.model.rotation.z, this.lean, dt);
    // The head's turn is taken off before the clips move it and put on after, as a clip that does not move the
    // head would leave it turning further each frame.
    this.head?.rotateX(-this.turned);
    this.clips.update(dt);
    this.turned = turned(this.turned, this.pitch, dt);
    this.head?.rotateX(this.turned);
    this.mouth = mouthOf(this.mouth, loudness, dt);
    showFace(this.face, this.vrm, this.feeling, this.mouth);
    // A VRM's normalized bones, which the clips move, to the bones it draws.
    this.vrm?.update(dt);
    this.renderer.render(this.scene, this.camera);
  }

  /** Whether the pixel at `x`, `y` of the canvas (CSS pixels) is the figure's and not see-through. */
  opaqueAt(x: number, y: number): boolean {
    if (!this.model || x < 0 || y < 0 || x >= SIZE.width || y >= SIZE.height) return false;
    const gl = this.renderer.getContext();
    const ratio = this.renderer.getPixelRatio();
    const pixel = new Uint8Array(4);
    gl.readPixels(Math.floor(x * ratio), Math.floor((SIZE.height - y) * ratio) - 1, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
    return pixel[3]! > 16;
  }
}
