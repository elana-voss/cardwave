import { expect, test, vi } from "vitest";
import { followKeyboard } from "./keyboard";

test("a keyboard that pans the visual viewport, the page not scrolled, puts the page back at its top", () => {
  const seen = Object.assign(new EventTarget(), { height: 500, scale: 1, offsetTop: 0 });
  const scrollTo = vi.fn();
  const win = { visualViewport: seen, innerHeight: 844, scrollY: 0, scrollTo, document } as unknown as Window;
  followKeyboard(win);
  seen.offsetTop = 120;
  seen.dispatchEvent(new Event("scroll"));
  expect(document.documentElement.style.getPropertyValue("--page-height")).toBe("500px");
  expect(scrollTo).toHaveBeenCalledWith(0, 0);
});
