// Who a reply is by, by name (`replierName`): its character, else in a chat without one "AI"; what a reply shows
// (`written`); a message's menu stays open as the list is drawn anew (`drawMessages`).
import { expect, test } from "vitest";
import type { ChatView } from "../api/generated/ChatView";
import type { MessageView } from "../api/generated/MessageView";
import { wording } from "../language/language";
import { drawMessages, replierName, written } from "./messages";
import { newScreen } from "./screen";

test("a reply in a chat without a character is by the AI, not its model", () => {
  const view = (model: string | null, ...names: string[]) => ({ model, characters: names.map((name, at) => ({ id: at + 1, name })) }) as unknown as ChatView;
  const reply = (model: string | null, speaker_id: number | null = null) => ({ model, speaker_id }) as MessageView;
  expect(replierName(view("Chat model"), reply("Reply model"))).toBe("AI");
  expect(replierName(view(null), undefined)).toBe("AI");
  expect(replierName(view("Chat model", "Isolde", "Bram"), reply("Reply model", 2))).toBe("Bram");
  expect(replierName(view("Chat model", "Isolde", "Bram"), undefined)).toBe("Isolde");
});

test("an assistant's reply keeps an empty line between its paragraphs when it is copied", () => {
  const plain = { model: null, characters: [] } as unknown as ChatView;
  const shown = document.createElement("div");
  shown.append(...written(plain, { content: "One\n\n- two\n- three", complete: true } as MessageView));
  expect(shown.textContent).toBe("One\n\ntwothree");
});

test("a message's menu stays open as the list is drawn anew, as an event of the server has it", () => {
  const s = newScreen(1);
  const message = (id: number, role: string) =>
    ({ id, parent_id: id - 1, role, speaker_id: null, content: `Line ${id}`, complete: true, swipes: [], picture: null, tokens: null, task_id: null, attachments: [] }) as unknown as MessageView;
  s.view = { chat: { id: 1, trashed: false }, model: null, characters: [], messages: [message(1, "user"), message(2, "assistant")] } as unknown as ChatView;
  document.body.append(s.list);
  drawMessages(s);
  const options = () => [...s.list.querySelectorAll<HTMLButtonElement>(`[data-id="2"] button`)].filter((button) => button.ariaLabel === wording("messages-message-options"));
  options()[0].click();
  drawMessages(s);
  expect(options().map((button) => button.ariaExpanded)).toEqual(["true"]);
  s.list.remove();
});
