// What the chat screen does with the model's thinking, and with a change of the personas.
import { expect, test } from "vitest";
import { onEvent } from "./events";
import { newScreen } from "./screen";

test("thinking told before the reply is known waits for it", () => {
  const s = newScreen(4);
  onEvent(s, { type: "reply_thinking", chat_id: 4, message_id: 9, line: "She weighs the storm." });
  expect(s.thinking).toEqual({ id: 9, line: "She weighs the storm." });
});

test("a change of the personas has the chat read anew, as a persona's lorebooks are the chat's", () => {
  const s = newScreen(4);
  s.loading = Promise.resolve();
  onEvent(s, { type: "personas" });
  expect(s.held).toEqual([{ type: "personas" }]);
});
