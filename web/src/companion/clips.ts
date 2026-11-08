// The companion's clips, apart from the drawing (figure.ts), so that a test runs them without WebGL: each model's
// table (`ClipTable`: the robot's own, `ROBOT`, and the carrier's, `CARRIED`, which every other figure is given) and
// `Clips`, which plays a state's clip, and a clip the companion is told to play over it, once or for a time.
//
// One clip goes into the next by a blend from the pose the figure has (the weights of all that still plays, scaled
// to make room for the new one, so they always add up to one, however often it changes mid-blend), and where the
// two clips' poses differ (standing, sitting, lying, hanging, landing) through the clips between them (`bridges`:
// it sits down before sitting, gets up before standing), else by a longer blend. The carrier's clips were measured
// for this (the plan's 95e: where it still breaks).
//
// Traps: three.js's own cross-fade starts the clip faded out at full weight, so a change mid-blend jumped: the
// weights are set here instead. A clip played once is held at its end (`clampWhenFinished`), as one switched off
// lets the figure's rest pose show through.
import { type AnimationAction, type AnimationClip, type AnimationMixer, LoopOnce, LoopRepeat } from "three";
import type { Clip } from "../api/generated/Clip";
import type { State } from "./body";

/** Where a clip leaves the body. */
export type Pose = "stand" | "sit" | "lie" | "hang" | "land";

/** Each state's clip of a model, and how fast it plays (a speed of 0 holds the clip at `at` of its length; `direct`:
 * reached by a blend alone, no clip between); and the model's clip of each clip the companion is told to play, where
 * it has one. */
export interface ClipTable {
  states: Record<State, { clip: string; speed: number; at?: number; once?: boolean; direct?: boolean }>;
  clips: Partial<Record<Clip, string>>;
  /** The pose each of the model's clips starts and ends in; one not named stands throughout. */
  poses?: Record<string, readonly [Pose, Pose]>;
  /** The clips played once on the way from one pose to another, by `from>to`. */
  bridges?: Partial<Record<`${Pose}>${Pose}`, string[]>>;
}

/** The robot's own clips. */
export const ROBOT: ClipTable = {
  states: {
    idle: { clip: "Idle", speed: 1 },
    listening: { clip: "Idle", speed: 1 },
    thinking: { clip: "Idle", speed: 0.5 },
    talking: { clip: "Idle", speed: 1 },
    sleeping: { clip: "Sitting", speed: 1, once: true },
    sitting: { clip: "Sitting", speed: 1, once: true },
    startled: { clip: "Jump", speed: 1.5, once: true },
    dragged: { clip: "Jump", speed: 0, at: 0.4 },
    shaken: { clip: "No", speed: 2.5 },
    thrown: { clip: "Jump", speed: 0, at: 0.5 },
    falling: { clip: "Jump", speed: 0, at: 0.3 },
    bumped: { clip: "Death", speed: 0, at: 0.25 },
    bouncing: { clip: "Death", speed: 0, at: 0.8 },
    landing: { clip: "Standing", speed: 1, once: true },
    walking: { clip: "Walking", speed: 1 },
    climbing: { clip: "Walking", speed: 0.8 },
  },
  clips: {
    idle: "Idle", idle_shift: "Idle", thinking: "Idle", listening: "Idle", talking: "Idle", walk: "Walking",
    sit_down: "Sitting", sitting: "Sitting", stand_up: "Standing", lying: "Death", get_up: "Standing", wave: "Wave",
    nod: "Yes", no: "No", jump: "Jump", dance: "Dance", hanging: "Jump", climbing: "Walking", startled: "Jump",
    falling: "Jump", shaken: "No", landing: "Standing",
  },
};

/** Every clip the companion is told to play, by its name, which is that of the carrier's clip. */
const CLIPS: Clip[] = [
  "idle", "idle_shift", "stretch", "thinking", "listening", "talking", "walk", "sit_down", "sitting", "stand_up",
  "lying", "get_up", "wave", "nod", "no", "jump", "dance", "hanging", "climbing", "startled", "falling", "shaken",
  "landing",
];

