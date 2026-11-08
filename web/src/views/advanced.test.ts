import { describe, expect, it } from "vitest";
import { describeCost, describingSays, SAMPLING, valueOf } from "./advanced";

const of = (key: string) => SAMPLING.find((value) => value.key === key)!;

describe("the page Advanced", () => {
  it("says that describing all again was stopped part way, not that every character is described", () => {
    const again = { characters: 4, waiting: 0, done: 2, failed: 0, failure: null, stopped: true };
    expect(describingSays({ waiting: 0, left: 0, failed: 0, failure: null }, again)).toBe("Stopped at 2 of 4 described again");
    // A full run that a character came after, or describing the cards running, is not told as stopped.
    expect(describingSays({ waiting: 0, left: 1, failed: 0, failure: null }, { ...again, stopped: false })).not.toContain("Stopped");
    expect(describingSays({ waiting: 3, left: 3, failed: 0, failure: null }, again)).not.toContain("Stopped");
  });

  it("says what describing the characters not yet described costs, and nothing while it runs or with none left", () => {
    expect(describeCost({ waiting: 0, left: 503, failed: 0, failure: null })).toBe("About 5,533,000 to 6,036,000 tokens for 503 characters");
    expect(describeCost({ waiting: 3, left: 3, failed: 0, failure: null })).toBe("");
    expect(describeCost({ waiting: 0, left: 0, failed: 0, failure: null })).toBe("");
  });

  it("keeps a value as typed only where it is a number in its range", () => {
    expect(valueOf("0.7", of("temperature"))).toBe(0.7);
    expect(valueOf(" 0,7 ", of("temperature"))).toBe(0.7);
    expect(valueOf("", of("temperature"))).toBeNull();
    expect(valueOf("2.5", of("temperature"))).toBeUndefined();
    expect(valueOf("abc", of("top_p"))).toBeUndefined();
    expect(valueOf("−1.5", of("presence_penalty"))).toBe(-1.5);
    expect(valueOf("3.5", of("seed"))).toBeUndefined();
    expect(valueOf("256", of("context_size"))).toBeUndefined();
    expect(valueOf("8192", of("context_size"))).toBe(8192);
  });
});
