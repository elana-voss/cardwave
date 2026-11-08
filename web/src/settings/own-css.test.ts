// What own-css.ts decides of the user's own CSS without a browser: a reading of the settings begun before a save
// does not take the app back to the CSS before it. What the dialog does is the browser's (e2e/tests/71-own-css).
import { expect, test, vi } from "vitest";
import { getSettings } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { readOwnCss, showOwnCss } from "./own-css";

vi.mock("../api/client", () => ({ getSettings: vi.fn(), changeSettings: vi.fn() }));

test("a reading begun before the CSS was saved, which answers after, leaves the CSS saved", async () => {
  let answer: (settings: Settings) => void = () => {};
  vi.mocked(getSettings).mockReturnValue(new Promise((done) => (answer = done)));
  const reading = readOwnCss();
  showOwnCss(".new {}");
  answer({ own_css: ".old {}" } as Settings);
  await reading;
  expect(document.querySelector("#own-css")?.textContent).toBe(".new {}");
});
