// The companion's figure as a body on the screen, without drawing it (figure.ts draws it): where its feet are, in
// the companion window's CSS pixels (the floor is the window's foot, the edges its sides), and how it moves: at
// rest, held by the hand, in the air after a throw or a fall, walking along the floor, climbing an edge of the
// screen, hanging where it climbed to. `stateOf` says what it plays: the states the board "Companion window" names
// and each stage of being handled that circe's avatar plan (`PLAN-avatar-system.md`) has: held, shaken (`shaking`
// tells it from the hand's moves), thrown or falling, hitting an edge, bouncing on the floor, landing, startled by a
// click, sitting. What happened since the hand took it is `happened`, which the animator is told. That plan
// ("Physics", "Event vocabulary") is where the numbers come from.
//
// Traps: `step` is to be given at most `LONGEST_TICK` at a time, as a long pause between frames would carry the
// body through the floor; a body the window shrinks under falls to the new floor (`fit`). `SIZE` changes with the
// size in Settings (`sizeTo`), so it is read where it is used, never copied.
import type { Edge } from "../api/generated/Edge";
import type { Handling } from "../api/generated/Handling";

/** The figure's box in CSS pixels at first, whose shape every size keeps. */
const BOX = { width: 200, height: 260 };
/** The figure's box in CSS pixels as sized now (`sizeTo`); its feet are at the middle of its foot. */
export const SIZE = { ...BOX };
/** The share of the box's height the figure takes, standing (figure.ts frames it so). */
export const FILL = 0.62;

/** Sizes the figure's box so that the figure standing is `percent` of a window `height` px high. */
export function sizeTo(percent: number, height: number): void {
  SIZE.height = Math.round((percent / 100) * height / FILL);
  SIZE.width = Math.round((SIZE.height * BOX.width) / BOX.height);
}
/** Half the figure's width standing, as a share of its height standing: narrower than its canvas, whose sides are
 * see-through (a person's shoulders, a robot's arms). */
const HALF_SPAN = 0.2;
/** Room between the figure and its compact chat, in CSS pixels. */
const CHAT_GAP = 12;

/** The left of a chat `width` wide beside the figure whose feet are at `x`: close at its right where the window,
 * `windowWidth` wide, has room, else close at its left (the board's "beside it"). */
export function beside(x: number, width: number, windowWidth: number): number {
  const reach = SIZE.height * FILL * HALF_SPAN + CHAT_GAP;
  return x + reach + width <= windowWidth ? x + reach : x - reach - width;
}
/** Where the face is, as a share of the figure's height above its feet. */
export const FACE = 0.55;
/** Pixels a second, a second. */
const GRAVITY = 2000;
/** What share of its speed the body keeps off the floor and off an edge. */
const FLOOR_BOUNCE = 0.35;
const EDGE_BOUNCE = 0.5;
/** How fast the floor slows a body that slides on it, in pixels a second, a second. */
const FRICTION = 1200;
/** Below this speed a body on the floor stops (pixels a second). */
const SETTLE = 40;
/** A release faster than this is a throw, and none is faster than `FASTEST` (pixels a second). */
const THROW = 300;
const FASTEST = 3000;
const WALK = 150;
const CLIMB = 90;
/** The longest time `step` takes at once, in seconds. */
export const LONGEST_TICK = 0.033;
/** Off an edge faster than this the body is seen to hit it (pixels a second). */
const BUMP = 150;
/** How long the one-shot stages show, in seconds. */
const BUMPED_S = 0.4;
const LANDING_S = 1.2;
const STARTLED_S = 0.6;
/** A shake: this many turns of the hand to and fro, each a swing of at least `SWING` pixels, within `SHAKE_MS`. */
const TURNS = 4;
const SWING = 8;
const SHAKE_MS = 1000;
/** The most stages `happened` keeps, as the server does (companion.rs, `MOST_HANDLED`). */
const NOTED = 16;

export type Motion =
  | { kind: "rest" }
  | { kind: "held" }
  | { kind: "air"; thrown: boolean }
  | { kind: "walk"; to: number }
  | { kind: "climb"; side: Edge; to: number }
  | { kind: "hang"; side: Edge };

export type State =
  | "idle"
  | "listening"
  | "thinking"
  | "talking"
  | "sleeping"
  | "sitting"
  | "startled"
  | "dragged"
  | "shaken"
  | "thrown"
  | "falling"
  | "bumped"
  | "bouncing"
  | "landing"
  | "walking"
  | "climbing";

/** What the compact chat is doing, which the figure shows while it is at rest. */
export type Mood = "listening" | "thinking" | "talking" | null;

