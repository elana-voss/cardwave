import { afterEach, describe, expect, it, vi } from "vitest";
import type { Clip } from "../api/generated/Clip";
import type { Feeling } from "../api/generated/Feeling";
import type { Move } from "../api/generated/Move";
import { Body, SIZE, stateOf } from "./body";
import { Companion, reporter, type Shown } from "./live";

const AREA = { width: 1000, height: 600 };

/** A figure that keeps what it was told: the clips played, its turn and its feeling. */
class Fake implements Shown {
  played: [Clip, number | undefined][] = [];
  turned: [number, number] = [0, 0];
  feeling: Feeling | null = null;
  clip: string | null = "idle";
  play(clip: Clip, ms?: number): number {
    this.played.push([clip, ms]);
    this.clip = clip;
    return ms ?? 1000;
  }
  look(yaw: number, pitch: number): void {
    this.turned = [yaw, pitch];
  }
  feel(feeling: Feeling | null): void {
    this.feeling = feeling;
  }
}

/** A companion standing at x 500, told `steps`. */
function told(steps: Move[], act?: number) {
  const body = new Body(AREA, 500, AREA.height);
  const figure = new Fake();
  const live = new Companion(body, figure);
  live.act(steps, act);
  const run = (seconds: number) => {
    for (let t = 0; t < seconds; t += 0.03) {
      live.step(0.03, false);
      body.step(0.03);
    }
  };
  const state = () => live.state(stateOf(body, null, false), false, AREA.width, AREA.height);
  return { body, figure, live, run, state };
}

describe("the companion told to move", () => {
  it("walks, and says what is left of its steps until it is there", () => {
    const { run, state } = told([{ do: "walk", x: 300 }]);
    run(0.1);
    expect(state()).toMatchObject({ state: "walking", steps: [{ do: "walk", x: 300 }] });
    run(3);
    expect(state()).toMatchObject({ x: 300, y: AREA.height, state: "idle", steps: [] });
  });

  it("climbs an edge, and lets go of it", () => {
    const { live, run, state } = told([{ do: "climb", side: "left", height: 0.5 }, { do: "wait", ms: 60_000 }]);
    run(15);
    expect(state()).toMatchObject({ x: SIZE.width / 2, steps: [{ do: "wait", ms: 60_000 }] });
    expect(state().y).toBeLessThan(AREA.height);
    live.act([{ do: "let_go" }]);
    run(4);
    expect(state()).toMatchObject({ y: AREA.height, steps: [] });
  });
});

describe("the companion told to play a clip", () => {
  it("plays it for the time asked, and says which", () => {
    const { figure, run, state } = told([{ do: "play", clip: "wave", ms: 2000 }]);
    run(0.1);
    expect(figure.played).toEqual([["wave", 2000]]);
    expect(state()).toMatchObject({ clip: "wave", steps: [{ do: "play", clip: "wave", ms: 2000 }] });
    run(2);
    expect(state().steps).toEqual([]);
  });
});

describe("the companion told to look", () => {
  it("turns to the point, up and to the left, for a time, then at the user again", () => {
    const { figure, run, state } = told([{ do: "look", x: 100, y: 50 }]);
    run(0.1);
    expect(state().looking).toEqual({ x: 100, y: 50 });
    expect(figure.turned[0]).toBeLessThan(0);
    expect(figure.turned[1]).toBeLessThan(0);
    run(5);
    expect(state().looking).toBeNull();
    expect(figure.turned).toEqual([0, 0]);
  });

  it("looks level with its face where told only how far along", () => {
    const { figure, run, state } = told([{ do: "look", x: 900 }]);
    run(0.1);
    expect(state().looking).toEqual({ x: 900, y: AREA.height - SIZE.height * 0.55 });
    expect(figure.turned[0]).toBeGreaterThan(0);
    expect(figure.turned[1]).toBeCloseTo(0);
  });
});

describe("the companion told to react", () => {
  it("shows the feeling on its face and plays its clip, for a time", () => {
    const { figure, run, state } = told([{ do: "react", feeling: "happy" }]);
    run(0.1);
    expect(figure.played).toEqual([["jump", undefined]]);
    expect(figure.feeling).toBe("happy");
    expect(state().feeling).toBe("happy");
    run(3);
    expect(figure.feeling).toBeNull();
    expect(state()).toMatchObject({ feeling: null, steps: [] });
  });
});

describe("the companion told to say a message", () => {
  it("says it for a time by its length", () => {
    const { live, run, state } = told([{ do: "say", text: "Hello there" }]);
    run(0.1);
    expect(live.said).toBe("Hello there");
    expect(state()).toMatchObject({ saying: "Hello there", steps: [{ do: "say", text: "Hello there" }] });
    run(2.5);
    expect(state()).toMatchObject({ saying: null, steps: [] });
  });

  it("says nothing for a message of only spaces", () => {
    const { live, run } = told([{ do: "say", text: "   " }]);
    run(0.1);
    expect(live.said).toBe(null);
  });
});

describe("the companion's acts", () => {
  it("say the server's act it began, and the hand ends what it was told", () => {
    const { live, state } = told([{ do: "wait", ms: 5000 }], 7);
    expect(state().acted).toBe(7);
    // The first step begins when told, so the state told the server at once says it.
    live.act([{ do: "react", feeling: "happy" }]);
    expect(state().feeling).toBe("happy");
    live.act([{ do: "walk", x: 10 }]);
    expect(state().acted).toBe(7);
    live.stop();
    expect(live.busy).toBe(false);
    expect(state().steps).toEqual([]);
  });
});

describe("telling the server what the figure does", () => {
  afterEach(() => void vi.useRealTimers());

  it("tells at once when asked, else at most each half second while it changes, and every five seconds while not", () => {
    vi.useFakeTimers();
    const send = vi.fn(() => Promise.resolve());
    const report = reporter(send);
    const { state, run } = told([{ do: "walk", x: 100 }]);
    report(state);
    run(0.1);
    report(state);
    expect(send).toHaveBeenCalledTimes(1);
    report(state, true);
    expect(send).toHaveBeenCalledTimes(2);
    vi.advanceTimersByTime(600);
    run(0.1);
    report(state);
    expect(send).toHaveBeenCalledTimes(3);
    vi.advanceTimersByTime(600);
    report(state);
    expect(send).toHaveBeenCalledTimes(3);
    vi.advanceTimersByTime(5000);
    report(state);
    expect(send).toHaveBeenCalledTimes(4);
  });
});
