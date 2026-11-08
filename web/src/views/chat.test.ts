// When a chat opens with its message field in focus (`opensWriting`).
import { expect, test } from "vitest";
import type { ChatView } from "../api/generated/ChatView";
import { opensWriting } from "./chat";

test("a chat the user wrote nothing in opens with the field in focus, but not on a touch screen, whose keyboard it would raise", () => {
  const fresh = { messages: [{ role: "assistant" }] } as unknown as ChatView;
  expect(opensWriting(fresh, document.body, false)).toBe(true);
  expect(opensWriting(fresh, document.body, true)).toBe(false);
});
