import { describe, expect, it } from "vitest";
import { Body, FILL, SIZE, beside, shaking, sizeTo, stateOf, throwOf } from "./body";

const AREA = { width: 1000, height: 600 };

/** Steps the body by 30 ms ticks for `seconds`. */
function run(body: Body, seconds: number): void {
  for (let t = 0; t < seconds; t += 0.03) body.step(0.03);
}

describe("the companion's body", () => {
  it("falls from where it is let go, bounces and comes to rest on the floor", () => {
    const body = new Body(AREA, 500, 200);
    body.hold();
    body.release(0, 0);
    expect(body.motion).toEqual({ kind: "air", thrown: false });
    run(body, 0.4);
    expect(body.y).toBeGreaterThan(200);
    run(body, 4);
    expect(body.motion.kind).toBe("rest");
    expect(body.y).toBe(AREA.height);
    expect(body.x).toBe(500);
  });

  it("flies where it is thrown, off the wall it meets, and stays inside the screen", () => {
    const body = new Body(AREA, 500, 300);
    body.hold();
    body.release(3000, -500);
    expect(body.motion).toEqual({ kind: "air", thrown: true });
    run(body, 0.3);
    // It met the right edge and came back off it.
    expect(body.x).toBeLessThanOrEqual(AREA.width - SIZE.width / 2);
    expect(body.vx).toBeLessThan(0);
    run(body, 6);
    expect(body.motion.kind).toBe("rest");
    expect(body.x).toBeGreaterThanOrEqual(SIZE.width / 2);
    // A hand as fast as a mouse jumping is no faster than a hard throw.
    body.hold();
    body.release(-400_000, -300_000);
    expect([body.vx, body.vy]).toEqual([-2400, -1800]);
    expect(body.y).toBe(AREA.height);
  });

  it("goes nowhere while the figure gets to its feet", () => {
    const body = new Body(AREA, 500, AREA.height);
    body.rising = true;
    body.walkTo(200);
    run(body, 1);
    expect(body.x).toBe(500);
    body.rising = false;
    run(body, 1);
    expect(body.x).toBeLessThan(500);
  });

  it("walks along the floor to a place and stops there, facing where it went", () => {
    const body = new Body(AREA, 500, AREA.height);
    body.walkTo(200);
    run(body, 1);
    expect(body.motion.kind).toBe("walk");
    expect(body.heading).toBe(-1);
    run(body, 3);
    expect(body.motion.kind).toBe("rest");
    expect(body.x).toBe(200);
  });

  it("neither walks nor climbs while the hand holds it", () => {
    const body = new Body(AREA, 500, 300);
    body.hold();
    body.walkTo(100);
    body.climb("left", 0.5);
    expect(body.motion).toEqual({ kind: "held" });
  });

  it("stopped on its way along the floor to an edge, rests where it stands without a landing", () => {
    const body = new Body(AREA, 500, AREA.height);
    body.climb("right", 0.5);
    body.step(0.1);
    body.stop();
    expect(body.motion).toEqual({ kind: "rest" });
    body.step(0.03);
    expect(body.gettingUp).toBe(false);
    expect(body.happened).not.toContain("landed");
  });

  it("climbs an edge to a height, hangs there, and falls when it lets go", () => {
    const body = new Body(AREA, 500, AREA.height);
    body.climb("right", 0.5);
    run(body, 20);
    expect(body.motion).toEqual({ kind: "hang", side: "right" });
    expect(body.x).toBe(AREA.width - SIZE.width / 2);
    expect(body.y).toBe(AREA.height - 0.5 * (AREA.height - SIZE.height));
    body.letGo();
    run(body, 5);
    expect(body.motion.kind).toBe("rest");
    expect(body.y).toBe(AREA.height);
  });

  it("says what it plays: the hand and the air first, then its moving, then the chat, then sleep", () => {
    const body = new Body(AREA, 500, AREA.height);
    expect(stateOf(body, null, false)).toBe("idle");
    expect(stateOf(body, null, true)).toBe("sleeping");
    expect(stateOf(body, "listening", true)).toBe("listening");
    body.walkTo(100);
    expect(stateOf(body, "talking", false)).toBe("walking");
    body.climb("left", 0.2);
    expect(stateOf(body, null, false)).toBe("walking");
    run(body, 4);
    expect(stateOf(body, null, false)).toBe("climbing");
    body.hold();
    expect(stateOf(body, "thinking", false)).toBe("dragged");
    body.release(2000, 0);
    expect(stateOf(body, null, false)).toBe("thrown");
    body.hold();
    body.release(0, 0);
    expect(stateOf(body, null, false)).toBe("falling");
  });
});

