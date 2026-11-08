import { expect, test } from "vitest";
import { contentPills } from "./character";

test("a content level is said in words, another term as it is, nothing for none", () => {
  const pills = contentPills(["sfw", "slow-burn", "constructor"]);
  expect(pills && [...pills.children].map((pill) => pill.textContent)).toEqual(["For everyone", "slow-burn", "constructor"]);
  expect(contentPills([])).toBe(false);
});
