import { expect, test } from "vitest";
import type { Lorebook } from "../api/generated/Lorebook";
import { usedLine } from "./lorebooks";

const book = (change: Partial<Lorebook>): Lorebook => ({
  id: 1,
  name: "Reef",
  description: "",
  entries: 2,
  entry_names: [],
  favorite: false,
  archived: false,
  trashed: false,
  everywhere: false,
  used_by: [],
  chats: 0,
  ...change,
});

test("a lorebook's line says who use it, and nothing where its name's line says it already", () => {
  expect(usedLine(book({}))).toBe("Not used yet");
  expect(usedLine(book({ used_by: ["Mira", ""] }))).toBe("Used by Mira and Untitled");
  expect(usedLine(book({ chats: 2 }))).toBe("In 2 chats");
  expect(usedLine(book({ used_by: ["Ada"], chats: 1 }))).toBe("Used by Ada · in 1 chat");
  expect(usedLine(book({ everywhere: true }))).toBeNull();
  expect(usedLine(book({ card: { card_id: 3, title: "Mira", reference: "lorebook.x", first: true } }))).toBeNull();
});
