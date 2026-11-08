// The chat's messages: the list of the branch in view (`drawMessages`), and a message with its tools: versions,
// Regenerate, Continue (steered by the field's words, `goOn`), "Generate reply", and its menu "Message options" (copy, branch, edit, read aloud, delete),
// in `.tools` after a reply's (i), its statistics (stats.ts).
//
// A message is `article.message`: `.message-head` (`.avatar`, `.speaker`, whose tooltip says its tokens),
// `.bubble > .text` (narration.ts) or a picture with its own menu (pictures.ts), what the user attached over the
// bubble (`.attached-stack`), and `.actions`. Its menu places itself in the window
// (`menuOn` with `float`). A click on a reply, not on one of its controls or its words being selected, chooses it
// (`.chosen`, `choose`), for the side panel's "Used in this reply"; a second click lets it go. The user's round is the persona's, else the account's; a chat
// without a character has "AI" with the robot round (`aiRound`). A coding task's card (coding.ts)
// stands in its message's place (`cards`). While something is written a message is only read (`idle`). While the
// model thinks before a reply's first word, one grey line under its head says the newest sentence of its thinking in
// the bubble's place (`showThinking`, `.thinking`). A reply without words yet has the typing sign in its bubble
// (`typingSign`), and so has the bubble that stands in its place from Send until its message comes (`asked`).
import { showRound } from "../account";
import type { ChatCharacter } from "../api/generated/ChatCharacter";
import type { ChatView } from "../api/generated/ChatView";
import type { MessageView } from "../api/generated/MessageView";
import { avatarUrl, deleteMessage, deleteVersion, editMessage, moveHead, restoreMessages } from "../api/client";
import { taskCard } from "./coding";
import { announce, el, iconButton, typingDots } from "../dom";
import { isArt } from "../art";
import { menuOn, type MenuItem } from "../dialogs";
import { icon, type IconName } from "../icons";
import { deleteItem } from "../library/library-actions";
import { narrated } from "../narration";
import { chatLayout } from "../theme";
import { readAloud, spoken, stopReading } from "../voice/voice";
import { speakerOf } from "./panel";
import { attachedTo, avatar, pictureOf } from "./pictures";
import { statsButton } from "./stats";
import { forget, keep, kept } from "../unsaved";
import { typed } from "./composer";
import { act, branch, failed, idle, reply, show, tell, type Screen } from "./screen";
import { wording } from "../language/language";

/** Draws the branch in view anew, the message branched off after marked; a message being edited keeps the cursor. */
export function drawMessages(s: Screen): void {
  const messages = s.view?.messages ?? [];
  const active = document.activeElement;
  const typing = active instanceof HTMLTextAreaElement && s.list.contains(active) ? active : null;
  const point = messages.findIndex((message) => message.id === s.branchAt);
  s.list.replaceChildren(
    ...messages.map((message, i) => {
      const shown = messageNode(s, message, i === messages.length - 1);
      shown.classList.toggle("branch-point", i === point);
      shown.classList.toggle("later", point >= 0 && i > point);
      return shown;
    }),
  );
  if (s.asked !== null && (messages.at(-1)?.id ?? -1) === s.asked) s.list.append(waitingNode(s));
  if (typing) {
    const area = s.list.querySelector("textarea");
    area?.focus();
    area?.setSelectionRange(typing.selectionStart, typing.selectionEnd);
  }
}

/** The round of a chat without a character: the AI itself. */
export const aiRound = () => el("span", { className: "initial initial-sm avatar ai", ariaHidden: "true" }, icon("robot", 16));

/** Chooses the reply `id` with a click, or lets it go where it is chosen; not a click on a control, or one that selected words. */
function choose(s: Screen, id: number, event: MouseEvent): void {
  if (event.target instanceof Element && event.target.closest("button, a, input, textarea, [role=menu], .message-edit")) return;
  if (!(window.getSelection()?.isCollapsed ?? true)) return;
  s.chosen = s.chosen === id ? null : id;
  s.render();
}

/**
 * Who a reply is by, by name: its character, else the chat's first; in a chat without a character "AI" (the model
 * stays in the header's grey line).
 */
export const replierName = (view: ChatView, message: MessageView | undefined): string =>
  speakerOf(view.characters, message?.speaker_id)?.name ?? wording("messages-ai");

/**
 * Who a message is by: the picture in a round, and the name. A character has
 * its own picture; the user goes by the chat's persona, its picture or the first letter of its name, and
 * without one by the account's.
 */
