// What theme.ts decides: which theme and which layout of a chat count, and what choosing one sets.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { beforeEach, expect, test } from "vitest";
import { chatLayouts, chatLayout, compact, setChatLayout, setCompact, setTheme, showChatLayout, theme, themes } from "./theme";

beforeEach(() => {
  localStorage.clear();
  delete document.documentElement.dataset.theme;
  delete document.documentElement.dataset.chat;
  delete document.documentElement.dataset.density;
});

test("the theme is the system's while none was chosen, and when what is kept is no theme", () => {
  expect(theme()).toBe("system");
  localStorage.setItem("theme", "sepia");
  expect(theme()).toBe("system");
});

test("a theme chosen is set on the root at once and kept for the next start", () => {
  setTheme("dark");
  expect(document.documentElement.dataset.theme).toBe("dark");
  expect(localStorage.getItem("theme")).toBe("dark");
  expect(theme()).toBe("dark");
  setTheme("light");
  expect(document.documentElement.dataset.theme).toBe("light");
  expect(theme()).toBe("light");
  setTheme("neonwave-light");
  expect(document.documentElement.dataset.theme).toBe("neonwave-light");
  expect(theme()).toBe("neonwave-light");
});

test("the system's theme takes the root's own away, and is kept as a choice too", () => {
  setTheme("dark");
  setTheme("system");
  expect(document.documentElement.dataset.theme).toBeUndefined();
  expect(localStorage.getItem("theme")).toBe("system");
  expect(theme()).toBe("system");
});

test("the themes to choose from are the system's, light, dark and the five looks, Cyberpunk not among them", () => {
  expect(themes()).toEqual([
    ["system", "System"],
    ["light", "Light"],
    ["dark", "Dark"],
    ["downtempo", "Downtempo"],
    ["outrun", "Outrun"],
    ["retrowave", "Retrowave"],
    ["neonwave-dark", "Neon Wave dark"],
    ["neonwave-light", "Neon Wave light"],
  ]);
});

test("a chat is drawn as bubbles while no layout was chosen, and when what is kept is no layout", () => {
  expect(chatLayout()).toBe("bubbles");
  localStorage.setItem("chat-layout", "columns");
  expect(chatLayout()).toBe("bubbles");
});

test("a layout chosen is said on the root at once and kept for the next start", () => {
  setChatLayout("plain");
  expect(document.documentElement.dataset.chat).toBe("plain");
  expect(localStorage.getItem("chat-layout")).toBe("plain");
  expect(chatLayout()).toBe("plain");
  setChatLayout("bubbles");
  expect(document.documentElement.dataset.chat).toBe("bubbles");
  expect(chatLayout()).toBe("bubbles");
});

test("at the start the root is told the layout that was kept, and bubbles where none was", () => {
  showChatLayout();
  expect(document.documentElement.dataset.chat).toBe("bubbles");
  localStorage.setItem("chat-layout", "plain");
  showChatLayout();
  expect(document.documentElement.dataset.chat).toBe("plain");
  // Showing one keeps nothing.
  localStorage.clear();
  showChatLayout("plain");
  expect(localStorage.getItem("chat-layout")).toBeNull();
});

test("the layouts to choose from are bubbles and plain", () => {
  expect(chatLayouts()).toEqual([
    ["bubbles", "Bubbles"],
    ["plain", "Plain"],
  ]);
});

test("Compact is off while not chosen; on, the root says it at once and it is kept, off takes it away", () => {
  expect(compact()).toBe(false);
  setCompact(true);
  expect(document.documentElement.dataset.density).toBe("compact");
  expect(localStorage.getItem("density")).toBe("compact");
  expect(compact()).toBe(true);
  setCompact(false);
  expect(document.documentElement.dataset.density).toBeUndefined();
  expect(compact()).toBe(false);
});

test("a choice of the look tells the page, so what shows it is drawn anew", () => {
  let told = 0;
  const count = () => told++;
  document.addEventListener("look", count);
  setTheme("dark");
  setChatLayout("plain");
  setCompact(true);
  document.removeEventListener("look", count);
  expect(told).toBe(3);
});

test("public/early.js sets every theme but the system's, its list written by tools/looks.py from this file", () => {
  const early = readFileSync(join(process.cwd(), "public", "early.js"), "utf8");
  const line = early.split("\n").find((each) => each.includes("const themes = ["));
  expect(line).toContain("tools/looks.py");
  const listed: unknown = JSON.parse(line!.slice(line!.indexOf("["), line!.indexOf("]") + 1));
  expect(listed).toEqual(themes().map(([name]) => name).filter((name) => name !== "system"));
});
