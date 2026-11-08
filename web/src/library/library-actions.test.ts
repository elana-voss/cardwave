// Tested here: a card's picture in a list line stands as a plain grey box where the card has no art (`cover`).
import { expect, test } from "vitest";
import { el } from "../dom";
import { cover } from "./library-actions";

test("a card without a picture shows a plain box in its list line, the size of a picture, not an empty gap", () => {
  const line = el("li");
  const shown = cover(7, "cover-sm");
  line.append(shown);
  shown.dispatchEvent(new Event("error"));
  expect(line.firstElementChild?.tagName).toBe("SPAN");
  expect(line.firstElementChild?.className).toBe("cover cover-sm cover-blank");
});