function head(s: Screen, message: MessageView): HTMLElement {
  const by = (picture: HTMLElement | null, ...name: (Node | string | undefined)[]) =>
    el("div", { className: "msg-head" }, picture, el("span", { className: "speaker semi", title: wording("messages-tokens", { count: message.tokens }) }, ...name));
  if (message.role === "system") return by(null, wording("theme-system"));
  const { persona, characters } = s.view!;
  if (message.role === "assistant") {
    const one = speakerOf(characters, message.speaker_id);
    return by(one ? avatar(one) : characters.length ? null : aiRound(), replierName(s.view!, message));
  }
  const me = el("span", { className: `initial initial-sm avatar own${persona ? " of-persona" : ""}`, ariaHidden: "true" });
  if (persona) showRound(me, persona);
  else if (s.account) showRound(me, s.account);
  // Plain has every message at the left, and says which is the user's. Without a character the user is the account.
  if (persona) return by(me, persona.name, el("span", { className: "you" }, wording("messages-you")));
  return by(me, !characters.length && s.account ? s.account.name : wording("messages-you-2"));
}

function messageNode(s: Screen, message: MessageView, isNewest: boolean): HTMLElement {
  const mine = message.role === "user";
  const shown = el("article", { className: `msg message ${message.role}${mine ? " me" : ""}` }, head(s, message));
  shown.dataset.id = String(message.id);
  if (message.role === "assistant") {
    shown.classList.toggle("chosen", s.chosen === message.id);
    shown.onclick = (event) => choose(s, message.id, event);
  }
  if (s.editing?.id === message.id) {
    shown.append(editor(s, message));
    return shown;
  }
  // A coding task's card has nothing to do with it but its own buttons.
  if (message.task_id !== null) {
    const id = message.task_id;
    const card = s.cards.get(id) ?? taskCard(id, (error) => failed(s, error));
    s.cards.set(id, card);
    shown.append(card.node);
    return shown;
  }
  // A reply in the making has nothing to do with it but the stop, at the composer; a chat in the Trash is only read.
  // A picture has a menu of its own, at its corner.
  const done = message.complete && !s.view!.chat.trashed;
  // A picture stands in its text's place, which says to the model what it shows.
  const inside = message.picture
    ? pictureOf(s, message, () => void deleteFrom(s, message))
    : el("div", { className: "text" }, ...(message.complete || message.content ? narrated(message.content, !message.complete) : [typingSign()]));
  const bubble = el("div", { className: `bubble${message.picture ? " painted" : ""} ${mine ? "msg-indent-end" : "msg-indent"}` }, inside);
  // What the user attached stands over the bubble; a message of nothing else has no bubble.
  const attached = attachedTo(message);
  const body = attached ? el("div", { className: "attached-stack flex f-col g-8 minw0" }, attached, ...(message.content.trim() ? [bubble] : [])) : bubble;
  const tools = done && !message.picture ? el("div", { className: "tools flex reveal" }, statsButton(s.node, message), more(s, message, isNewest)) : null;
  shown.append(el("div", { className: mine ? "bubble-row jc-e" : "bubble-row" }, ...(mine ? [tools, body] : [body, tools])));
  if (s.thinking?.id === message.id) thinkingLine(shown, s.thinking.line);
  const under = done && actions(s, message, isNewest);
  if (under) shown.append(under);
  return shown;
}

/** A reply is on its way and has no words yet. */
const typingSign = () => typingDots(wording("messages-writing"));

/**
 * The reply asked for, until its message comes: the bubble with the typing sign under who replies, where that is
 * known (the character picked to reply, or the only one); in a chat without a character, the AI.
 */
function waitingNode(s: Screen): HTMLElement {
  const { characters, chat } = s.view!;
  const one = chat.replier_id !== null ? speakerOf(characters, chat.replier_id) : characters.length === 1 ? characters[0] : undefined;
  const head = el("div", { className: "msg-head" });
  if (one) head.append(avatar(one), el("span", { className: "speaker semi" }, one.name));
  else if (!characters.length) head.append(aiRound(), el("span", { className: "speaker semi" }, s.view!.model ?? wording("messages-ai")));
  return el("article", { className: "msg message assistant asked" }, head, el("div", { className: "bubble-row" }, el("div", { className: "bubble msg-indent" }, el("div", { className: "text" }, typingSign()))));
}

