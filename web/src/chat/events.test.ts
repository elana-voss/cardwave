// What the chat screen does with the model's thinking, and with a change of the personas.
import { expect, test } from "vitest";
import { onEvent } from "./events";
import { newScreen, sayBrokeOff } from "./screen";

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

test("a reply the app's close broke off says so when its chat is opened, as it said so live", () => {
  const s = newScreen(4);
  s.view = { messages: [{ id: 9, content: "The tide", complete: true, broke_off: true }] } as never;
  sayBrokeOff(s);
  expect(s.notice).toBe("The reply broke off.");
});
