import { describe, expect, it } from "vitest";
import { Body, SIZE } from "./body";
import { Plan, wander, type Actor } from "./plan";

const AREA = { width: 1000, height: 600 };

/** Runs the plan in 30 ms ticks for `seconds`, the body with it; answers the clips played, each a second long. */
function run(plan: Plan, body: Body, seconds: number, still = false): string[] {
  const played: string[] = [];
  const actor: Actor = {
    play: (clip) => played.push(clip) && 1000,
    look: () => {},
    react: () => 1000,
    say: () => 1000,
  };
  for (let t = 0; t < seconds; t += 0.03) {
    plan.step(0.03, body, still, actor);
    body.step(0.03);
  }
  return played;
}

describe("a plan of the animator's", () => {
  it("runs its moves one after the other: a walk to its end, a clip for as long as it plays, a wait", () => {
    const body = new Body(AREA, 500, AREA.height);
    const plan = new Plan([
      { do: "walk", x: 350 },
      { do: "play", clip: "wave" },
      { do: "wait", ms: 1000 },
      { do: "climb", side: "left", height: 0.4 },
      { do: "let_go" },
    ]);
    expect(run(plan, body, 0.9)).toEqual([]);
    expect(body.motion.kind).toBe("walk");
    expect(run(plan, body, 0.3)).toEqual(["wave"]);
    expect(body.x).toBe(350);
    run(plan, body, 1.5);
    // Still waiting: no climb yet.
    expect(body.motion.kind).toBe("rest");
    expect(plan.done).toBe(false);
    run(plan, body, 12);
    expect(plan.done).toBe(true);
    expect(body.motion.kind).toBe("rest");
    expect(body.x).toBe(SIZE.width / 2);
  });

  it("leaves out walking and climbing while the figure sits still, and plays the rest", () => {
    const body = new Body(AREA, 500, AREA.height);
    const plan = new Plan([{ do: "walk", x: 100 }, { do: "climb", side: "right", height: 1 }, { do: "play", clip: "nod" }]);
    expect(run(plan, body, 2, true)).toEqual(["nod"]);
    expect(body.x).toBe(500);
    expect(plan.done).toBe(true);
  });
});

describe("a plan and the hand", () => {
  it("waits while the figure is in the air, walks from an edge only once it has let go and landed, and never ends hanging", () => {
    const body = new Body(AREA, 500, 200);
    body.hold();
    body.release(0, 0);
    const plan = new Plan([{ do: "walk", x: 300 }, { do: "climb", side: "right", height: 0.5 }]);
    run(plan, body, 0.2);
    // Still falling, and not walking yet.
    expect(body.motion.kind).toBe("air");
    run(plan, body, 25);
    expect(plan.done).toBe(true);
    // It climbed, and the plan's end let go of the edge.
    expect(body.motion.kind).toBe("rest");
    expect(body.x).toBe(AREA.width - SIZE.width / 2);
    expect(body.y).toBe(AREA.height);

    body.climb("left", 0.5);
    for (let t = 0; t < 15; t += 0.03) body.step(0.03);
    expect(body.motion.kind).toBe("hang");
    const walk = new Plan([{ do: "walk", x: 600 }]);
    run(walk, body, 0.1);
    expect(body.motion.kind).toBe("air");
    run(walk, body, 10);
    expect(walk.done).toBe(true);
    expect([body.x, body.y]).toEqual([600, AREA.height]);
  });
});

describe("a plan that replaces a climb still on the floor", () => {
  it("walks on at once, with no fall or landing", () => {
    const body = new Body(AREA, 500, AREA.height);
    body.climb("left", 0.5);
    body.step(0.1);
    expect(body.motion.kind).toBe("climb");
    const walk = new Plan([{ do: "walk", x: 700 }]);
    run(walk, body, 0.1);
    expect(body.motion.kind).toBe("walk");
    expect(body.gettingUp).toBe(false);
    expect(body.happened).not.toContain("landed");
  });
});

describe("wandering", () => {
  it("is a walk along the floor, or now and then a climb that lets go again", () => {
    expect(wander(AREA, () => 0.5)).toEqual([{ do: "walk", x: 500 }]);
    const climb = wander(AREA, () => 0.1);
    expect(climb.map((move) => move.do)).toEqual(["climb", "wait", "let_go"]);
  });
});

describe("a plan given while the figure gets up from a landing", () => {
  it("waits until it has got up", () => {
    const body = new Body(AREA, 500, 400);
    body.letGo();
    while (body.motion.kind !== "rest") body.step(0.03);
    const plan = new Plan([{ do: "walk", x: 100 }]);
    run(plan, body, 0.6);
    expect(body.x).toBe(500);
    run(plan, body, 1);
    expect(body.x).toBeLessThan(500);
  });
});
