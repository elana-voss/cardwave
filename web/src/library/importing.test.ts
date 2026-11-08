// What the import panel's head says of a folder of cards: while its files are looked for, while they are imported,
// and what it came to, with the files the library had and those that failed; and a folder's import followed while
// an import of files runs, which neither cuts short; and the notice of one card imported, which leads to it.
import { expect, test, vi } from "vitest";
import { getCardFolderImport } from "../api/client";
import type { FolderImport } from "../api/generated/FolderImport";
import { fileImport, folderSaid, followFolderImport, noteWords } from "./importing";

vi.mock("../api/client", () => ({ getCardFolderImport: vi.fn() }));

const state = (more: Partial<FolderImport>): FolderImport => ({ folder: "C:\Cards", running: true, found: 0, imported: 0, skipped: 0, failed: [], ...more });

test("the head says how far a folder's import is, and what it came to", () => {
  expect(folderSaid(state({}))).toEqual({ title: "Importing cards", count: "Looking for card files…" });
  expect(folderSaid(state({ found: 40, imported: 9, skipped: 2, failed: [{ name: "a.png", reason: { code: "file_not_imported", error: "not a card", details: {} } }] }))).toEqual({ title: "Importing 40 cards", count: "12 of 40 · 1 failed" });
  expect(folderSaid(state({ running: false, found: 1, imported: 1 })).title).toBe("1 card imported");
  expect(folderSaid(state({ running: false, found: 5, imported: 0, skipped: 5 })).title).toBe("No cards imported · 5 already in the library");
  expect(folderSaid(state({ running: false, found: 4, imported: 2, skipped: 1, failed: [{ name: "b.png", reason: { code: "file_not_imported", error: "no card in it", details: {} } }] })).title).toBe("2 cards imported · 1 already in the library · 1 failed");
});

test("a folder's import followed while files are imported leaves them to go on, and shows what it came to after them", async () => {
  vi.mocked(getCardFolderImport).mockResolvedValue(state({ running: false, found: 1, imported: 1 }));
  let release = () => {};
  const gate = new Promise<void>((done) => (release = done));
  const add = vi.fn(async (file: File) => {
    await gate;
    return { title: file.name, warnings: [] };
  });
  const page = document.createElement("div");
  const notice = document.createElement("div");
  notice.id = "toast";
  document.body.append(page, notice);
  const field = fileImport("card", ".png", page, add, () => {});
  Object.defineProperty(field, "files", { value: [new File(["a"], "a.png"), new File(["b"], "b.png")] });
  field.dispatchEvent(new Event("change"));
  const following = followFolderImport();
  await new Promise((wait) => setTimeout(wait, 10));
  release();
  await following;
  expect(add).toHaveBeenCalledTimes(2);
  expect(document.querySelector("#importing h2")?.textContent).toBe("1 card imported");
  expect((document.querySelector("#importing") as HTMLElement).hidden).toBe(false);
});

test("an import's notes are worded from their codes", () => {
  expect(noteWords({ code: "first_character_kept", name: "Mira" })).toBe("Only its first character, “Mira”, was kept: Cardwave keeps one character per card.");
  expect(noteWords({ code: "asset_only_linked", kind: "", name: "sea" })).toBe('the file "sea" is only linked, not part of the card; it was not downloaded');
  expect(noteWords({ code: "dangling", owner: "character.a", key: "prompt", reference: "prompt.none" })).toBe("character.a refers to “prompt.none”, which the card does not hold");
  expect(noteWords({ code: "outlet_entries_off", count: 2 })).toBe("lorebook entries for an outlet were imported switched off (2)");
});

test("one card imported alone: its notice offers Open, which leads to its page", async () => {
  document.body.replaceChildren();
  const page = document.createElement("div");
  const notice = document.createElement("div");
  notice.id = "toast";
  document.body.append(page, notice);
  const field = fileImport("card", ".png", page, async () => ({ title: "Una", warnings: [], open: "#/library/c1" }), () => {});
  Object.defineProperty(field, "files", { value: [new File(["a"], "una.png")] });
  field.dispatchEvent(new Event("change"));
  await new Promise((wait) => setTimeout(wait, 10));
  const open = [...notice.querySelectorAll("button")].find((button) => button.textContent === "Open");
  open!.click();
  await new Promise((wait) => setTimeout(wait, 0));
  expect(location.hash).toBe("#/library/c1");
});