/** Shows the thinking line of the reply `id` as the screen has it, or takes it away once there is none. */
export function showThinking(s: Screen, id: number): void {
  const shown = s.list.querySelector<HTMLElement>(`[data-id="${id}"]`);
  if (!shown) return;
  if (s.thinking?.id === id) thinkingLine(shown, s.thinking.line);
  else {
    shown.querySelector(".think")?.remove();
    shown.classList.remove("thinking");
  }
}

/** Puts `line` under the head of the message `shown`, in its bubble's place. */
function thinkingLine(shown: HTMLElement, line: string): void {
  let think = shown.querySelector(".think");
  if (!think) {
    think = el("div", { className: "think" });
    shown.querySelector(".msg-head")?.after(think);
  }
  think.textContent = line;
  shown.classList.add("thinking");
}

/** Reads `message` aloud, after stopping what was read before, a character's reply in its card's voice; the menu says "Stop reading" meanwhile. */
function read(s: Screen, message: MessageView): void {
  s.reading = message.id;
  s.render();
  const characters = s.view!.characters;
  const one = message.role === "assistant" && characters.length ? speakerOf(characters, message.speaker_id) : undefined;
  readAloud(spoken(message.content), s.voice!.rate, (why) => {
    if (why) failed(s, why);
    if (s.reading === message.id) s.reading = null;
    else if (!why) return;
    s.render();
  }, one ? { card: one.card_id } : {});
}

/** Not every page may write to the clipboard (a page served over plain http may not). */
const copy = (s: Screen, text: string) =>
  Promise.resolve()
    .then(() => navigator.clipboard.writeText(text))
    .catch(() => tell(s, wording("messages-copy-refused")));

/**
 * Deletes a message with its versions and all that follows it; the chat goes on from the message before. Of a
 * message with several versions, `only` the one shown: the chat shows another in its place. The notice's Undo puts
 * it all back.
 */
const deleteFrom = (s: Screen, message: MessageView, only = false) =>
  act(s, async () => {
    const after = (s.view?.messages.length ?? 0) - 1 - (s.view?.messages.findIndex((other) => other.id === message.id) ?? 0);
    s.view = await (only ? deleteVersion : deleteMessage)(message.id);
    announce(after ? wording("messages-message-and-the-after", { after }) : wording("messages-message-deleted"), async () => {
      s.view = await restoreMessages(message.id);
      s.render();
    });
  });

/**
 * A message's menu, "…": copy its text, branch off after it, change it, read it aloud, delete it. The
 * newest message has nothing to branch off from: what is sent next follows
 * it anyway. While a reply is written, a message that is there can be
 * copied and no more; the reply itself has no menu until it is written, and
 * no message of a chat in the Trash has one.
 */
function more(s: Screen, message: MessageView, isNewest: boolean): HTMLElement {
  const still = !idle(s);
  const items: MenuItem[] = [
    { label: wording("mcp-copy"), shape: "copy", action: () => void copy(s, message.content) },
    ...(isNewest ? [] : [{ label: wording("messages-branch-from-here"), shape: "branch" as const, off: still, action: () => branch(s, message.id) }]),
    { label: wording("messages-edit-message"), shape: "edit", action: () => edit(s, message) },
    // The voice reads once it is downloaded, or at once where it is at a provider.
    ...(!(s.voice?.state === "ready" || s.voice?.at_provider) || !spoken(message.content).trim()
      ? []
      : s.reading === message.id
        ? [{ label: wording("messages-stop-reading"), shape: "stop" as const, action: stopReading }]
        : [{ label: wording("messages-read-aloud"), shape: "speaker" as const, action: () => read(s, message) }]),
    // Where it has several versions, the one shown alone, or all of them, which the line says.
    ...(message.swipes.length > 1 ? [{ ...deleteItem(() => void deleteFrom(s, message, true)), off: still, label: wording("messages-delete-version") }] : []),
    { ...deleteItem(() => void deleteFrom(s, message)), off: still, ...(message.swipes.length > 1 ? { label: wording("messages-delete-versions", { count: message.swipes.length }) } : {}) },
  ];
  const button = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("messages-message-options") }, icon("more"));
  // In Plain the button ends the name's line, and the menu opens back from there.
  return menuOn(button, items, chatLayout() === "plain" ? "end" : true);
}

