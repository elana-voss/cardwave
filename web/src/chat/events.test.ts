// What the chat screen does with the model's thinking, a change of the personas and a memory pass that failed.
import { expect, test } from "vitest";
import { onEvent } from "./events";
import { newScreen } from "./screen";
import { failureWords } from "../language/errors";

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

test("a memory pass that failed is told over the message field of its own chat alone", () => {
  const error = { code: "provider_refused", error: "401", details: { refusal: "key", whose: "model_server" } } as const;
  const other = newScreen(5);
  onEvent(other, { type: "memory_failed", chat_id: 4, error });
  expect(other.notice).toBeFalsy();
  const s = newScreen(4);
  onEvent(s, { type: "memory_failed", chat_id: 4, error });
  expect(s.notice).toBe(`The helper model could not keep this chat's memory. ${failureWords(error)}`);
});
