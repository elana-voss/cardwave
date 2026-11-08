import { describe, expect, it } from "vitest";
import { SAMPLING, valueOf } from "./advanced";

const of = (key: string) => SAMPLING.find((value) => value.key === key)!;

describe("the page Advanced", () => {
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
