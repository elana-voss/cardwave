// What card-page.ts decides alone: a redraw after a save leaves a text being written in the page.
import { expect, test, vi } from "vitest";
import { redrawIdle, type Card } from "./card-page";

test("a redraw after a save draws only the state while a text is being written, else the whole page", () => {
  const render = vi.fn();
  const drawState = vi.fn();
  const body = document.createElement("div");
  const c = { body, render, drawState } as unknown as Card;
  body.innerHTML = '<div class="in-place"></div>';
  redrawIdle(c);
  expect([render.mock.calls.length, drawState.mock.calls.length]).toEqual([0, 1]);
  body.replaceChildren();
  redrawIdle(c);
  expect([render.mock.calls.length, drawState.mock.calls.length]).toEqual([1, 1]);
});
