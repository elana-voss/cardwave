// What the view menu decides, without a browser: its lines for a page of several views and of one, what choosing a
// view, a theme, Compact spacing or a set of message colours does to the page and to the menus, the side menus' keys,
// and at 600 px the side menu in the menu's place.
import { afterEach, beforeEach, expect, test } from "vitest";
import { SMALL, type View } from "../dom";
import { showTextSet } from "../theme";
import { viewButton } from "./view-menu";

beforeEach(() => {
  localStorage.clear();
  delete document.documentElement.dataset.theme;
  delete document.documentElement.dataset.density;
  document.body.replaceChildren();
});

afterEach(() => {
  delete (SMALL as { matches?: boolean }).matches;
});

/** A page of the views List, Gallery and Discovery, List in use; `chosen` holds what was chosen. */
function library(chosen: string[]): View {
  let now = "list";
  return {
    node: document.createElement("div"),
    views: {
      heading: () => "Characters page",
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

const key = (at: Element, name: string) => at.dispatchEvent(new KeyboardEvent("keydown", { key: name, bubbles: true }));

/** The button made for `page`, put in the page and opened; a menu's lines as words or "—" for a rule, and the ticked ones. */
function opened(page: View | null) {
  const node = viewButton("btn", () => page);
  document.body.append(node);
  const button = node.firstElementChild as HTMLButtonElement;
  button.click();
  const [menu, side] = node.querySelectorAll<HTMLElement>("[role=menu]");
  const lines = (of = menu) => [...of.children].map((one) => (one.tagName === "HR" ? "—" : one.textContent));
  const ticked = (of = menu) => [...of.querySelectorAll("button")].filter((one) => one.ariaChecked === "true").map((one) => one.textContent);
  const line = (words: string, of = menu) => [...of.querySelectorAll<HTMLButtonElement>("button")].find((one) => one.textContent!.startsWith(words))!;
  const shown = () => !menu.hidden && !menu.parentElement!.hidden;
  return { button, menu, side, lines, ticked, line, shown };
}

test("a page of several views: its name, its views, a rule, App theme and Compact spacing, a rule and the message colours", () => {
  const { button, lines, ticked, side } = opened(library([]));
  expect(button.title).toBe("View");
  expect(lines()).toEqual(["Characters page", "List", "Gallery", "Discovery", "—", "App themeSystem", "Compact spacing", "—", "Chat message coloursOff"]);
  expect(ticked()).toEqual(["List"]);
  expect(side.hidden).toBe(true);
});

test("a page of one view leaves out its name, the views and their rule", () => {
  const { lines } = opened({ node: document.createElement("div") });
  expect(lines()).toEqual(["App themeSystem", "Compact spacing", "—", "Chat message coloursOff"]);
});

test("a view chosen is the page's at once and closes the menu", () => {
  const chosen: string[] = [];
  const { line, button, ticked, shown } = opened(library(chosen));
  line("Gallery").click();
  expect(chosen).toEqual(["gallery"]);
  expect(shown()).toBe(false);
  button.click();
  expect(ticked()).toEqual(["Gallery"]);
});

test("App theme opens the eight themes beside the menu; one picked is set at once and both menus stay", () => {
  const { line, side, lines, ticked, shown } = opened(null);
  line("App theme").click();
  expect(side.hidden).toBe(false);
  expect(line("App theme").ariaExpanded).toBe("true");
  expect(lines(side)).toEqual(["System", "Light", "Dark", "Downtempo", "Outrun", "Retrowave", "Neon Wave dark", "Neon Wave light"]);
  expect(document.activeElement).toBe(line("System", side));
  line("Dark", side).click();
  expect(document.documentElement.dataset.theme).toBe("dark");
  expect(shown()).toBe(true);
  expect(side.hidden).toBe(false);
  expect(ticked(side)).toEqual(["Dark"]);
  expect(line("App theme").textContent).toBe("App themeDark");
  expect(document.activeElement).toBe(line("Dark", side));
});

test("keys: → opens a side menu, ↓ moves in it, ← returns to its line, Escape there and a second Escape closes all", () => {
  const { button, line, side, shown } = opened(null);
  line("Chat message colours").focus();
  key(line("Chat message colours"), "ArrowRight");
  expect(side.hidden).toBe(false);
  expect(document.activeElement).toBe(line("Off", side));
  key(document.activeElement!, "ArrowDown");
  expect(document.activeElement).toBe(line("Light", side));
  key(document.activeElement!, "ArrowLeft");
  expect(side.hidden).toBe(true);
  expect(document.activeElement).toBe(line("Chat message colours"));
  key(line("Chat message colours"), "Enter");
  key(document.activeElement!, "Escape");
  expect(side.hidden).toBe(true);
  expect(shown()).toBe(true);
  key(document.activeElement!, "Escape");
  expect(shown()).toBe(false);
  expect(document.activeElement).toBe(button);
});

test("a set of message colours picked is kept and shown on a chat's root while it applies; Off shows none", () => {
  const chat = document.createElement("div");
  const other = document.createElement("div");
  let character = true;
  const followed = showTextSet(chat, () => character);
  showTextSet(other, () => false);
  const { line, side, lines } = opened(null);
  line("Chat message colours").click();
  expect(lines(side)).toEqual(["OffThe theme's own colours", "LightFor light themes", "DarkFor dark themes"]);
  line("Light", side).click();
  expect(chat.dataset.textSet).toBe("light");
  expect(other.dataset.textSet).toBeUndefined();
  expect(line("Chat message colours").textContent).toBe("Chat message coloursLight");
  character = false;
  followed.show();
  expect(chat.dataset.textSet).toBeUndefined();
  character = true;
  line("Off", side).click();
  expect(chat.dataset.textSet).toBeUndefined();
  line("Dark", side).click();
  followed.stop();
  line("Light", side).click();
  expect(chat.dataset.textSet).toBe("dark");
});

test("Compact spacing turns with its switch, set at once, and the menu stays", () => {
  const { line, shown } = opened(null);
  line("Compact spacing").click();
  expect(document.documentElement.dataset.density).toBe("compact");
  expect(shown()).toBe(true);
  expect(line("Compact spacing").ariaChecked).toBe("true");
  line("Compact spacing").click();
  expect(document.documentElement.dataset.density).toBeUndefined();
  expect(line("Compact spacing").ariaChecked).toBe("false");
});

test("at 600 px the side menu takes the menu's place, its back line first, which returns to the menu", () => {
  Object.defineProperty(SMALL, "matches", { value: true, configurable: true });
  const { line, menu, side, lines } = opened(null);
  line("App theme").click();
  expect(menu.hidden).toBe(true);
  expect(side.classList.contains("vm-narrow")).toBe(true);
  expect(lines(side).slice(0, 3)).toEqual(["App theme", "—", "System"]);
  expect(document.activeElement).toBe(side.querySelector(".vm-back"));
  (side.querySelector(".vm-back") as HTMLButtonElement).click();
  expect(menu.hidden).toBe(false);
  expect(side.hidden).toBe(true);
  expect(document.activeElement).toBe(line("App theme"));
});
