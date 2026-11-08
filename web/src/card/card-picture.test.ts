// What card-picture.ts decides without a browser: what the picture's place says it does.
import { expect, test } from "vitest";
import { choosing } from "./card-picture";

test("on a touch screen the picture's place says tap, and nothing of a click or a drop", () => {
  expect(choosing(true)).toEqual({ label: "Character picture: tap to choose a picture", says: "Tap to choose a picture" });
  expect(choosing(false).says).toBe("Click to choose a picture, or drop one here");
});
