import { afterEach, describe, expect, it, vi } from "vitest";
import { Clicks, Reactions } from "./react";

describe("the figure's reactions", () => {
  it("keep a handling that ends while another question is in flight, and ask it once that one has answered", async () => {
    const asked: string[] = [];
    let answer: () => void = () => {};
    const reactions = new Reactions(
      (occasion) => {
        asked.push(occasion);
        return new Promise<boolean>((done) => (answer = () => done(true)));
      },
      () => {},
      () => 1000,
    );
    reactions.took();
    reactions.standing(false, 0);
    reactions.took();
    reactions.standing(true, 0);
    expect(asked).toEqual(["handled"]);
    answer();
    await Promise.resolve();
    await Promise.resolve();
    reactions.standing(true, 0);
    expect(asked).toEqual(["handled", "handled"]);
  });

  it("left alone, ask again and again, each a while after the last moves ended, and walk of their own where the model gives nothing", async () => {
    const asked: string[] = [];
    let answer: (acted: boolean) => void = () => {};
    let model = true;
    const wander = vi.fn();
    const reactions = new Reactions(
      (occasion) => {
        if (!model) return null;
        asked.push(occasion);
        return new Promise<boolean>((done) => (answer = done));
      },
      wander,
      () => 1000,
    );
    const settle = async () => {
      await Promise.resolve();
      await Promise.resolve();
    };
    reactions.standing(true, 0);
    reactions.standing(true, 999);
    expect(asked).toEqual([]);
    reactions.standing(true, 1000);
    expect(asked).toEqual(["alone"]);
    answer(true);
    await settle();
    // Its moves run (not idle), and the next question waits a while after they end.
    reactions.standing(false, 1500);
    reactions.standing(true, 5000);
    reactions.standing(true, 5999);
    expect(asked).toEqual(["alone"]);
    reactions.standing(true, 6000);
    expect(asked).toEqual(["alone", "alone"]);
    // An answer without moves, or none to be had, is a walk of its own.
    answer(false);
    await settle();
    expect(wander).toHaveBeenCalledTimes(1);
    reactions.standing(false, 6100);
    model = false;
    reactions.standing(true, 7000);
    reactions.standing(true, 8000);
    expect(wander).toHaveBeenCalledTimes(2);
    // Used: being alone counts from then.
    reactions.used();
    model = true;
    reactions.standing(true, 8500);
    reactions.standing(true, 9000);
    expect(asked).toEqual(["alone", "alone"]);
  });

  it("do not walk of their own when the hand took the figure while a question about being alone was in flight", async () => {
    let answer: (acted: boolean) => void = () => {};
    const wander = vi.fn();
    const reactions = new Reactions(() => new Promise<boolean>((done) => (answer = done)), wander, () => 0);
    reactions.standing(true, 0);
    reactions.took();
    answer(false);
    await Promise.resolve();
    await Promise.resolve();
    expect(wander).not.toHaveBeenCalled();
  });
});

describe("a click on the figure", () => {
  afterEach(() => void vi.useRealTimers());

  it("startles it when no press follows, and not while a drag that followed it goes on", () => {
    vi.useFakeTimers();
    const startle = vi.fn();
    const clicks = new Clicks(startle, 300);
    clicks.up(false);
    vi.advanceTimersByTime(400);
    expect(startle).toHaveBeenCalledTimes(1);
    // A press within the double-click's time that becomes a drag, held longer than that.
    clicks.up(false);
    clicks.down();
    vi.advanceTimersByTime(400);
    clicks.up(true);
    expect(startle).toHaveBeenCalledTimes(1);
  });
});
