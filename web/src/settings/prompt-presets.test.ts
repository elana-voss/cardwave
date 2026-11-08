// What prompt-presets.ts decides without a browser: what a prompt preset's line says under its name and the name a
// preset may not have.
import { expect, test } from "vitest";
import { about, refusedName } from "./prompt-presets";

const texts = (system_prompt: string, authors_note: string, authors_note_depth = 4) => ({ system_prompt, authors_note, authors_note_depth });

test("a prompt preset's line says what it changes: the system prompt, the author's note and its depth", () => {
  expect(about(texts("Write as noir.", "[Rain.]"))).toBe("System prompt · note, 4 messages back");
  expect(about(texts("Write as noir.", ""))).toBe("System prompt");
  expect(about(texts(" ", "[Rain.]", 1))).toBe("Note, 1 message back");
  expect(about(texts("", ""))).toBe("As the character says");
});

test("no preset may be called as the page calls Default", () => {
  expect(refusedName(" Default ")).toBe("“Default” is the character's own prompt.");
  expect(refusedName("Noir")).toBeNull();
});
