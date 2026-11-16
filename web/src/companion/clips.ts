// The companion's clips, apart from the drawing (figure.ts), so that a test runs them without WebGL: each model's
// table (`ClipTable`: the robot's own, `ROBOT`, and the carrier's, `CARRIED`, which every other figure is given) and
// `Clips`, which plays a state's clip, and a clip the companion is told to play over it, once or for a time. A state
// has several clips: one is picked by chance among those that fit the figure's mood (a feeling it showed, for a
// while; else the calm ones), and the next after `ROTATE` seconds; a clip told by name, among its versions alike.
// The catalogue's moods are mapped to those the figure takes (`TAKEN`), so that every clip can come.
//
// One clip goes into the next by a blend from the pose the figure has (the weights of all that still plays, scaled
// to make room for the new one, so they always add up to one, however often it changes mid-blend), and where the
// two clips' poses differ (standing, sitting, lying, hanging, landing) through the clips between them (`bridges`:
// it sits down before sitting, gets up before standing), else by a longer blend. A clip between that plays on goes
// on to what is wanted next where that starts where it ends, as getting up again would freeze the figure.
//
// Traps: three.js's own cross-fade starts the clip faded out at full weight, so a change mid-blend jumped: the
// weights are set here instead. A clip played once is held at its end (`clampWhenFinished`), as one switched off
// lets the figure's rest pose show through.
import { type AnimationAction, type AnimationClip, type AnimationMixer, LoopOnce, LoopRepeat } from "three";
import type { Clip } from "../api/generated/Clip";
import type { Feeling } from "../api/generated/Feeling";
import carrierClips from "../figures/animations.json";
import type { State } from "./body";

/** Where a clip leaves the body: standing, sitting on a seat not shown, sitting on the floor, lying, hanging, in the
 * air, landing. */
export type Pose = "stand" | "sit" | "floor" | "lie" | "hang" | "air" | "land";

/** A state's clips (the figure rotates among them, by its mood where one fits), and how fast they play (a speed of 0
 * holds the clip at `at` of its length; `direct`: reached by a blend alone, no clip between). */
export interface StateClips {
  clips: readonly string[];
  speed: number;
  at?: number;
  once?: boolean;
  direct?: boolean;
}

/** Each state's clips of a model; the model's clip of each clip the companion is told to play, where it has one (a
 * table without `clips` plays each by its own name, and its versions `<name>_2`, `<name>_3`, as the state's are
 * rotated); each clip's mood and poses. */
export interface ClipTable {
  states: Record<State, StateClips>;
  clips?: Partial<Record<Clip, string>>;
  /** The pose each of the model's clips starts and ends in; one not named stands throughout. */
  poses?: Record<string, readonly [Pose, Pose]>;
  /** Each clip's mood, one of `MOODS`'; one not named, or "", is calm. */
  moods?: Record<string, string>;
  /** The clips played once on the way from one pose to another, by `from>to`. */
  bridges?: Partial<Record<`${Pose}>${Pose}`, string[]>>;
}

/** The robot's own clips. */
export const ROBOT: ClipTable = {
  states: {
    idle: { clips: ["Idle"], speed: 1 },
    listening: { clips: ["Idle"], speed: 1 },
    thinking: { clips: ["Idle"], speed: 0.5 },
    talking: { clips: ["Idle"], speed: 1 },
    sleeping: { clips: ["Sitting"], speed: 1, once: true },
    sitting: { clips: ["Sitting"], speed: 1, once: true },
    startled: { clips: ["Jump"], speed: 1.5, once: true },
    dragged: { clips: ["Jump"], speed: 0, at: 0.4 },
    shaken: { clips: ["No"], speed: 2.5 },
    thrown: { clips: ["Jump"], speed: 0, at: 0.5 },
    falling: { clips: ["Jump"], speed: 0, at: 0.3 },
    bumped: { clips: ["Death"], speed: 0, at: 0.25 },
    bouncing: { clips: ["Death"], speed: 0, at: 0.8 },
    landing: { clips: ["Standing"], speed: 1, once: true },
    walking: { clips: ["Walking"], speed: 1 },
    climbing: { clips: ["Walking"], speed: 0.8 },
  },
  clips: {
    idle: "Idle", neutral_idle: "Idle", standard_idle: "Idle", breathing_idle: "Idle", thinking: "Idle", talking: "Idle",
    walking: "Walking", happy_walk: "Walking", sad_walk: "Walking", sitting_idle: "Sitting", stand_to_sit: "Sitting",
    stand_up: "Standing", standing_up: "Standing", getting_up: "Standing", laying_idle: "Death", falling_down: "Death",
    waving: "Wave", standing_greeting: "Wave", head_nod_yes: "Yes", agreeing: "Yes", thoughtful_head_nod: "Yes",
    no: "No", shaking_head_no: "No", jump: "Jump", joyful_jump: "Jump", dancing: "Dance", hip_hop_dancing: "Dance",
    silly_dancing: "Dance", cheering: "Dance", surprised: "Jump", shake_fist: "No", terrified: "Jump",
  },
};

