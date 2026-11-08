import { expect, test } from "vitest";
import type { MemoryView } from "../api/generated/MemoryView";
import { about, fromWords, matches, plainText } from "./memories";

const memory = (change: Partial<MemoryView>): MemoryView => ({
  id: "1.0",
  chat_id: 1,
  chat_title: "",
  character: "Noor",
  said_at: null,
  kind: "fact",
  text: "The ferry leaves at nine.",
  status: "current",
  until: "",
  world: false,
  known_to: null,
  names: ["Noor", "Hesper", "Sam"],
  ...change,
});

test("a row tells who know a memory by name, the user as you, its kind and state staying behind", () => {
  expect(about(memory({}))).toBe("Known by everyone");
  expect(about(memory({ status: "temporary", until: "day 14", known_to: ["sam", "noor"] }))).toBe("Known by Noor and you");
  expect(about(memory({ status: "done", world: true, known_to: [] }))).toBe("Known by nobody");
  expect(about(memory({ kind: "event", status: null, known_to: ["hesper"] }))).toBe("Known by Hesper");
});

test("an event's cause and result read as one sentence, a part left as ? left out", () => {
  expect(plainText("The queen waits (cause: the eldest lord asked it; result: the court is silent)")).toBe("The queen waits, because the eldest lord asked it, so the court is silent.");
  expect(plainText("Ana comes tonight. (cause: ?; result: Mira waits)")).toBe("Ana comes tonight, so Mira waits.");
  expect(plainText("The ferry leaves at nine.")).toBe("The ferry leaves at nine.");
});

test("the search finds a memory by its text, its chat and who may know it", () => {
  expect(matches(memory({}), "ferry hesper")).toBe(true);
  expect(matches(memory({}), "noor")).toBe(true);
  expect(matches(memory({}), "ferry pirates")).toBe(false);
});

test("a row names a chat without a title as the user's chat with its character", () => {
  expect(fromWords(memory({}))).toContain("From your chat with");
  expect(fromWords(memory({ chat_title: "The ferry" }))).toContain("From the chat");
});
