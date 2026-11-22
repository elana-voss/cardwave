import { describe, expect, it } from "vitest";
import { Lips, PACE } from "./lips";

/** How open the mouth is at each letter's time of `text`, played from the start. */
function played(text: string, letters = [...text].length + 2): number[] {
  const lips = new Lips();
  lips.hear(text);
  const shapes = [lips.step(0)];
  for (let at = 1; at < letters; at++) shapes.push(lips.step(1 / PACE));
  return shapes;
}

describe("the mouth in a rhythm from letters, without a voice", () => {
  it("opens wide on a, less on o and e, little on i and u, shuts on m, b and p, rests between words, then rests", () => {
    expect(played("ao eiu mbp")).toEqual([1, 0.8, 0, 0.6, 0.4, 0.4, 0, 0, 0, 0, 0, 0]);
    expect(played("Ká")).toEqual([0.2, 1, 0, 0]);
  });

  it("pauses longer at a sentence's end than at a comma, and gives no time to marks between", () => {
    expect(played("a, a. a*", 12)).toEqual([1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0]);
  });

  it("opens and half-shuts in turn on letters of a script it has no vowels for", () => {
    expect(played("你好吗")).toEqual([0.7, 0.2, 0.7, 0, 0]);
  });

  it("plays letters as they arrive, at its pace, from the first after a rest", () => {
    const lips = new Lips();
    expect(lips.step(1)).toBe(0);
    lips.hear("a");
    expect(lips.step(0.5 / PACE)).toBe(1);
    lips.hear("m");
    expect(lips.step(0.6 / PACE)).toBe(0);
    expect(lips.step(1 / PACE)).toBe(0);
    lips.hear("o");
    expect(lips.step(0)).toBe(0.8);
  });

  it("rests at once when told, and plays a whole text said anew from its start", () => {
    const lips = new Lips();
    lips.hear("aaaa");
    lips.rest();
    expect(lips.step(0)).toBe(0);
    lips.hear("aaaa");
    lips.say("e");
    expect(played("e")[0]).toBe(lips.step(0));
    expect(lips.step(1 / PACE)).toBe(0);
  });
});