/** The carrier's clips (tools/companion_assets.py), which every figure but the robot is given, each played by its
 * own name. The carrier's idle_shift, stretch, sit_down, stand_up and get_up are for idling and going from one state
 * to the next (the plan's 95: which chains into which). */
export const CARRIED: ClipTable = {
  states: {
    idle: { clip: "idle", speed: 1 },
    listening: { clip: "listening", speed: 1 },
    thinking: { clip: "thinking", speed: 1 },
    talking: { clip: "talking", speed: 1 },
    sleeping: { clip: "lying", speed: 1 },
    sitting: { clip: "sitting", speed: 1 },
    startled: { clip: "startled", speed: 1, once: true },
    dragged: { clip: "hanging", speed: 1 },
    shaken: { clip: "shaken", speed: 1 },
    thrown: { clip: "falling", speed: 1 },
    falling: { clip: "falling", speed: 1 },
    bumped: { clip: "startled", speed: 0, at: 0.3 },
    // Thrown, it lies at once while it bounces, not by sitting down first.
    bouncing: { clip: "lying", speed: 1, direct: true },
    landing: { clip: "landing", speed: 1, once: true },
    walking: { clip: "walk", speed: 1 },
    climbing: { clip: "climbing", speed: 1 },
  },
  clips: Object.fromEntries(CLIPS.map((clip) => [clip, clip])),
  poses: {
    sit_down: ["stand", "sit"], sitting: ["sit", "sit"], stand_up: ["sit", "stand"], lying: ["lie", "lie"],
    get_up: ["lie", "stand"], hanging: ["hang", "hang"], climbing: ["hang", "hang"], landing: ["land", "stand"],
  },
  // Lying down has no clip of its own: it sits down first, nearer lying than standing is.
  bridges: { "stand>sit": ["sit_down"], "sit>stand": ["stand_up"], "lie>stand": ["get_up"], "lie>sit": ["get_up", "sit_down"], "stand>lie": ["sit_down"] },
};

/** How long a blend takes, in seconds: between clips of one pose, and from one pose to another without a clip between. */
const BLEND = 0.3;
const BLEND_FAR = 0.7;
/** A weight below which a clip no longer counts and is stopped. */
const GONE = 0.001;

/** A clip to play: its action, once or over and over, how fast, from where, and for how long (s; Infinity: until
 * something else is played). */
interface Step {
  action: AnimationAction;
  once: boolean;
  speed: number;
  at?: number;
  seconds: number;
  /** No clip between the figure's pose and this one's. */
  direct?: boolean;
}

/** The model's clips: the one of the state shown, and a clip played over it once or for a time, which ends with a
 * change of state; each reached through the clips between, where its pose differs from the figure's. */
export class Clips {
  private readonly actions = new Map<string, AnimationAction>();
  /** Each clip that plays, by its weight in the pose. */
  private readonly weights = new Map<AnimationAction, number>();
  /** The step that plays and blends in, how long it has played, and the steps after it. */
  private front: Step | null = null;
  private elapsed = 0;
  private route: Step[] = [];
  /** How long the blend into the front's clip takes. */
  private blend = BLEND;
  /** The state's step, and whether a clip played over it is on its way (handed back to the state's after). */
  private state: Step | null = null;
  private over = false;
  private shown = "";

  constructor(
    private readonly mixer: AnimationMixer,
    clips: AnimationClip[],
    private readonly table: ClipTable,
  ) {
    for (const clip of clips) this.actions.set(clip.name, mixer.clipAction(clip));
  }

  /** Whether a clip between two poses plays (it sits down, stands up or gets up). */
  get between(): boolean {
    return this.route.length > 0;
  }

  /** The clip that gives the figure its pose now. */
  get current(): string | null {
    return this.front?.action.getClip().name ?? null;
  }

  /** Plays the clip of `state`, from where the table says, ending a clip played over the state's before. */
  show(state: State): void {
    const want = this.table.states[state];
    const key = `${want.clip}:${want.speed}:${want.at ?? ""}`;
    if (key === this.shown) return;
    this.shown = key;
    const action = this.actions.get(want.clip);
    if (!action) return;
    this.state = { action, once: !!want.once, speed: want.speed, at: want.at, seconds: Infinity, direct: want.direct };
    this.over = false;
    this.go(this.state);
  }

