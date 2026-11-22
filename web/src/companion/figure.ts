// The companion's figure drawn in 3D (three.js) on a canvas of its own, which main.ts places where the body's feet
// are: the 3D figure of its card and mode, else the base figure picked (`baseSource`: the woman or man of
// web/src/figures/, tools/companion_assets.py), each given the carrier's clips (`CARRIED`), else, and where that
// does not load, the robot robot.glb ("RobotExpressive" by Tomás Laulhé, modified by Don McCurdy, CC0 1.0, from
// three.js's examples) with its own clips (`ROBOT`). What plays is clips.ts's `Clips`; the figure turns over a
// moment to where it goes or looks (`turned`), and its face lives by face.ts's `LiveFace`: feelings, blinks, the
// eyes on the user and the mouth as loud as the voice is heard, else as lips.ts's letters have it (`mouthOf`). It is seen straight on, its
// lowest point as its idle clip stands it on the canvas's foot (`framing`, `standing`), at every size; in every
// other clip ground.ts's `Ground` rests it there, and its walk's `pace` is how fast main.ts has the body walk.
// Where a click lands on its body is figures/touch.ts's (`bodyPartAt`; figures/ray.ts `prepare`s the figure for it
// when placed), by its human bones (the robot's by `ROBOT_BONES`).
//
// Traps: drawn by figures/drawer.ts's renderer, WebGPU or WebGL 2, which keeps no frame after the task that drew it:
// each frame is copied to a 2D canvas (`kept`), whose pixel `opaqueAt` reads to say whether the cursor is on the
// figure, which is what lets a click through everywhere else (the desktop's cursor poll). Until the renderer has
// started and the model has come, nothing is drawn and no pixel is the figure's. A figure replaced is let go of
// (`letGo`), and one whose load a later change overtook is never shown (`newest`).
import { AnimationMixer, Box3, type AnimationClip, type Bone, type Camera, type Object3D, OrthographicCamera, Scene } from "three";
import type { WebGPURenderer } from "three/webgpu";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { type VRM, VRMUtils } from "@pixiv/three-vrm";
import type { BodyPart } from "../api/generated/BodyPart";
import type { Clip } from "../api/generated/Clip";
import type { Feeling } from "../api/generated/Feeling";
import { drawer, lit } from "../figures/drawer";
import { clipsFor, type FigureKind, loadFigure } from "../figures/load";
import { type HumanBone, humanBoneOf } from "../figures/skeleton";
import { FILL, SIZE, type State } from "./body";
import { CARRIED, type ClipTable, Clips, ROBOT } from "./clips";
import { Ground } from "./ground";
import { LiveFace } from "./face";
import { prepare } from "../figures/ray";
import { bodyPartAt } from "../figures/touch";
import robot from "./robot.glb";
import woman from "../figures/woman.glb";
import man from "../figures/man.glb";
import type { BaseFigure } from "../api/generated/BaseFigure";


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

/** Whether a figure turned by `y` (radians, wound past a turn or not) faces the user. */
export const facing = (y: number): boolean => Math.abs(Math.atan2(Math.sin(y), Math.cos(y))) < 0.35;

/** How open the mouth is after `dt` seconds of a voice heard as loud as `loudness`, from `now` (0 shut to 1), or
 * as open as the letters spoken without a voice have it (`letters`, lips.ts's), whichever is wider. */
export const mouthOf = (now: number, loudness: number, dt: number, letters = 0): number =>
  now + (Math.max(Math.min(1, loudness * OPENS), letters) - now) * (1 - Math.exp(-LIPS * dt));

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
  /** Its human bones, by which a click finds the part of the body (touch.ts). */
  bones: ReadonlyMap<HumanBone, Object3D>;
}

/** The robot's bones that its names do not tell. */
const ROBOT_BONES: Record<string, HumanBone> = { Abdomen: "spine", Torso: "chest", Palm2L: "leftHand", Palm2R: "rightHand" };