export class Body {
  vx = 0;
  vy = 0;
  motion: Motion = { kind: "rest" };
  /** Which way it walked last: -1 left, 1 right, 0 towards the user. */
  heading: -1 | 0 | 1 = 0;
  /** Whether the hand shakes it now. */
  shaking = false;
  /** Whether it bounced off the floor since it was last let go. */
  bounced = false;
  /** Whether the figure gets to its feet (figure.ts), meanwhile it walks and climbs nowhere. */
  rising = false;
  /** What happened since the hand last took it, in order, each stage once in a row. */
  happened: Handling[] = [];
  /** Seconds the body has been stepped, which the one-shot stages are timed by. */
  private clock = 0;
  private until = { bumped: -1, landing: -1, startled: -1 };

  constructor(
    public area: { width: number; height: number },
    public x: number,
    public y: number,
  ) {}

  private get left(): number {
    return SIZE.width / 2;
  }
  private get right(): number {
    return Math.max(this.left, this.area.width - SIZE.width / 2);
  }

  /** Taken by the hand, which woke it where it slept: it goes where `x`, `y` are put, until released. */
  hold(woken = false): void {
    this.motion = { kind: "held" };
    this.vx = this.vy = 0;
    this.heading = 0;
    this.happened = woken ? ["woken", "held"] : ["held"];
  }

  /** The hand shakes it, or stopped shaking it. */
  shake(now: boolean): void {
    if (now && !this.shaking) this.note("shaken");
    this.shaking = now;
  }

  /** A click on it: it starts, where it stands. */
  startle(): void {
    if (this.motion.kind === "rest") this.until.startled = this.clock + STARTLED_S;
  }

  /** Whether it is getting up from a landing, before which it goes nowhere. */
  get gettingUp(): boolean {
    return this.clock < this.until.landing;
  }

  /** Which one-shot stage shows now, if any. */
  shownOnce(): "bumped" | "landing" | "startled" | null {
    if (this.motion.kind === "air" && this.clock < this.until.bumped) return "bumped";
    if (this.motion.kind !== "rest") return null;
    if (this.gettingUp) return "landing";
    return this.clock < this.until.startled ? "startled" : null;
  }

  /** Notes a stage, at most `NOTED` of them: when full, the newest takes the last one's place, so a landing ends it. */
  private note(what: Handling): void {
    if (this.happened[this.happened.length - 1] === what) return;
    if (this.happened.length >= NOTED) this.happened.pop();
    this.happened.push(what);
  }

  /** Let go by the hand at this speed: a throw, or a fall where it is slow. */
  release(vx: number, vy: number): void {
    const speed = Math.hypot(vx, vy);
    const thrown = speed > THROW;
    const kept = thrown ? Math.min(1, FASTEST / speed) : 0;
    this.vx = vx * kept;
    this.vy = vy * kept;
    this.motion = { kind: "air", thrown };
    this.shaking = false;
    this.bounced = false;
    this.note(thrown ? "thrown" : "dropped");
  }

  /** Walks to `x` on the floor; not while the hand holds it (an answer or a walk of its own that came late). */
  walkTo(x: number): void {
    if (this.motion.kind === "held") return;
    const to = Math.min(this.right, Math.max(this.left, x));
    this.heading = to < this.x ? -1 : to > this.x ? 1 : this.heading;
    this.motion = { kind: "walk", to };
  }

  /** Walks to an edge, then climbs it to `height`, a share of the height above the floor. */
  climb(side: Edge, height: number): void {
    if (this.motion.kind === "held") return;
    const room = this.area.height - SIZE.height;
    this.motion = { kind: "climb", side, to: this.area.height - Math.min(1, Math.max(0, height)) * Math.max(0, room) };
  }

  /** Lets go of the edge it is on, or stops whatever it does, and falls. */
  letGo(): void {
    this.vx = this.vy = 0;
    this.bounced = false;
    this.motion = { kind: "air", thrown: false };
  }

  /** Whether it is up an edge, climbing or hanging above the floor (not on its way there along the floor). */
  get onEdge(): boolean {
    return (this.motion.kind === "climb" || this.motion.kind === "hang") && this.y < this.area.height;
  }

  /** Stops walking or climbing: falls from where it climbed to, else rests where it stands. */
  stop(): void {
    if (this.onEdge) this.letGo();
    else if (this.motion.kind === "walk" || this.motion.kind === "climb" || this.motion.kind === "hang") this.motion = { kind: "rest" };
  }

  /** The window is another size now: the body stays inside it, and falls where the floor went down. */
  fit(area: { width: number; height: number }): void {
    this.area = area;
    this.x = Math.min(this.right, Math.max(this.left, this.x));
    if (this.y > area.height) this.y = area.height;
    if (this.motion.kind === "rest" && this.y < area.height) this.letGo();
  }

