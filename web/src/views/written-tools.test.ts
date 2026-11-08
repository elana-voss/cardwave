// What the page "Tools the AI wrote" says of a tool: in its row, and in its panel.
import { expect, test } from "vitest";
import type { WrittenTool } from "../api/generated/WrittenTool";
import { day } from "../format";
import { about, used } from "./written-tools";

const tool: WrittenTool = { id: 1, name: "word_count", description: "Counts the words of a text.", code: "", on: true, created_at: Date.UTC(2026, 9, 15, 12), chat_id: 4, chat_title: "North Light", uses: 0 };

test("a row says what the tool does, when and in which chat it was made", () => {
  const when = day(tool.created_at);
  expect(about(tool)).toBe(`Counts the words of a text · made ${when} in North Light`);
  expect(about({ ...tool, chat_id: null, chat_title: null })).toBe(`Counts the words of a text · made ${when}`);
  expect(about({ ...tool, chat_title: "" })).toBe(`Counts the words of a text · made ${when} in New chat`);
});

test("the panel says how often it was used", () => {
  expect(used(0)).toBe("not used yet");
  expect(used(1)).toBe("used once");
  expect(used(3)).toBe("used 3 times");
});
