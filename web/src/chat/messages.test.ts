// Who a reply is by, by name (`replierName`): its character, else in a chat without one "AI"; what a reply shows (`written`).
import { expect, test } from "vitest";
import type { ChatView } from "../api/generated/ChatView";
import type { MessageView } from "../api/generated/MessageView";
import { replierName, written } from "./messages";

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