/**
 * What stands under a message: the arrows through its versions, where it
 * has several, and under the newest message Regenerate and Continue, for a reply, and
 * "Generate reply". Nothing, for a message that has none of them.
 */
function actions(s: Screen, message: MessageView, isNewest: boolean): HTMLElement | null {
  const row = el("div", { className: "acts reveal" });
  // While the characters reply by themselves, as while a reply or the user's message is written, a message is only read.
  const free = idle(s);
  /** An action as its icon, named for screen readers and on hover. */
  const button = (label: string, shape: IconName, run: () => void, enabled = free, title = label) => {
    const added = iconButton(label, title, shape, run);
    added.disabled = !enabled;
    row.append(added);
  };
  const { swipes } = message;
  if (swipes.length > 1) {
    const at = swipes.indexOf(message.id);
    // The other swipe comes with what follows it: the branch last written in under it.
    const to = (step: number) => () =>
      act(s, async () => {
        s.view = await moveHead(s.chatId, { message_id: swipes[at + step], follow: true });
      });
    button(wording("messages-previous-version"), "left", to(-1), free && at > 0);
    row.append(el("span", { className: "count meta", title: wording("messages-version-of", { at: at + 1, count: swipes.length }) }, wording("card-texts-greeting-at", { at: at + 1, count: swipes.length })));
    button(wording("messages-next-version"), "right", to(1), free && at < swipes.length - 1);
  }
  if (isNewest && message.role === "assistant") {
    button(wording("messages-write-again"), "regenerate", () => act(s, () => reply(s, { regenerate: true })));
    // A reply without words has nothing to go on from.
    if (message.content.trim() && !message.picture) button(wording("messages-continue-reply"), "continue", () => act(s, () => goOn(s)), free, wording("messages-continue-uses-what-you"));
  }
  // It shows after a reply failed, and in a chat of several characters under the newest message whoever
  // wrote it: there one of them may reply to another.
  const several = (s.view?.characters.length ?? 0) > 1;
  if (isNewest && (message.role === "user" || several)) {
    row.append(el("button", { type: "button", className: "btn btn-quiet btn-sm generate", disabled: !free, onclick: () => act(s, () => reply(s)) }, icon("reply", 14), wording("messages-generate-reply")));
  }
  return row.childElementCount ? row : null;
}

/**
 * Continues the newest reply, steered by the words in the field, which are sent as no message and, once the reply
 * is continued, leave the field (C7); failing, they stay.
 */
async function goOn(s: Screen): Promise<void> {
  const words = s.input.value;
  await reply(s, words.trim() ? { continue: true, direction: words } : { continue: true });
  if (s.input.value === words && words) {
    s.input.value = "";
    typed(s);
  }
}

/** The name a message's unsaved edit is kept by (../unsaved.ts). */
const fieldOf = (id: number) => `message.${id}`;

/** Opens the message's editor, with its words, or with those typed there before and not saved, which come back. */
function edit(s: Screen, message: MessageView): void {
  s.editing = { id: message.id, draft: message.content };
  s.render();
  s.list.querySelector("textarea")?.focus();
  void kept(fieldOf(message.id)).then((text) => {
    if (text === null || s.editing?.id !== message.id || s.editing.draft !== message.content) return;
    s.editing.draft = text;
    s.render();
  });
}

/** The message being edited: its words in a field, with Save and Cancel; Escape is Cancel. */
function editor(s: Screen, message: MessageView): HTMLElement {
  const draft = s.editing!.draft;
  const area = el("textarea", { value: draft, rows: Math.min(draft.split("\n").length + 1, 12), ariaLabel: wording("messages-edit-message") });
  area.oninput = () => {
    if (s.editing) s.editing.draft = area.value;
    keep(fieldOf(message.id), area.value === message.content ? "" : area.value);
  };
  const save = () =>
    act(s, async () => {
      const changed = await editMessage(message.id, { content: area.value });
      s.editing = null;
      forget(fieldOf(message.id));
      show(s, changed);
    });
  const cancel = () => {
    s.editing = null;
    forget(fieldOf(message.id));
    s.render();
  };
  area.onkeydown = (event) => {
    if (event.key !== "Escape" || event.isComposing) return;
    event.preventDefault();
    cancel();
  };
  return el(
    "div",
    { className: "message-edit flex f-col g-6" },
    area,
    el(
      "div",
      { className: "flex g-4" },
      el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: save }, wording("common-save")),
      el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: cancel }, wording("common-cancel")),
    ),
  );
}
