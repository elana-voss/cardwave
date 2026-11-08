// What a chat says and shows of a call that waits.
import { expect, test, vi } from "vitest";
import { askNode, askText } from "./tool-ask";

const answerTool = vi.fn();
const send = (chat: number) => (allow: boolean, forChat: boolean) => answerTool(chat, allow, forChat);

test("a call that waits says who wants what", () => {
  expect(askText({ kind: "write", what: "plan.txt", detail: "Sail." }, "Mira")).toBe("Mira wants to write “plan.txt” in your folder:");
  expect(askText({ kind: "command", what: "dir", detail: "" }, "Mira")).toBe("Mira wants to run a command in your folder:");
  expect(askText({ kind: "install", what: "npm install", detail: "" }, "Worker 1")).toBe("Worker 1 wants to download and install programs it needs:");
  expect(askText({ kind: "read", what: "a.txt", detail: "" }, "Planner")).toBe("Planner wants to read in your folder:");
  expect(askText({ kind: "web", what: "lamps", detail: "" }, "Worker 2")).toBe("Worker 2 wants to use the web:");
});

test("a coding task's call shows what it reads, runs or searches, without the switch for the chat", () => {
  const node = askNode({ kind: "web", what: "lamps", detail: "" }, "Worker 2", send(3), () => {}, false);
  expect(node.querySelector("pre")!.textContent).toBe("lamps");
  expect(node.querySelector("input[role=switch]")).toBeNull();
});

test("a call is answered once: Allow and Deny cannot be pressed again while the answer is on its way", () => {
  answerTool.mockReturnValue(new Promise(() => {}));
  const node = askNode({ kind: "command", what: "dir", detail: "" }, "Mira", send(7), () => {});
  const [allow, deny] = node.querySelectorAll("button");
  allow.click();
  allow.click();
  deny.click();
  expect(answerTool.mock.calls).toEqual([[7, true, false]]);
  expect([allow.disabled, deny.disabled]).toEqual([true, true]);
});

test("the switch allows such calls for the chat with Allow, and Escape is Deny", () => {
  answerTool.mockReset().mockReturnValue(new Promise(() => {}));
  const node = askNode({ kind: "write", what: "plan.txt", detail: "Sail." }, "Mira", send(7), () => {});
  const toggle = node.querySelector<HTMLInputElement>("input[role=switch]")!;
  expect(toggle.ariaLabel).toBe("Allow writing files for this chat");
  toggle.click();
  node.querySelector<HTMLButtonElement>("button.btn-primary")!.click();
  expect(answerTool.mock.lastCall).toEqual([7, true, true]);

  const other = document.body.appendChild(askNode({ kind: "command", what: "dir", detail: "" }, "Mira", send(8), () => {}));
  expect(other.querySelector("input[role=switch]")!.ariaLabel).toBe("Allow commands for this chat");
  document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
  expect(answerTool.mock.lastCall).toEqual([8, false, false]);
  other.remove();
});

test("a change to Cardwave shows the request, without the switch for the chat", () => {
  const ask = { kind: "app", what: "post_cards_new", detail: 'POST /api/cards/new\n{ "body": {} }' } as const;
  expect(askText(ask, "Gwen")).toBe("Gwen wants to change Cardwave:");
  const node = askNode(ask, "Gwen", send(7), () => {});
  expect(node.querySelector("pre")!.textContent).toBe(ask.detail);
  expect(node.querySelector("input[role=switch]")).toBeNull();
});

test("a new tool shows its code, and has no switch for the chat", () => {
  const ask = { kind: "new_tool", what: "word_count", detail: "export default () => 1" } as const;
  expect(askText(ask, "Mira")).toBe("Mira wants to use a new tool: Word count");
  const node = askNode(ask, "Mira", send(7), () => {});
  expect(node.querySelector("pre")!.textContent).toBe("export default () => 1");
  expect(node.querySelector("input[role=switch]")).toBeNull();
});
