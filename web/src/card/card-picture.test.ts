// What card-picture.ts decides without a browser: what the picture's place says it does.
import { expect, test } from "vitest";
import type { Card } from "./card-page";
import { choosing, heroPicture, pictureMade } from "./card-picture";

test("on a touch screen the picture's place says tap, and nothing of a click or a drop", () => {
  expect(choosing(true)).toEqual({ label: "Character picture: tap to choose a picture", says: "Tap to choose a picture" });
  expect(choosing(false).says).toBe("Click to choose a picture, or drop one here");
});

test("the picture's Make a picture button, grey while the card is not made, opens to a click once the card is made", () => {
  const c = { id: null, node: document.createElement("div"), detail: null, pending: null } as unknown as Card;
  const hero = heroPicture(c);
  const buttons = () => [...hero.querySelectorAll<HTMLButtonElement>("button.rbtn, button.on-box")].filter((b) => b.textContent === "Make a picture");
  expect(buttons().length).toBe(2);
  expect(buttons().every((b) => b.disabled)).toBe(true);
  pictureMade(hero);
  expect(buttons().every((b) => !b.disabled && !b.title)).toBe(true);
});
