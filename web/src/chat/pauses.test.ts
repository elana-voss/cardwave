// Dictation's pauses: a recording cut where the speaker pauses, and silence not sent.
import { expect, test } from "vitest";
import { Pauses } from "./pauses";

const RATE = 1000;
/** `seconds` of sound as loud as `level`, in pieces of 50 ms as the page gets them. */
const sound = (level: number, seconds: number) =>
  Array.from({ length: Math.round(seconds * 20) }, () => new Float32Array(RATE / 20).fill(level));

test("speech followed by a pause is cut there, and what follows is the next piece", () => {
  const pauses = new Pauses(RATE);
  const cuts = [...sound(0.2, 1), ...sound(0, 0.6), ...sound(0.3, 0.5)].map((piece) => pauses.add(piece)).filter((cut) => cut);
  expect(cuts).toHaveLength(1);
  expect(cuts[0]?.length).toBe(1.6 * RATE);
  expect(pauses.rest()?.length).toBe(0.5 * RATE);
  expect(pauses.rest()).toBeNull();
});

test("a breath between words, softer speech and a voice that drops less than tenfold are no pause", () => {
  const pauses = new Pauses(RATE);
  const cuts = [...sound(0.2, 1), ...sound(0, 0.3), ...sound(0.05, 1), ...sound(0.03, 1)].map((piece) => pauses.add(piece));
  expect(cuts.every((cut) => cut === null)).toBe(true);
});

test("silence is never sent, but the moment before speech starts is kept", () => {
  const pauses = new Pauses(RATE);
  for (const piece of sound(0, 3)) expect(pauses.add(piece)).toBeNull();
  expect(pauses.rest()).toBeNull();
  for (const piece of [...sound(0, 3), ...sound(0.2, 1)]) pauses.add(piece);
  expect(pauses.rest()?.length).toBe(1.3 * RATE);
});

test("a stretch ten times softer than the voice heard before is the room, and is not sent", () => {
  const pauses = new Pauses(RATE);
  const cuts = [...sound(0.2, 1), ...sound(0, 0.6), ...sound(0.01, 1), ...sound(0, 0.6), ...sound(0.1, 1), ...sound(0, 0.6)].map((piece) => pauses.add(piece)).filter((cut) => cut);
  expect(cuts.map((cut) => cut?.length)).toEqual([1.6 * RATE, 1.6 * RATE]);
  for (const piece of sound(0.01, 1)) pauses.add(piece);
  expect(pauses.rest()).toBeNull();
});
