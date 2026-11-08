// Knowledge › Memories: the facts and events the characters of the user's chats remember, as each memory holds
// now (a roleplay chat's on its branch in view), the newest first. No board draws it: it is made of the library's
// lists (docs/design.md, "Knowledge").
//
// A grey line under the search says memories come from chats (none is added by hand, the owner). A row
// (`.memory-row`) is the memory's text, an event's cause and result read as one sentence (`plainText`), under it in
// grey who knows it (the user as "you"), the chat it is from, a link, and the day it was said; its kind and state
// stay behind (proposal 59 of 88, the owner). Its "…" has Edit, a dialog of its text as the row reads it (sent only
// where it was changed, so an event keeps the form the prompt has) and of who of the chat's characters and the user
// know it (pills), and Delete,
// which asks nothing and has the notice's Undo.
// The search is the page's own, over the list it read: every word must be in the text, the chat's title or the
// names of who may know it. A memory saved,
// changed or deleted anywhere (the event `memories`), and the server heard again after a drop, have the list read
// anew. The rail leads to Knowledge's other page, views/documents.ts.
import { changeMemory, deleteMemory, listMemories, restoreMemory } from "../api/client";
import type { MemoryView } from "../api/generated/MemoryView";
import { announce, el, latest, noticeBox, oneAtATime, pill, searchField, type View } from "../dom";
import { chatTitle } from "../chat-title";
import { formDialog, menu } from "../dialogs";
import { emptyLine, pageTitle } from "../library/list-screen";
import { icon } from "../icons";
import { knownLine } from "../memory-known";
import { wording } from "../language/language";
import { ago, comma } from "../format";

/** What the list was last searched for. Kept while the app runs. */
const asked = { q: "" };

/** Who of `names` (the chat's characters, then the user) know the memory; all where everyone does. */
export function knowers(memory: MemoryView): string[] {
  const known = memory.known_to;
  return known ? memory.names.filter((name) => known.includes(name.toLowerCase())) : memory.names;
}

/** A name of `memory.names` as the page writes it: the user, the last of them, as "you" ("You" where it stands alone, a pill). */
const named = (memory: MemoryView, name: string, alone = false) =>
  isUser(memory, name) ? (alone ? wording("memories-you-alone") : wording("memories-you")) : name;

/** Whether `name` is the user's, the last of `memory.names`. */
const isUser = (memory: MemoryView, name: string) => name === memory.names[memory.names.length - 1];

/** What a row says of a memory under its text: who know it, the user as "you". */
export function about(memory: MemoryView): string {
  if (!memory.known_to) return knownLine({ code: "everyone" });
  const known = knowers(memory);
  return knownLine({ code: "by", names: known.filter((name) => !isUser(memory, name)), you: known.some((name) => isUser(memory, name)) });
}

/** An event's text as one plain sentence: "[what] (cause: [c]; result: [r])", as the memory keeps it for the prompt, reads "[what], because [c], so [r]."; a part the helper model left as "?" is left out. */
export function plainText(text: string): string {
  const parts = /^(.*) \(cause: (.*); result: (.*)\)$/s.exec(text);
  if (!parts) return text;
  const [, what, cause, result] = parts.map((part) => part.trim());
  const known = (part: string) => part !== "" && part !== "?";
  const end = (part: string) => part.replace(/[.!?]+$/, "");
  const said = [end(what!), known(cause!) ? wording("memories-because", { end: end(cause!) }) : "", known(result!) ? wording("memories-so", { end: end(result!) }) : ""].filter(Boolean).join(comma());
  return `${said}.`;
}

/** What a chat is called in a row: its title, else the character it began with. */
const chatName = (memory: MemoryView) => memory.chat_title || chatTitle(memory.character);

/** The words before the chat's link in a row: "From the chat" before its title, "From your chat with" before the character's name. */
export const fromWords = (memory: MemoryView) => (memory.chat_title || !memory.character ? wording("memories-from-the-chat") : wording("memories-from-your-chat-with"));

