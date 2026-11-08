import { expect, test } from "vitest";
import { wording } from "../language/language";
import { readBackList } from "./readback";

test("a line says what the user said, or that it is the AI's own guess where the server says so", () => {
  const line = (words: string) => ({ sentence: "You want calm", words, gap: false });
  const back = { lines: [line("quiet evenings"), line("calm")], questions: [0, null], guesses: [false, true] };
  const list = readBackList({ back, verdicts: [null, null], changed: () => {}, notIt: () => {} });
  const said = [...list.querySelectorAll(".rb-said")].map((node) => node.textContent);
  expect(said).toEqual([wording("interview-you-said", { words: "quiet evenings" }), wording("interview-own-guess")]);
});
