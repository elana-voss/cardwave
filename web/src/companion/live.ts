// The companion as one interface on its page (the server's companion/live.rs is the same over HTTP and as tools):
// what it does, `act` (the steps of `Move`: walk, climb, let go, play a clip, look, react, say, wait), and what it
// knows of itself, `state`. `Companion` runs the steps on the body (plan.ts) and the figure, keeps where it looks,
// the feeling it shows and the message its bubble says, each for a time on its own clock, and `reporter` tells the
// server what the figure does. main.ts hands it the server's acts, the worker model's moves and its own wanders;
// 95c's steering uses it too.
//
// Traps: an act takes the place of what was under way, and the hand that takes the figure ends it (`stop`). A look
// turns the whole figure in every state but walking and climbing; a feeling also plays its clip once.
import type { Clip } from "../api/generated/Clip";
import type { CompanionFigure } from "../api/generated/CompanionFigure";
import type { Feeling } from "../api/generated/Feeling";
import type { Move } from "../api/generated/Move";
import type { Point } from "../api/generated/Point";
import { FACE, SIZE, type Body, type State } from "./body";
import { Plan, type Actor } from "./plan";

/** What the companion asks of the drawn figure (figure.ts), so that a test runs it without WebGL. */
export interface Shown {
  play(clip: Clip, ms?: number): number;
  look(yaw: number, pitch: number): void;
  feel(feeling: Feeling | null): void;
  readonly clip: string | null;
}

/** The clip each feeling plays once. */
export const FEELINGS: Record<Feeling, Clip> = {
  happy: "jump",
  excited: "dance",
  surprised: "startled",
  sad: "idle_shift",
  angry: "no",
  agree: "nod",
  disagree: "no",
  puzzled: "thinking",
};

/** How long a feeling shows at least, and a look lasts, in ms. */
const FEEL_MS = 3000;
const LOOK_MS = 5000;
/** How far the user's eyes are taken to be from the screen, in CSS pixels, which makes a look's angles. */
const EYES = 600;
/** How far the figure turns to where it looks, at most (radians). */
const YAW = 0.8;

/** How long a message shows: by its length, between 2.5 and 10 s. */
export const sayingMs = (text: string): number => Math.min(10_000, Math.max(2500, 1500 + 60 * [...text].length));

export class Companion implements Actor {
  private plan: Plan | null = null;
  /** The last act of the server's it has begun, by its number. */
  private acted = 0;
  private clock = 0;
  /** Whether it sits still, as the last frame said. */
  private still = false;
  private looking: { at: Point; until: number } | null = null;
  private feeling: { is: Feeling; until: number } | null = null;
  private saying: { text: string; until: number } | null = null;

  constructor(
    private readonly body: Body,
    private readonly figure: Shown,
  ) {}

  /** Has the figure do `steps` in place of what it does, the first begun at once, so the state told after says it;
   * `act` is the server's number of them, where it sent them. */
  act(steps: Move[], act?: number): void {
    this.plan = new Plan(steps);
    this.plan.step(0, this.body, this.still, this);
    if (act !== undefined) this.acted = Math.max(this.acted, act);
  }

  /** Ends what it was doing: the hand took it. */
  stop(): void {
    this.plan = null;
  }

  /** Whether it is doing what it was told. */
  get busy(): boolean {
    return this.plan !== null && !this.plan.done;
  }

  /** What its bubble says now, or null. */
  get said(): string | null {
    return this.saying?.text ?? null;
  }

  /** Runs on by `dt` seconds: the steps, and the look, feeling and message, each until its time ends. */
  step(dt: number, still: boolean): void {
    this.clock += dt * 1000;
    this.still = still;
    if (this.plan?.done) this.plan = null;
    this.plan?.step(dt, this.body, still, this);
    if (this.feeling && this.clock >= this.feeling.until) {
      this.feeling = null;
      this.figure.feel(null);
    }
    if (this.saying && this.clock >= this.saying.until) this.saying = null;
    if (this.looking && this.clock >= this.looking.until) this.looking = null;
    const at = this.looking?.at;
    if (!at) return this.figure.look(0, 0);
    const face = this.body.y - SIZE.height * FACE;
    const yaw = Math.atan2(at.x - this.body.x, EYES);
    this.figure.look(Math.max(-YAW, Math.min(YAW, yaw)), Math.atan2(at.y - face, EYES));
  }

  play(clip: Clip, ms?: number): number {
    return this.figure.play(clip, ms);
  }

  look(at: Point | null): void {
    this.looking = at && { at, until: this.clock + LOOK_MS };
  }

  react(feeling: Feeling): number {
    const ms = Math.max(this.figure.play(FEELINGS[feeling]), FEEL_MS);
    this.feeling = { is: feeling, until: this.clock + ms };
    this.figure.feel(feeling);
    return ms;
  }

  say(text: string): number {
    if (!text.trim()) return 0;
    const ms = sayingMs(text);
    this.saying = { text, until: this.clock + ms };
    return ms;
  }

  /** What it knows of itself, in the figure's `state`, its chat open or not, on a screen of `width` by `height`. */
  state(state: State, chatOpen: boolean, width: number, height: number): CompanionFigure {
    return {
      width,
      height,
      x: Math.round(this.body.x),
      y: Math.round(this.body.y),
      state,
      clip: this.figure.clip,
      looking: this.looking?.at ?? null,
      feeling: this.feeling?.is ?? null,
      saying: this.said,
      steps: this.plan?.left ?? [],
      chat_open: chatOpen,
      acted: this.acted,
    };
  }
}

/** Tells the server what the figure does (`send`): at once when told `now`, else at most each half second while
 * it changes and every five seconds while it does not, which keeps it counted as shown. `known` makes what it does,
 * called only when it may be told. */
export function reporter(send: (figure: CompanionFigure) => Promise<unknown>): (known: () => CompanionFigure, now?: boolean) => void {
  let last = "";
  let at = -Infinity;
  return (known, now = false) => {
    const since = Date.now() - at;
    if (!now && since < 500) return;
    const figure = known();
    const said = JSON.stringify(figure);
    if (!now && said === last && since < 5000) return;
    last = said;
    at = Date.now();
    void send(figure).catch(() => {});
  };
}
