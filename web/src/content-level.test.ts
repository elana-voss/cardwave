import { expect, test } from "vitest";
import { tagWord } from "./content-level";

test("a content level among a card's tags is said in words, another tag as it is", () => {
  expect(["sfw", "nsfw-extreme", "stoic"].map(tagWord)).toEqual(["For everyone", "For adults, extreme", "stoic"]);
});
