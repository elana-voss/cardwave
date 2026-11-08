import { describe, expect, it } from "vitest";
import type { Poster } from "../api/generated/Poster";
import { DESIGNS, designOf } from "./poster-designs";

const card = (parts: Partial<Poster>): Poster => ({ tagline: "A line", mood: "drama", design: "b", faces: [], ...parts });

describe("a card's design", () => {
  it("is its mood's with its stored letter", () => {
    expect(designOf(card({}))).toBe("drama-b");
    expect(Object.keys(DESIGNS)).toHaveLength(14);
  });

  it("is none, for the plain tile, without a tagline, a mood or a letter", () => {
    expect(designOf(card({ tagline: "" }))).toBeNull();
    expect(designOf(card({ mood: null }))).toBeNull();
    expect(designOf(card({ design: null }))).toBeNull();
  });
});