  /** Moves the body on by `dt` seconds. */
  step(dt: number): void {
    dt = Math.min(dt, LONGEST_TICK);
    this.clock += dt;
    const floor = this.area.height;
    const motion = this.motion;
    if (motion.kind === "air") {
      this.vy += GRAVITY * dt;
      this.x += this.vx * dt;
      this.y += this.vy * dt;
      if (this.x < this.left || this.x > this.right) {
        this.x = Math.min(this.right, Math.max(this.left, this.x));
        if (Math.abs(this.vx) > BUMP) {
          this.until.bumped = this.clock + BUMPED_S;
          this.note("hit_edge");
        }
        this.vx = -this.vx * EDGE_BOUNCE;
      }
      if (this.y - SIZE.height < 0) {
        this.y = SIZE.height;
        this.vy = Math.abs(this.vy) * EDGE_BOUNCE;
      }
      if (this.y >= floor) {
        this.y = floor;
        this.vy = this.vy * FLOOR_BOUNCE > SETTLE ? -this.vy * FLOOR_BOUNCE : 0;
        if (this.vy !== 0) {
          this.bounced = true;
          this.note("bounced");
        }
        if (this.vy === 0) {
          // Sliding on the floor, slowed down by it.
          const slower = Math.max(0, Math.abs(this.vx) - FRICTION * dt);
          this.vx = Math.sign(this.vx) * slower;
          if (slower < SETTLE) {
            this.vx = 0;
            this.motion = { kind: "rest" };
            this.until.landing = this.clock + LANDING_S;
            this.note("landed");
          }
        }
      }
      return;
    }
    if ((motion.kind === "walk" || motion.kind === "climb") && this.rising) return;
    if (motion.kind === "walk") {
      this.x = towards(this.x, motion.to, WALK * dt);
      if (this.x === motion.to) this.motion = { kind: "rest" };
      return;
    }
    if (motion.kind === "climb") {
      const wall = motion.side === "left" ? this.left : this.right;
      if (this.x !== wall) {
        // To the edge first, along the floor.
        this.heading = wall < this.x ? -1 : 1;
        this.x = towards(this.x, wall, WALK * dt);
        return;
      }
      this.y = towards(this.y, motion.to, CLIMB * dt);
      if (this.y === motion.to) this.motion = { kind: "hang", side: motion.side };
      return;
    }
    if (motion.kind === "rest" && this.y < floor) this.letGo();
  }
}

/** `from` moved by at most `by` towards `to`. */
function towards(from: number, to: number, by: number): number {
  return Math.abs(to - from) <= by ? to : from + Math.sign(to - from) * by;
}

/** What the figure plays: what the hand and the air do first, then its own moving, then a stage shown once, then
 * the chat, then sleep, then sitting still. */
export function stateOf(body: Body, mood: Mood, asleep: boolean, still = false): State {
  const motion = body.motion;
  const once = body.shownOnce();
  if (motion.kind === "held") return body.shaking ? "shaken" : "dragged";
  if (motion.kind === "air") return once ?? (body.bounced ? "bouncing" : motion.thrown ? "thrown" : "falling");
  if (motion.kind === "walk") return "walking";
  if (motion.kind === "climb") return body.x === (motion.side === "left" ? SIZE.width / 2 : Math.max(SIZE.width / 2, body.area.width - SIZE.width / 2)) ? "climbing" : "walking";
  if (motion.kind === "hang") return "climbing";
  return once ?? mood ?? (asleep ? "sleeping" : still ? "sitting" : "idle");
}

/** Where the hand was, in CSS pixels, and when (ms). */
export interface Sample {
  x: number;
  y: number;
  at: number;
}

/** Whether the hand shakes what it holds: `TURNS` turns to and fro, each after a swing of `SWING` pixels or more,
 * within the last `SHAKE_MS` before `now` (ms). */
export function shaking(samples: Sample[], now: number): boolean {
  let turns = 0;
  let way = 0;
  let far: number | null = null;
  for (const sample of samples) {
    if (sample.at < now - SHAKE_MS) continue;
    if (far === null) {
      far = sample.x;
      continue;
    }
    const swing = sample.x - far;
    if (way !== 0 && Math.sign(swing) === way) far = sample.x;
    else if (Math.abs(swing) >= SWING) {
      if (way !== 0) turns += 1;
      way = Math.sign(swing);
      far = sample.x;
    }
  }
  return turns >= TURNS;
}

/** The hand's speed over its last tenth of a second, in pixels a second: what a release throws the body with. */
export function throwOf(samples: Sample[]): { vx: number; vy: number } {
  const last = samples[samples.length - 1];
  const first = samples.find((sample) => sample.at >= (last?.at ?? 0) - 100);
  if (!last || !first || last.at === first.at) return { vx: 0, vy: 0 };
  const seconds = (last.at - first.at) / 1000;
  return { vx: (last.x - first.x) / seconds, vy: (last.y - first.y) / seconds };
}