describe("a throw", () => {
  it("is the hand's speed over its last tenth of a second, in pixels a second", () => {
    const samples = [
      { x: 0, y: 0, at: 0 },
      { x: 500, y: 0, at: 300 },
      { x: 520, y: 10, at: 400 },
      { x: 560, y: 30, at: 450 },
      { x: 600, y: 50, at: 500 },
    ];
    expect(throwOf(samples)).toEqual({ vx: 800, vy: 400 });
    expect(throwOf(samples.slice(0, 1))).toEqual({ vx: 0, vy: 0 });
  });
});

describe("the companion's body handled by the hand", () => {
  it("shows each stage: held, shaken, thrown, hitting the edge, bouncing, landing, and notes them in order", () => {
    const body = new Body(AREA, 500, 400);
    body.hold(true);
    expect(stateOf(body, null, false)).toBe("dragged");
    body.shake(true);
    expect(stateOf(body, null, false)).toBe("shaken");
    body.shake(false);
    body.release(2500, 0);
    const seen = new Set<string>();
    for (let t = 0; t < 8; t += 0.03) {
      body.step(0.03);
      seen.add(stateOf(body, null, false));
    }
    expect([...seen]).toEqual(expect.arrayContaining(["thrown", "bumped", "bouncing", "landing", "idle"]));
    expect(body.happened.slice(0, 5)).toEqual(["woken", "held", "shaken", "thrown", "hit_edge"]);
    expect(body.happened).toContain("bounced");
    expect(body.happened[body.happened.length - 1]).toBe("landed");
    // However long the account grows, it keeps 16 stages and ends with the newest.
    body.hold();
    for (let i = 0; i < 20; i += 1) {
      body.shake(true);
      body.shake(false);
      body.release(0, 0);
    }
    run(body, 3);
    expect(body.happened).toHaveLength(16);
    expect(body.happened[body.happened.length - 1]).toBe("landed");
    // A new hold begins a new account.
    body.hold();
    expect(body.happened).toEqual(["held"]);
  });

  it("gets up from a landing before it is at rest for a plan, starts at a click, and sits while it sits still", () => {
    const body = new Body(AREA, 500, 500);
    body.letGo();
    while (body.motion.kind !== "rest") body.step(0.03);
    expect(body.gettingUp).toBe(true);
    expect(stateOf(body, "talking", false)).toBe("landing");
    run(body, 1.3);
    expect(body.gettingUp).toBe(false);
    expect(stateOf(body, null, false, true)).toBe("sitting");
    body.startle();
    expect(stateOf(body, null, false, true)).toBe("startled");
    run(body, 0.7);
    expect(stateOf(body, null, false)).toBe("idle");
  });
});

describe("a shake", () => {
  /** The hand's x at each 40 ms, from 0 ms. */
  const moves = (xs: number[]) => xs.map((x, i) => ({ x, y: 300, at: i * 40 }));

  it("is four turns to and fro of eight pixels or more within a second", () => {
    expect(shaking(moves([0, 20, 0, 20, 0, 20]), 200)).toBe(true);
    // Too small swings, or too few turns, are no shake.
    expect(shaking(moves([0, 5, 0, 5, 0, 5, 0]), 240)).toBe(false);
    expect(shaking(moves([0, 20, 0, 20, 0]), 160)).toBe(false);
    // A shake over a second ago is over.
    expect(shaking(moves([0, 20, 0, 20, 0, 20]), 1300)).toBe(false);
  });
});

describe("the companion's size", () => {
  it("makes the figure the share of the window's height asked, and keeps a body at an edge inside the window", () => {
    const before = { ...SIZE };
    try {
      sizeTo(21, 752);
      expect(SIZE.height * FILL).toBeCloseTo(0.21 * 752, 0);
      expect(SIZE.width / SIZE.height).toBeCloseTo(200 / 260, 2);
      const body = new Body(AREA, AREA.width - SIZE.width / 2, AREA.height);
      sizeTo(50, AREA.height);
      body.fit(AREA);
      expect(SIZE.height * FILL).toBeCloseTo(300, 0);
      expect(body.x).toBe(AREA.width - SIZE.width / 2);
      expect(body.y).toBe(AREA.height);
    } finally {
      Object.assign(SIZE, before);
    }
  });
});

describe("the compact chat beside the figure", () => {
  it("opens close at the figure's right where there is room, else close at its left, never across it", () => {
    const standing = SIZE.height * FILL;
    // At the right: nearer than the canvas's edge, as the figure is narrower than its canvas.
    const right = beside(300, 360, 1440);
    expect(right).toBeGreaterThan(300 + standing * 0.15);
    expect(right).toBeLessThan(300 + SIZE.width / 2);
    // At the left where the right has no room: the chat ends as near the figure.
    const left = beside(1200, 360, 1440);
    expect(1200 - (left + 360)).toBe(right - 300);
  });
});