/** The human bones of the robot, by their names. */
function robotBones(model: Object3D): Map<HumanBone, Object3D> {
  const bones = new Map<HumanBone, Object3D>();
  model.traverse((node) => {
    const bone = (node as Bone).isBone ? (ROBOT_BONES[node.name] ?? humanBoneOf(node.name)) : null;
    if (bone && !bones.has(bone)) bones.set(bone, node);
  });
  return bones;
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

/** The camera that frames a figure whose box standing is `stood`, on a canvas `aspect` wide to its height: the figure
 * standing takes `FILL` of the canvas's height, its lowest point on the canvas's foot, which main.ts stands on the
 * body's feet, with room above and at the sides for a jump and for raised arms. Seen straight on, without
 * perspective, as a perspective would draw a foot nearer the camera lower than one further off, by a share of the
 * canvas, so more pixels the larger the figure (milestone 160). */
export function framing(stood: Box3, aspect: number): Camera {
  const view = (stood.max.y - stood.min.y) / FILL;
  const half = (view * aspect) / 2;
  // Far enough off that a figure lying or reaching out stays between the near and far planes; a figure in
  // centimetres (an FBX of Mixamo's) is as far off as one in metres is near.
  const reach = view * 2;
  const camera = new OrthographicCamera(-half, half, stood.min.y + view, stood.min.y, reach / 100, reach * 2);
  camera.position.set(0, 0, reach);
  camera.updateProjectionMatrix();
  return camera;
}

/** The box of `model` standing: its skin as the first frame of its idle clip (of `clips`, by `table`) poses it, not
 * as the file left it (arms out, or feet lower or higher than the clips stand them). */
export function standing(model: Object3D, mixer: AnimationMixer, clips: AnimationClip[], table: ClipTable, vrm: VRM | null): Box3 {
  const idle = clips.find((clip) => table.states.idle.clips.includes(clip.name));
  const action = idle ? mixer.clipAction(idle).play() : null;
  mixer.update(0);
  vrm?.update(0);
  model.updateMatrixWorld(true);
  const box = new Box3().setFromObject(model, true);
  action?.stop();
  return box;
}

/** Lets go of a model no longer shown: its clips, and its shapes, looks and pictures on the graphics card. */
export function letGo(model: Object3D, mixer: AnimationMixer): void {
  mixer.stopAllAction();
  mixer.uncacheRoot(model);
  VRMUtils.deepDispose(model);
}


export class Figure {
  readonly canvas: HTMLCanvasElement;
  private readonly renderer: WebGPURenderer;
  /** The renderer started, before which nothing is drawn. */
  private readonly started: Promise<void>;
  /** The last frame drawn, which `opaqueAt` reads. */
  private readonly kept: CanvasRenderingContext2D;
  private readonly scene = new Scene();
  private camera: Camera = new OrthographicCamera();
  private model: Object3D | null = null;
  private mixer: AnimationMixer | null = null;
  private clips: Clips | null = null;
  private ground: Ground | null = null;
  /** The names of its walking and climbing clips, by its table (`place`). */
  private steps: ReadonlySet<string> = new Set();
  /** Its face alive, face.ts's. */
  private live: LiveFace | null = null;
  private vrm: VRM | null = null;
  private bones: ReadonlyMap<HumanBone, Object3D> = new Map();
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
    ({ renderer: this.renderer, ready: this.started } = drawer(this.canvas));
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.renderer.setSize(SIZE.width, SIZE.height);
    // A canvas of its own has no other kind of drawing yet, so it gives a 2D one.
    this.kept = document.createElement("canvas").getContext("2d")!;
    lit(this.scene);
    this.ready = this.change(source);
  }

  /** Draws on a canvas of `SIZE` as it is now, the figure framed as before, so it grows or shrinks with it. */
  resize(): void {
    this.renderer.setSize(SIZE.width, SIZE.height);
  }

  /** Shows the figure of `source` in place of the one shown, else the robot. */
  async change(source: FigureSource | null): Promise<void> {
    const [placed] = await Promise.all([this.load(source), this.started]);
    if (placed) this.place(placed);
  }

  /** The figure of `source`, else the robot; a slow load overtaken by a later change is not shown. */
  private readonly load = newest(async (source: FigureSource | null): Promise<Placed> => {
    if (source) {
      try {
        // A KTX2 texture needs the renderer started (figures/decoders.ts).
        await this.started;
        const model = await loadFigure(source.url, source.kind, this.renderer);
        return { model: model.root, clips: await clipsFor(model), table: CARRIED, vrm: model.vrm, bones: model.bones };
      } catch (error) {
        console.warn("The companion's figure did not load; the robot stands in.", error);
      }
    }
    const gltf = await new GLTFLoader().loadAsync(robot);
    return { model: gltf.scene, clips: gltf.animations, table: ROBOT, vrm: null, bones: robotBones(gltf.scene) };
  });

  private place({ model, clips, table, vrm, bones }: Placed): void {
    if (this.model && this.mixer) {
      this.scene.remove(this.model);
      letGo(this.model, this.mixer);
    }
    this.model = model;
    this.bones = bones;
    this.vrm = vrm;
    this.head = vrm?.humanoid?.getNormalizedBoneNode("head") ?? null;
    this.turned = 0;
    model.traverse((part) => {
      if (!this.head && (part as Bone).isBone && /head/i.test(part.name)) this.head = part;
    });
    this.scene.add(model);
    this.mixer = new AnimationMixer(model);
    this.clips = new Clips(this.mixer, clips, table);
    this.steps = new Set([...table.states.walking.clips, ...table.states.climbing.clips]);
    const stood = standing(model, this.mixer, clips, table, vrm);
    this.ground = new Ground(model, stood, vrm?.humanoid ?? null);
    this.camera = framing(stood, SIZE.width / SIZE.height);
    // Placed facing the user, as the face takes where its eyes look.
    model.updateMatrixWorld(true);
    this.live = new LiveFace(model, vrm, this.head);
    prepare(model);
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

  /** Whether it plays a clip between two poses, standing up or getting up, or its landing, before it can go
   * anywhere. */
  get rising(): boolean {
    return this.clips?.between ?? false;
  }

  /** The model's clip that plays now, by its name in the model, without the version (`dancing_2` is `dancing`):
   * the name the AI plays it by. */
  get clip(): string | null {
    return this.clips?.current?.replace(/_\d+$/, "") ?? null;
  }

  /** How fast the feet of its walking or climbing clips go as they play now, at their weights and speeds, in heights
   * standing a second: how fast the figure is to go along the floor or up an edge so that its feet do not slide. 0
   * while no such clip plays; null before the model has come. */
  get pace(): number | null {
    if (!this.clips || !this.ground) return null;
    let pace = 0;
    for (const [action, weight] of this.clips.weighed) {
      if (this.steps.has(action.getClip().name)) pace += weight * Math.abs(action.timeScale) * this.ground.paceOf(action.getClip());
    }
    return pace;
  }

  /** Turns the figure by `yaw` and its head by `pitch` (radians; 0, 0: at the user), but while it walks or climbs. */
  look(yaw: number, pitch: number): void {
    this.yaw = yaw;
    this.pitch = Math.max(-PITCH, Math.min(PITCH, pitch));
  }

  /** Shows `feeling` on the face, or none. */
  feel(feeling: Feeling | null): void {
    this.feeling = feeling;
    if (feeling) this.clips?.feel(feeling);
  }

  /** Moves the clips on by `dt` seconds, turns the figure to where it is to face, opens its mouth as loud as the
   * voice is heard (`loudness`, 0 to 1) or as the letters spoken without one have it (`letters`), and draws. */
  draw(dt: number, loudness: number, letters = 0): void {
    if (!this.clips || !this.model) return;
    this.model.rotation.y = turned(this.model.rotation.y, this.facing, dt);
    this.model.rotation.z = turned(this.model.rotation.z, this.lean, dt);
    // The head's turn is taken off before the clips move it and put on after, as a clip that does not move the
    // head would leave it turning further each frame.
    this.head?.rotateX(-this.turned);
    this.clips.update(dt);
    this.turned = turned(this.turned, this.pitch, dt);
    this.head?.rotateX(this.turned);
    this.mouth = mouthOf(this.mouth, loudness, dt, letters);
    // It looks at the user while it faces the user and its head is not turned up or down.
    const atUser = facing(this.model.rotation.y) && Math.abs(this.turned) < 0.1;
    this.live?.show(dt, this.feeling, this.mouth, atUser);
    // A VRM's normalized bones, which the clips move, to the bones it draws.
    this.vrm?.update(dt);
    this.ground?.settle(this.clips.weighed);
    this.renderer.render(this.scene, this.camera);
    this.keep();
  }

  /** Copies the frame just drawn to `kept`, which keeps it until the next. */
  private keep(): void {
    const { width, height } = this.canvas;
    const copy = this.kept.canvas;
    if (copy.width !== width || copy.height !== height) Object.assign(copy, { width, height });
    else this.kept.clearRect(0, 0, width, height);
    this.kept.drawImage(this.canvas, 0, 0);
  }

  /** The part of the body at `x`, `y` of the canvas (CSS pixels), as drawn now; null beside it (touch.ts). */
  partAt(x: number, y: number): BodyPart | null {
    if (!this.model) return null;
    return bodyPartAt(this.model, this.bones, this.camera, (x / SIZE.width) * 2 - 1, 1 - (y / SIZE.height) * 2);
  }

  /** Whether the pixel at `x`, `y` of the canvas (CSS pixels) is the figure's and not see-through. */
  opaqueAt(x: number, y: number): boolean {
    if (!this.model || x < 0 || y < 0 || x >= SIZE.width || y >= SIZE.height) return false;
    const ratio = this.renderer.getPixelRatio();
    return this.kept.getImageData(Math.floor(x * ratio), Math.floor(y * ratio), 1, 1).data[3]! > 16;
  }
}