/** The mood each feeling gives the figure. */
export const MOODS: Partial<Record<Feeling, string>> = {
  happy: "happy", excited: "happy", surprised: "surprised", sad: "sad", angry: "angry",
  afraid: "afraid", playful: "playful", bashful: "bashful", tired: "tired",
};

/** The figure's mood for each of the catalogue's moods that is a feeling (the rest are calm): no feeling the AI
 * shows is pained, so that comes with the nearest that is. */
const TAKEN: Record<string, string> = {
  happy: "happy", playful: "playful", sad: "sad", pained: "sad", angry: "angry", surprised: "surprised", afraid: "afraid",
  bashful: "bashful", tired: "tired",
};

/** Each clip of the carrier's (web/src/figures/animations.json): its mood, and the poses it starts and ends in. */
const SHIPPED = carrierClips as unknown as Record<string, [string, Pose, Pose]>;

/** The carrier's clips (tools/companion_assets.py), which every figure but the robot is given: the companion's 100,
 * each played by its own name, and the states' among them. */
export const CARRIED: ClipTable = {
  states: {
    idle: {
      clips: [
        "idle", "idle_2", "idle_3", "idle_4", "breathing_idle", "neutral_idle", "standard_idle",
        "weight_shift", "bored", "look_around_2", "looking_around", "scratch_idle", "arm_stretching", "yawn",
        "one_shoulder_lean", "leaning", "happy_idle", "happy_idle_2", "victory_idle", "happy", "sad_idle", "sad_idle_2",
        "crying", "angry", "nervously_look_around", "look_around", "bashful",
      ],
      speed: 1,
    },
    listening: {
      clips: ["acknowledging", "thoughtful_head_nod", "head_nod_yes", "agreeing", "agreeing_2", "breathing_idle", "happy_idle", "sad_idle", "bashful"],
      speed: 1,
    },
    thinking: { clips: ["thinking", "looking", "looking_2", "scratch_idle", "thoughtful_head_nod"], speed: 1 },
    talking: {
      clips: ["talking", "talking_2", "talking_3", "telling_a_secret", "laughing", "excited", "crying", "angry"],
      speed: 1,
    },
    sleeping: { clips: ["sleeping_idle", "sleeping_idle_2", "laying_sleeping"], speed: 1 },
    sitting: { clips: ["sitting_idle", "sitting_idle_2"], speed: 1 },
    startled: { clips: ["surprised", "reacting"], speed: 1, once: true },
    dragged: { clips: ["hanging_idle", "hanging_idle_2"], speed: 1 },
    shaken: { clips: ["falling_idle", "fall_loop"], speed: 1 },
    thrown: { clips: ["fall_loop", "falling_idle"], speed: 1 },
    falling: { clips: ["fall_loop", "falling_idle"], speed: 1 },
    bumped: { clips: ["reacting"], speed: 0, at: 0.3 },
    // Thrown, it lies at once while it bounces, not by a clip between.
    bouncing: { clips: ["laying_idle", "laying_idle_2"], speed: 1, direct: true },
    landing: { clips: ["hard_landing", "hard_landing_2", "fall_landing"], speed: 1, once: true },
    walking: { clips: ["walking", "walking_2", "walking_3", "walking_4", "happy_walk", "sad_walk"], speed: 1 },
    climbing: { clips: ["climbing_up_wall"], speed: 1 },
  },
  poses: Object.fromEntries(Object.entries(SHIPPED).map(([name, [, start, end]]) => [name, [start, end] as const])),
  moods: Object.fromEntries(Object.entries(SHIPPED).map(([name, [mood]]) => [name, TAKEN[mood] ?? ""])),
  // Getting down to the floor or lying has no clip of the 100 but falling: a longer blend.
  bridges: { "stand>sit": ["stand_to_sit"], "floor>stand": ["standing_up"], "lie>stand": ["stand_up"] },
};


