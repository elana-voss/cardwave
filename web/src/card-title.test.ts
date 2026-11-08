import { expect, test } from "vitest";
import { cardTitle } from "./card-title";

test("a card that names nothing is worded by the page", () => {
  expect(cardTitle("")).toBe("Untitled");
  expect(cardTitle("Mira")).toBe("Mira");
});
