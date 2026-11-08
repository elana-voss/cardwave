// readList's callers: what an empty list names (its `many`) comes from the language files, never a literal,
// so every language says its own word for chats, lorebooks, personas and characters. And listScreen's reading:
// a list that could not be read says which, with Try again, and its search and switch stay usable, so a
// search that fails can be changed; a list read anew that brings another item under a resting mouse takes no
// press until it moves.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { keyed, listScreen, readList } from "./list-screen";

describe("listScreen", () => {
  it("a list that could not be read says so with Try again, which reads it anew; its search and switch stay usable", async () => {
    let fails = true;
    const shown: string[][] = [];
    const screen = listScreen({
      title: "Characters",
      kind: "library",
      search: "Search",
      placeholder: "Name or tag",
      unread: "Couldn't load your characters.",
      asked: { q: "", show: "all" },
      read: async () => {
        if (fails) throw new Error("Something went wrong in Cardwave. Try again.");
        return ["Una"];
      },
      show: (found) => void shown.push(found),
    });
    await screen.load();
    expect(screen.notice.querySelector('[role="alert"]')?.textContent).toContain("Couldn't load your characters.");
    const controls = [...screen.tools.node.querySelectorAll<HTMLInputElement | HTMLButtonElement>("input, button")];
    expect(controls.length).toBeGreaterThan(1);
    expect(controls.some((control) => control.disabled)).toBe(false);

    fails = false;
    const again = [...screen.notice.querySelectorAll("button")].find((button) => button.textContent === "Try again")!;
    again.click();
    await new Promise((done) => setTimeout(done, 0));
    expect(shown).toEqual([["Una"]]);
    expect(screen.notice.querySelector('[role="alert"]')).toBeNull();
    expect(controls.every((control) => !control.disabled)).toBe(true);
  });

  it("a list read anew that brings another item under a resting mouse takes no press until it moves; the same item stays pressable; after a touch the next tap is taken", async () => {
    let item = "Una";
    const screen = listScreen({
      title: "Characters",
      kind: "library",
      search: "Search",
      placeholder: "Name or tag",
      unread: "Couldn't load your characters.",
      asked: { q: "", show: "all" },
      read: async () => item,
      show: (name) => {
        // One row, where a browser would lay it out: under the pointer at (10, 10).
        const row = keyed(document.createElement("li"), name);
        row.getBoundingClientRect = () => new DOMRect(0, 0, 100, 20);
        screen.list.replaceChildren(row);
      },
    });
    const pointer = (type: string, pointerType: string) => screen.list.dispatchEvent(Object.assign(new Event(type), { pointerType, clientX: 10, clientY: 10 }));
    await screen.load();
    pointer("pointerenter", "mouse");
    await screen.load();
    expect(screen.list.classList.contains("still")).toBe(false);
    item = "Bo";
    await screen.load();
    expect(screen.list.classList.contains("still")).toBe(true);
    // Read once more with Bo still there: it stays at rest until the mouse moves.
    await screen.load();
    expect(screen.list.classList.contains("still")).toBe(true);
    pointer("pointermove", "mouse");
    expect(screen.list.classList.contains("still")).toBe(false);

    pointer("pointerenter", "touch");
    pointer("pointerleave", "touch");
    item = "Cy";
    await screen.load();
    expect(screen.list.classList.contains("still")).toBe(false);
  });
});

const src = join(__dirname, "..");

function sources(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === "api" ? [] : sources(path);
    return entry.name.endsWith(".ts") && !entry.name.endsWith(".test.ts") ? [path] : [];
  });
}

describe("readList", () => {
  it("an empty section without an archive is read once and says it holds nothing", async () => {
    const asked: string[] = [];
    const [found, said] = await readList(async ({ show }) => (asked.push(show), []), "personas", { q: "", show: "all" }, "No personas yet.", "", false);
    expect([found, said, asked]).toEqual([[], "No personas yet.", ["all"]]);
  });
});

describe("readList's callers", () => {
  it("name the list's things in words from the language files", () => {
    const literal: string[] = [];
    for (const file of sources(src)) {
      for (const call of readFileSync(file, "utf8").matchAll(/readList\((?:[^,()]|\([^()]*\))*,\s*(\S)/g)) {
        if (call[1] === '"' || call[1] === "'" || call[1] === "`") literal.push(file);
      }
    }
    expect(literal).toEqual([]);
  });
});