/** How long a state's clip plays before the next of its clips (s), and a mood lasts. */
const ROTATE = 12;
const MOOD_LASTS = 60;

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
  /** The state's clips, the mood they are picked by ("": calm) and how long it lasts yet (s). */
  private want: StateClips | null = null;
  private mood = "";
  private moodLeft = 0;

  constructor(
    private readonly mixer: AnimationMixer,
    clips: AnimationClip[],
    private readonly table: ClipTable,
    private readonly random: () => number = Math.random,
  ) {
    for (const clip of clips) this.actions.set(clip.name, mixer.clipAction(clip));
  }

  /** Whether a clip between two poses plays (it sits down, stands up or gets up), or a state's clip played once
   * (a landing) has not played out. */
  get between(): boolean {
    const front = this.front;
    if (this.route.length > 0) return true;
    return !!front && front === this.state && front.once && this.elapsed * front.speed < front.action.getClip().duration;
  }

  /** The clip that gives the figure its pose now. */
  get current(): string | null {
    return this.front?.action.getClip().name ?? null;
  }

  /** Plays a clip of `state`, from where the table says, ending a clip played over the state's before. */
  show(state: State): void {
    const want = this.table.states[state];
    const key = `${want.clips.join()}:${want.speed}:${want.at ?? ""}`;
    if (key === this.shown) return;
    this.shown = key;
    this.want = want;
    this.over = false;
    this.rotate();
  }

  /** Gives the figure the mood of `feeling` (`MOODS`) for a while: the clips are picked by it, and a state's clip
   * that does not fit gives way at once. */
  feel(feeling: Feeling): void {
    const mood = MOODS[feeling];
    if (!mood) return;
    this.mood = mood;
    this.moodLeft = MOOD_LASTS;
    if (!this.over && !this.fits()) this.rotate();
  }

  /** Plays `clip` over what plays, once, or over and over for `ms`; answers how long, in ms, with the clips on the
   * way to it (0: the model has no such clip). */
  play(clip: Clip, ms?: number): number {
    const own = this.table.clips ? this.table.clips[clip] : clip;
    const versions = own === undefined ? [] : [own];
    for (let n = 2; own !== undefined && !this.table.clips && this.actions.has(`${own}_${n}`); n++) versions.push(`${own}_${n}`);
    const name = this.pick(versions);
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
    this.moodLeft -= dt;
    if (this.moodLeft <= 0) this.mood = "";
    if (this.front && this.elapsed >= this.front.seconds) {
      const next = this.route.shift();
      if (next) this.begin(next);
      else if (this.over && this.state) {
        this.over = false;
        if (this.fits()) this.go(this.state);
        else this.rotate();
      }
    } else if (this.state && this.front === this.state && !this.state.once && this.elapsed >= ROTATE) this.rotate();
    this.weigh(dt);
    this.mixer.update(dt);
  }

  /** Plays the next of the state's clips (one only where it has no other that fits). */
  private rotate(): void {
    const name = this.want ? this.pick(this.want.clips, this.state?.action.getClip().name) : undefined;
    const action = name === undefined ? undefined : this.actions.get(name);
    if (!action || !this.want) return;
    const { once, speed, at, direct } = this.want;
    this.state = { action, once: !!once, speed, at, seconds: Infinity, direct };
    this.go(this.state);
  }

  /** Whether the state's clip fits the mood. */
  private fits(): boolean {
    return !this.want || !this.state || this.fitting(this.want.clips).includes(this.state.action.getClip().name);
  }

  /** Those of `names` the model has that fit the mood: its own, else the calm ones, else all. */
  private fitting(names: readonly string[]): string[] {
    const have = names.filter((name) => this.actions.has(name));
    const moods = this.table.moods ?? {};
    const felt = this.mood === "" ? [] : have.filter((name) => moods[name] === this.mood);
    const calm = have.filter((name) => !moods[name]);
    return felt.length > 0 ? felt : calm.length > 0 ? calm : have;
  }

  /** One of `names` that fits the mood, by chance, another than `now` where there is one. */
  private pick(names: readonly string[], now?: string): string | undefined {
    const fit = this.fitting(names);
    const others = fit.filter((name) => name !== now);
    const from = others.length > 0 ? others : fit;
    return from[Math.floor(this.random() * from.length)];
  }

  /** Plays `target` after the clips between the figure's pose and its; answers how long until it has played (s). */
  private go(target: Step): number {
    const to = this.poseOf(target.action)[0];
    // A clip between that plays on goes on to `target` where it ends in its pose.
    const last = this.route.length > 1 ? this.route[this.route.length - 2] : this.front;
    if (this.route.length > 0 && this.front && last && !target.direct && this.poseOf(last.action)[1] === to) {
      this.route = [...this.route.slice(0, -1), target];
      return this.route.reduce((sum, step) => sum + step.seconds, this.front.seconds - this.elapsed);
    }
    const from = this.pose();
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
