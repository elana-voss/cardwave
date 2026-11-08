// What windowed.ts decides, without a browser: which rows are drawn, and that a long list is in the page only in part,
// each item with its place in the whole, the one kept that stays near the view, the row beyond drawn for Tab; the scroll
// kept when drawn anew or resized, the empty line kept, a taller window drawing more. The page has no layout here, so a
// row's height and place (50 px, one item a row), the clamped scroll and the ResizeObserver are stood in for.
import { afterEach, expect, test, vi } from "vitest";
import { el } from "./dom";
import { rowsSeen, windowed } from "./windowed";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  document.body.replaceChildren();
});

const frame = () =>
  new Promise((done) => requestAnimationFrame(() => setTimeout(done)));

/** A scroller 500 px tall over a windowed list of 50 px rows, which scrolls and clamps as a browser does, and its
 * ResizeObserver's callback (`resize`). */
function scrolling() {
  let resize = () => {};
  vi.stubGlobal(
    "ResizeObserver",
    class {
      constructor(callback: () => void) {
        resize = callback;
      }
      observe() {}
    },
  );
  const scroller = el("div");
  const list = el("ul");
  scroller.append(list);
  document.body.append(scroller);
  const height = { now: 500 };
  vi.spyOn(scroller, "clientHeight", "get").mockImplementation(
    () => height.now,
  );
  // The scroll position, cut down to what the list's height allows whenever the page is laid out (it is read).
  let top = 0;
  const clamp = () => {
    const tall =
      (parseFloat(list.style.paddingTop) || 0) +
      (parseFloat(list.style.paddingBottom) || 0) +
      list.children.length * 50;
    top = Math.max(0, Math.min(top, tall - height.now));
    return top;
  };
  vi.spyOn(scroller, "scrollTop", "get").mockImplementation(clamp);
  vi.spyOn(scroller, "scrollTop", "set").mockImplementation((value: number) => {
    top = value;
  });
  vi.spyOn(HTMLElement.prototype, "offsetHeight", "get").mockImplementation(
    function (this: HTMLElement) {
      return this.tagName === "LI" ? 50 : 0;
    },
  );
  vi.spyOn(HTMLElement.prototype, "offsetTop", "get").mockImplementation(
    function (this: HTMLElement) {
      clamp();
      return (Number(this.getAttribute("aria-posinset") ?? 1) - 1) * 50;
    },
  );
  vi.spyOn(list, "getBoundingClientRect").mockImplementation(
    () => ({ top: -clamp() }) as DOMRect,
  );
  const view = windowed<string>(list, scroller);
  return { list, scroller, view, height, resize: () => resize() };
}

const cards = Array.from({ length: 5000 }, (_, n) => `Card ${n + 1}`);
const card = (name: string) => el("li", null, name);

test("the rows drawn are those in view and a few around, the first of them at an even place", () => {
  const heights = new Array(100).fill(50);
  expect(rowsSeen(heights, 0, 500, 6)).toEqual([0, 16]);
  expect(rowsSeen(heights, 1000, 1500, 6)).toEqual([14, 36]);
  expect(rowsSeen(heights, 4800, 5300, 6)).toEqual([90, 100]);
});

test("a list of 5,000 is drawn only around the view, says each item's place, pads for the rest and keeps an item drawn while it stays near", async () => {
  const at = (node: HTMLElement) =>
    Number(node.getAttribute("aria-posinset") ?? 1) - 1;
  vi.spyOn(HTMLElement.prototype, "offsetHeight", "get").mockImplementation(
    function (this: HTMLElement) {
      return this.tagName === "LI" ? 50 : 0;
    },
  );
  vi.spyOn(HTMLElement.prototype, "offsetTop", "get").mockImplementation(
    function (this: HTMLElement) {
      return at(this) * 50;
    },
  );
  const scroller = el("div");
  vi.spyOn(scroller, "clientHeight", "get").mockReturnValue(500);
  const list = el("ul");
  scroller.append(list);
  document.body.append(scroller);
  const items = Array.from({ length: 5000 }, (_, n) => `Card ${n + 1}`);
  const view = windowed<string>(list, scroller);
  view.draw(items, (name) => el("li", null, name));

  expect(list.children.length).toBe(16);
  expect(list.children[3].getAttribute("aria-posinset")).toBe("4");
  expect(list.children[3].getAttribute("aria-setsize")).toBe("5000");
  expect(list.style.paddingBottom).toBe(`${(5000 - 16) * 50}px`);

  // Scrolled 20 rows down: rows 14 to 36 are drawn; the 15th item is the same element as before.
  const fifteenth = list.children[14];
  vi.spyOn(list, "getBoundingClientRect").mockReturnValue({
    top: -1000,
  } as DOMRect);
  scroller.dispatchEvent(new Event("scroll"));
  await new Promise((done) => requestAnimationFrame(() => setTimeout(done)));
  expect(list.firstElementChild?.textContent).toBe("Card 15");
  expect(list.children.length).toBe(22);
  expect(list.firstElementChild).toBe(fifteenth);
  expect(list.style.paddingTop).toBe(`${14 * 50}px`);

  // Tab from the last item drawn draws the row beyond it first, for the focus to go on to.
  const last = list.lastElementChild as HTMLElement;
  last.dispatchEvent(
    new KeyboardEvent("keydown", { key: "Tab", bubbles: true }),
  );
  expect(list.lastElementChild?.textContent).toBe("Card 37");
  expect(list.lastElementChild?.previousElementSibling).toBe(last);
});

test("a list drawn anew, or in a wider or narrower window, stays where it was scrolled", () => {
  const { list, scroller, view, resize } = scrolling();
  view.draw(cards, card);
  scroller.scrollTop = 2000;
  view.draw(cards, card);
  expect(scroller.scrollTop).toBe(2000);
  expect(list.firstElementChild?.textContent).toBe("Card 35");
  resize();
  expect(scroller.scrollTop).toBe(2000);
  expect(list.firstElementChild?.textContent).toBe("Card 35");
});

test("an empty list keeps its empty line when the window is resized", () => {
  const { list, view, resize } = scrolling();
  view.draw([], card);
  list.append(el("li", null, "No cards"));
  resize();
  expect(list.textContent).toBe("No cards");
});

test("a taller window draws more rows", async () => {
  const { list, view, height, resize } = scrolling();
  view.draw(cards, card);
  resize();
  expect(list.children.length).toBe(16);
  height.now = 1000;
  resize();
  await frame();
  expect(list.children.length).toBe(26);
});
