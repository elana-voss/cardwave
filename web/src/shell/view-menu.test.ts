// What the view menu decides, without a browser: its groups for a page of several views and of one, and what
// choosing a view, a theme or Compact does to the page and to the menu.
import { beforeEach, expect, test } from "vitest";
import type { View } from "../dom";
import { viewButton } from "./view-menu";

beforeEach(() => {
  localStorage.clear();
  delete document.documentElement.dataset.theme;
  delete document.documentElement.dataset.density;
  document.body.replaceChildren();
});

/** A page of the views List, Gallery and Discovery, List in use; `chosen` holds what was chosen. */
function library(chosen: string[]): View {
  let now = "list";
  return {
    node: document.createElement("div"),
    views: {
      list: [
        ["list", "List"],
        ["gallery", "Gallery"],
        ["discovery", "Discovery"],
      ],
      now: () => now,
      choose: (name) => {
        now = name;
        chosen.push(name);
      },
    },
  };
}

/** The button made for `page`, put in the page and opened; its menu's lines as words or "—" for a rule, and the ticked ones. */
function opened(page: View | null) {
  const node = viewButton("btn", () => page);
  document.body.append(node);
  const button = node.firstElementChild as HTMLButtonElement;
  button.click();
  const menu = node.querySelector<HTMLElement>("[role=menu]")!;
  const lines = () => [...menu.children].map((one) => (one.tagName === "HR" ? "—" : one.textContent));
  const ticked = () => [...menu.querySelectorAll("button")].filter((one) => one.ariaChecked === "true").map((one) => one.textContent);
  const line = (words: string) => [...menu.querySelectorAll<HTMLButtonElement>("button")].find((one) => one.textContent === words)!;
  return { button, menu, lines, ticked, line };
}

test("a page of several views: its views, a rule, the themes, a rule and Compact; the ones in use ticked", () => {
  const { button, menu, lines, ticked } = opened(library([]));
  expect(button.title).toBe("View");
  expect(menu.hidden).toBe(false);
  expect(lines()).toEqual(["List", "Gallery", "Discovery", "—", "System", "Light", "Dark", "Downtempo", "Outrun", "Retrowave", "Neon Wave dark", "Neon Wave light", "—", "Compact"]);
  expect(ticked()).toEqual(["List", "System"]);
});

test("a page of one view leaves out the views and their rule", () => {
  const { lines } = opened({ node: document.createElement("div") });
  expect(lines()).toEqual(["System", "Light", "Dark", "Downtempo", "Outrun", "Retrowave", "Neon Wave dark", "Neon Wave light", "—", "Compact"]);
});

test("a view chosen is the page's at once and closes the menu", () => {
  const chosen: string[] = [];
  const { menu, line, button, ticked } = opened(library(chosen));
  line("Gallery").click();
  expect(chosen).toEqual(["gallery"]);
  expect(menu.hidden).toBe(true);
  button.click();
  expect(ticked()).toEqual(["Gallery", "System"]);
});

test("a theme chosen is set at once and closes the menu", () => {
  const { menu, line } = opened(null);
  line("Dark").click();
  expect(document.documentElement.dataset.theme).toBe("dark");
  expect(menu.hidden).toBe(true);
});

test("Compact is ticked and unticked, set at once, and the menu stays", () => {
  const { menu, line, ticked } = opened(null);
  line("Compact").click();
  expect(document.documentElement.dataset.density).toBe("compact");
  expect(menu.hidden).toBe(false);
  expect(ticked()).toEqual(["System", "Compact"]);
  line("Compact").click();
  expect(document.documentElement.dataset.density).toBeUndefined();
  expect(ticked()).toEqual(["System"]);
});