/** Whether every word of `query` is in what is said of the memory. */
export function matches(memory: MemoryView, query: string): boolean {
  const said = [memory.text, chatName(memory), ...memory.names].join(" ").toLowerCase();
  return query.toLowerCase().split(/\s+/).filter(Boolean).every((word) => said.includes(word));
}

export function memoriesView(): View {
  const list = el("ul", { className: "rows-plain" });
  const notice = noticeBox();
  let all: MemoryView[] = [];
  const draw = () => {
    const found = all.filter((memory) => matches(memory, asked.q));
    list.replaceChildren(...found.map(row));
    if (!found.length) list.append(emptyLine(all.length ? wording("memories-no-memory-found") : wording("memories-nothing-remembered-yet")));
  };
  const search = searchField(wording("memories-search-memories"), wording("memories-text-chat-or-character"), asked, draw, "search-list");
  const node = el(
    "section",
    { className: "main main-list knowledge" },
    el("header", { className: "pbar" }, pageTitle(wording("page-memories"))),
    el("div", { className: "flex g-12" }, search),
    el("p", { className: "meta m0" }, wording("memories-come-from-chats")),
    notice,
    list,
  );
  const attempt = oneAtATime(notice);
  const load = latest(notice, listMemories, (memories) => {
    all = memories;
    draw();
  });

  function edit(memory: MemoryView): void {
    const shown = plainText(memory.text);
    const text = el("textarea", { id: "memory-text", className: "field", rows: 4, value: shown, required: true });
    const had = knowers(memory);
    const knows = new Set(had);
    const pills = memory.names.map((name) => {
      const button = pill(named(memory, name, true), knows.has(name), () => {
        if (!knows.delete(name)) knows.add(name);
        button.ariaPressed = String(knows.has(name));
      });
      return button;
    });
    const fields = [
      el("div", { className: "fld" }, el("label", { htmlFor: text.id }, wording("library-actions-kind-text")), text),
      el("div", { className: "fld" }, el("span", { className: "field-name label" }, wording("memories-known-by")), el("div", { className: "pills", role: "group", ariaLabel: wording("memories-known-by") }, ...pills), el("p", { className: "hint" }, wording("memories-known-by-hint"))),
    ];
    const box = formDialog(node, wording("memories-edit-memory"), fields, async () => {
      // Each part is sent only where it was changed: "everyone" stays so, and an event its form.
      const same = knows.size === had.length && had.every((name) => knows.has(name));
      await changeMemory(memory.id, { ...(text.value === shown ? {} : { text: text.value }), ...(same ? {} : { known_to: [...knows] }) });
      box.close();
      await load();
    });
  }

  function row(memory: MemoryView): HTMLElement {
    const remove = () =>
      attempt(async () => {
        await deleteMemory(memory.id);
        await load();
        announce(wording("memories-memory-deleted"), async () => {
          await restoreMemory(memory.id);
          await load();
        });
      });
    const lines = [
      { label: wording("common-edit"), shape: "edit" as const, action: () => edit(memory) },
      { label: wording("common-delete"), shape: "trash" as const, danger: true, apart: true, action: () => void remove() },
    ];
    const when = memory.said_at === null ? [] : [" · ", ago(memory.said_at)];
    return el(
      "li",
      { className: "item row item-roomy ai-s memory-row" },
      el("span", { className: "icover icover-sq" }, icon("knowledge")),
      el(
        "div",
        { className: "item-text item-text-spaced" },
        el("span", { className: "medium two-lines" }, plainText(memory.text)),
        el("span", { className: "meta" }, about(memory), fromWords(memory), el("a", { href: `#/chats/${memory.chat_id}` }, chatName(memory)), ...when),
      ),
      el("div", { className: "reveal flex" }, menu(wording("common-more"), lines)),
    );
  }

  void load();
  return {
    node: node,
    onEvent: (event) => void (event.type === "memories" && load()),
    onConnected: () => void load(),
  };
}
