// What a chat shows while a tool's call waits for the user (`askNode`: a raised card with Allow, Deny and the
// switch "Allow … for this chat", which with Allow lets the chat run such calls from then on; Escape is Deny), and
// what it says (`askText`). A new tool the model wrote, and a coding task's call, are asked about without the switch.
import { wording } from "../language/language";
import type { ToolAsk } from "../api/generated/ToolAsk";
import { el, escapeFree, switchBox } from "../dom";
import { spoken } from "../format";

/** What a chat says of a call that waits for the user: who wants what. */
export function askText(ask: ToolAsk, name: string): string {
  switch (ask.kind) {
    case "new_tool":
      return wording("tools-ask-new", { name, what: spoken(ask.what) });
    case "write":
      return wording("tools-ask-write", { name, what: ask.what });
    case "read":
      return wording("tools-ask-read", { name });
    case "install":
      return wording("tools-ask-install", { name });
    case "web":
      return wording("tools-ask-web", { name });
    case "app":
      return wording("tools-ask-app", { name });
    default:
      return wording("tools-ask-command", { name });
  }
}

/**
 * The card of a call that waits: what it is, the file's text, the command or what is read, and Allow and Deny,
 * which `send` answers; with `forChat`, the switch that allows such calls in the chat from then on.
 */
export function askNode(ask: ToolAsk, name: string, send: (allow: boolean, forChat: boolean) => Promise<void>, failed: (error: unknown) => void, forChat = true): HTMLElement {
  const allow = el("button", { type: "button", className: "btn btn-primary" }, wording("tools-allow"));
  const deny = el("button", { type: "button", className: "btn btn-secondary" }, wording("tools-deny"));
  const label = ask.kind === "write" ? wording("tools-allow-writing") : wording("tools-allow-commands");
  const always = switchBox({ ariaLabel: label });
  // One answer: the buttons cannot be pressed again while it is on its way.
  const answer = (allowed: boolean) => () => {
    if (allow.disabled) return;
    allow.disabled = deny.disabled = true;
    send(allowed, allowed && always.checked).catch((error) => {
      allow.disabled = deny.disabled = false;
      failed(error);
    });
  };
  allow.onclick = answer(true);
  deny.onclick = answer(false);
  const node = el(
    "div",
    { className: "tool-ask flex f-col g-10", role: "status" },
    el("span", null, askText(ask, name)),
    el("pre", { className: "code mono" }, ask.kind === "write" || ask.kind === "new_tool" || ask.kind === "app" ? ask.detail : ask.what),
    el("div", { className: "flex wrap ai-c g-8" }, allow, deny, ask.kind === "new_tool" || ask.kind === "app" || !forChat ? "" : el("label", { className: "flex ai-c g-8 fs-small ml-8" }, always, el("span", null, label))),
  );
  // Escape is Deny, while the card is on the page (the owner, 2026-10-15); not one that closes a menu, a dialog
  // or the side panel.
  const escape = (event: KeyboardEvent) => {
    // Out of the page in a tab out of view, which comes back, it listens on; drawn away, it is done.
    if (!node.isConnected) {
      if (!(node.getRootNode() as Element).hasAttribute?.("data-tab")) document.removeEventListener("keydown", escape);
      return;
    }
    const elsewhere = event.target instanceof Element && event.target.closest("dialog, aside, [role=menu]");
    if (!escapeFree(event) || elsewhere) return;
    event.preventDefault();
    answer(false)();
  };
  document.addEventListener("keydown", escape);
  return node;
}
