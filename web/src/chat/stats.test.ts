// What the dialog "About this reply" says of a reply, line by line; how it looks is the browser tests'.
import { expect, onTestFinished, test } from "vitest";
import type { MessageView } from "../api/generated/MessageView";
import { sentParts, statLines } from "./stats";
import { useLanguage } from "../language/language";

const reply = (more: Partial<MessageView>): MessageView => ({
  id: 1, parent_id: null, role: "assistant", speaker_id: null, content: "", complete: true, token_count: null, created_at: 0,
  swipes: [1], lore: [], memories: [], picture: false, tokens: 0, task_id: null, context: null, model: null, provider: null, times: null, sent: null, reads: [], attachments: [],
  ...more,
});

test("a reply's model, response time and context, each line only where the reply has it", () => {
  const all = reply({ model: "gpt-x", provider: "OpenAI", times: { to_first_word_ms: 420, in_all_ms: 12_345 }, context: { used: 3_000, size: 8_000 } });
  expect(statLines(all)).toEqual([
    { name: "Model", says: "gpt-x · OpenAI" },
    { name: "Response time", says: "0.4 s to the first word · 12.3 s in all" },
    { name: "Context", says: "3,000 of 8,000 tokens used · 5,000 free", filled: 37.5 },
  ]);
  // A picture alone has no first word; a reply from before has no provider or times.
  expect(statLines(reply({ model: "m", times: { to_first_word_ms: null, in_all_ms: 2_000 } }))).toEqual([
    { name: "Model", says: "m" },
    { name: "Response time", says: "2.0 s in all" },
  ]);
  expect(statLines(reply({}))).toEqual([]);
});

test("the seconds' unit is the language's", () => {
  onTestFinished(() => useLanguage("en"));
  useLanguage("ru", Object.values(import.meta.glob<string>("../language/ru.chat.ftl", { query: "?raw", import: "default", eager: true }))[0]);
  expect(statLines(reply({ times: { to_first_word_ms: null, in_all_ms: 2_000 } }))[0].says).toBe("всего 2,0 с");
});

test("Sent to the AI is the sum of its five parts", () => {
  expect(sentParts({ card: 300, persona: 20, memory: 0, lorebook: 40, history: 900 })).toEqual({
    total: 1_260,
    parts: [["Character", 300], ["Persona", 20], ["Memory", 0], ["Lorebook", 40], ["Earlier messages", 900]],
  });
});
