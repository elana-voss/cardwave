// What the companion's figure does by itself: the moves the animator answered after a reply (server's
// companion.rs, `Move`), run one after the other on the body (`Plan`), and, while nothing is planned, a walk now
// and then (`wander`). A plan runs from one tick to the next: a walk lasts until the body is there, a climb until
// it hangs at its height, a let-go until it rests on the floor, a clip, a feeling or a message as long as the actor
// (live.ts) says, a look at once.
//
// While the figure sits still (its menu's "Sit still") a plan's walks and climbs are left out. The hand that takes
// the figure ends the plan (main.ts drops it then); a plan waits while the figure flies and gets up from a landing, walks from up an
// edge only once it has let go and landed (from a climb still on the floor at once), and lets go of an edge it ends on.
import type { Move } from "../api/generated/Move";
import type { Clip } from "../api/generated/Clip";
import type { Feeling } from "../api/generated/Feeling";
import type { Point } from "../api/generated/Point";
import { FACE, SIZE, type Body } from "./body";

/** What runs the steps that are not the body's; each answers how long it takes, in ms. */
export interface Actor {
  /** Plays a clip once, or over and over for `ms`. */
  play(clip: Clip, ms?: number): number;
  /** Looks at a point of the screen; null: at the user. */
  look(at: Point | null): void;
  react(feeling: Feeling): number;
  say(text: string): number;
}

export class Plan {
  private at = -1;
  /** What is left of a clip, a feeling, a message or a wait, in ms. */
  private wait = 0;
  /** Where a walk goes that waits for the body to land, as it began on an edge. */
  private landing: number | null = null;
  private ended = false;

  constructor(private readonly moves: Move[]) {}

  get done(): boolean {
    return this.at >= this.moves.length;
  }

  /** What is left of the plan, the move under way first. */
  get left(): Move[] {
    return this.moves.slice(Math.max(0, this.at));
  }

  /** Runs the plan on by `dt` seconds: the move in hand goes on, or the next begins. */
  step(dt: number, body: Body, still: boolean, actor: Actor): void {
    this.wait -= dt * 1000;
    // Nothing goes on while the hand holds the body, it flies or it gets up from a landing.
    if (body.motion.kind === "held" || body.motion.kind === "air" || body.gettingUp) return;
    if (this.landing !== null) {
      body.walkTo(this.landing);
      this.landing = null;
    }
    while (!this.done && (this.at < 0 || this.over(body))) {
      this.at += 1;
      const move = this.moves[this.at];
      if (move) this.begin(move, body, still, actor);
    }
    // A plan does not leave the figure hanging on an edge.
    if (this.done && !this.ended) {
      this.ended = true;
      if (body.motion.kind === "hang") body.stop();
    }
  }

  private begin(move: Move, body: Body, still: boolean, actor: Actor): void {
    this.wait = 0;
    switch (move.do) {
      case "walk":
        if (still) return;
        // From up an edge it lets go first, and walks once it has landed.
        if (body.onEdge) {
          body.letGo();
          this.landing = move.x;
        } else body.walkTo(move.x);
        return;
      case "climb":
        if (!still) body.climb(move.side, move.height);
        return;
      case "let_go":
        if (body.motion.kind === "climb" || body.motion.kind === "hang") body.stop();
        return;
      case "play":
        this.wait = actor.play(move.clip, move.ms);
        return;
      case "look":
        // A look with one of the two looks level with the face, or straight up or down.
        actor.look(move.x === undefined && move.y === undefined ? null : { x: move.x ?? body.x, y: move.y ?? body.y - SIZE.height * FACE });
        return;
      case "react":
        this.wait = actor.react(move.feeling);
        return;
      case "say":
        this.wait = actor.say(move.text);
        return;
      case "wait":
        this.wait = move.ms;
        return;
    }
  }

  /** Whether the move in hand is over. */
  private over(body: Body): boolean {
    switch (this.moves[this.at]?.do) {
      case "walk":
        return this.landing === null && body.motion.kind !== "walk";
      case "climb":
        return body.motion.kind !== "climb";
      case "let_go":
        return body.motion.kind !== "air";
      default:
        return this.wait <= 0;
    }
  }
}

/** A walk to a place along the floor, or one time in four a climb up an edge that lets go after a while. */
export function wander(area: { width: number; height: number }, random: () => number = Math.random): Move[] {
  const chance = random();
  if (chance < 0.25) {
    return [
      { do: "climb", side: chance < 0.125 ? "left" : "right", height: 0.3 + chance },
      { do: "wait", ms: 3000 },
      { do: "let_go" },
    ];
  }
  return [{ do: "walk", x: Math.round(area.width * chance) }];
}