  /** Plays `clip` over what plays, once, or over and over for `ms`; answers how long, in ms, with the clips on the
   * way to it (0: the model has no such clip). */
  play(clip: Clip, ms?: number): number {
    const name = this.table.clips[clip];
    const action = name === undefined ? undefined : this.actions.get(name);
    if (!action || !this.state) return 0;
    this.over = true;
    const seconds = ms === undefined ? action.getClip().duration : ms / 1000;
    return this.go({ action, once: ms === undefined, speed: 1, seconds }) * 1000;
  }

  /** Moves the clips on by `dt` seconds: to the next step where one has played out (a clip played over that is
   * over hands back to the state's), the blend, and the clips. */
  update(dt: number): void {
    this.elapsed += dt;
    if (this.front && this.elapsed >= this.front.seconds) {
      const next = this.route.shift();
      if (next) this.begin(next);
      else if (this.over && this.state) {
        this.over = false;
        this.go(this.state);
      }
    }
    this.weigh(dt);
    this.mixer.update(dt);
  }

  /** Plays `target` after the clips between the figure's pose and its; answers how long until it has played (s). */
  private go(target: Step): number {
    const from = this.pose();
    const to = this.poseOf(target.action)[0];
    const between = target.direct || from === null || from === to ? [] : (this.table.bridges?.[`${from}>${to}`] ?? []);
    const steps: Step[] = between.flatMap((name) => {
      const action = this.actions.get(name);
      return action ? [{ action, once: true, speed: 1, seconds: action.getClip().duration }] : [];
    });
    const route = [...steps, target];
    this.route = route.slice(1);
    this.begin(route[0]!);
    return route.reduce((sum, step) => sum + step.seconds, 0);
  }

  /** The pose the figure is in: where the front's clip starts until it is half played, then where it ends (a
   * state's clip, played for no set time, by its own length). */
  private pose(): Pose | null {
    if (!this.front) return null;
    const [start, end] = this.poseOf(this.front.action);
    const { seconds, action } = this.front;
    const length = Number.isFinite(seconds) ? seconds : action.getClip().duration;
    return this.elapsed < length / 2 ? start : end;
  }

  private poseOf(action: AnimationAction): readonly [Pose, Pose] {
    return this.table.poses?.[action.getClip().name] ?? ["stand", "stand"];
  }

  /** Begins `step`: a clip played over and over that already plays goes on from where it is, others from their
   * start (or `at`). */
  private begin(step: Step): void {
    const { action } = step;
    const from = this.pose();
    const playing = (this.weights.get(action) ?? 0) > 0;
    if (!playing || (step.once && action !== this.front?.action)) action.reset();
    action.setLoop(step.once ? LoopOnce : LoopRepeat, step.once ? 1 : Infinity);
    action.clampWhenFinished = true;
    action.paused = false;
    action.enabled = true;
    action.timeScale = step.speed;
    if (step.at !== undefined) action.time = action.getClip().duration * step.at;
    action.play();
    this.blend = from === null || from === this.poseOf(action)[0] ? BLEND : BLEND_FAR;
    // The first clip of all is the pose at once.
    if (this.weights.size === 0) this.weights.set(action, 1);
    else if (!this.weights.has(action)) this.weights.set(action, 0);
    action.setEffectiveWeight(this.weights.get(action)!);
    this.front = step;
    this.elapsed = 0;
  }

  /** Blends the front's clip in by `dt`, the others out, each keeping its share of what is left. */
  private weigh(dt: number): void {
    if (!this.front) return;
    const front = this.front.action;
    const mine = Math.min(1, (this.weights.get(front) ?? 0) + dt / this.blend);
    let others = 0;
    for (const [action, weight] of this.weights) if (action !== front) others += weight;
    for (const [action, weight] of this.weights) {
      const now = action === front ? mine : others > 0 ? (weight / others) * (1 - mine) : 0;
      if (action !== front && now < GONE) {
        action.stop();
        this.weights.delete(action);
      } else {
        this.weights.set(action, now);
        action.setEffectiveWeight(now);
      }
    }
  }
}
