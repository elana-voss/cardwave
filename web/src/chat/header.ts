// The chat's bar: the first character's picture and name, leading to its card's page, with who else is in the
// chat under it (a chat without a character has its title, the model under it); the mode's pill after the title,
// for a card with modes; the chat's menu (Rename, "New chat with these characters" in a chat of several, "Add
// lorebook" while the side panel shows no Lorebooks (`lorebooks`, views/chat.ts), Export, Archive, Delete; Restore
// alone in the Trash is a notice); the
// split view's button (chat/split.ts) and the button that shows the side panel; views/chat.ts gives both their use.
// The chat's title is written where it stands (`inPlace`, `titleLine`): a click on it, or Rename, which in a chat
// whose line shows no title writes it in that line's place.
//
// Each part is drawn anew only when what it shows changed (`titleFor`, `modeFor`, `optionsFor`), so that a menu
// that is open stays open; the title is not drawn anew while it is written in.
import { avatarUrl, changeChat, chatAgain, renameChat, setChatMode } from "../api/client";
import { inPlace } from "../in-place";
import { announce, el, reason, titled } from "../dom";
import { chatName, chatTitle } from "../chat-title";
import { menu, menuOn, type MenuItem } from "../dialogs";
import { icon } from "../icons";
import { exportChatLine, trashItem } from "../library/library-actions";
import { modeLabel, sameMode } from "../card/modes";
import { avatar } from "./pictures";
import type { ChatCharacter } from "../api/generated/ChatCharacter";
import { act, personalityNow, toolsNow, took, type Screen } from "./screen";
import { wording } from "../language/language";
import { comma } from "../format";

export interface Header {
  node: HTMLElement;
  /** The menu and the two buttons, shown once the chat is read. */
  tools: HTMLElement;
  splitToggle: HTMLButtonElement;
  panelToggle: HTMLButtonElement;
  title: HTMLElement;
  modePlace: HTMLElement;
  options: HTMLElement;
  /** Begins writing the chat's title where it stands. */
  rename: () => void;
  /** The menu's "Add lorebook": whether it is needed, as the side panel shows no Lorebooks, and what it does. */
  lorebooks: { needed(): boolean; add(): void };
  /** What the title, the mode's pill and the menu were last drawn from. */
  titleFor: string;
  modeFor: string;
  optionsFor: string;
}

export function header(): Header {
  const title = el("h1", { className: "flex ai-c g-12 minw0" });
  const modePlace = el("span", { className: "mode-place" });
  const options = el("span");
  const panelToggle = el("button", { type: "button", className: "btn btn-quiet btn-icon" }, icon("panel"));
  const splitToggle = el("button", { type: "button", className: "btn btn-quiet btn-icon" }, icon("split"));
  const tools = el("div", { className: "bar-tools flex g-4 ai-c ml-auto", hidden: true }, options, splitToggle, panelToggle);
  const node = el("header", { className: "chat-bar g-12" }, title, tools);
  return { node, tools, splitToggle, panelToggle, title, modePlace, options, rename: () => undefined, lorebooks: { needed: () => false, add: () => undefined }, titleFor: "", modeFor: "", optionsFor: "" };
}

export function drawHeader(s: Screen, h: Header): void {
  drawTitle(s, h);
  drawMode(s, h);
  drawOptions(s, h);
}

/**
 * The first character's picture and name lead to its card's page. Under the name stands who else is in the
 * chat, or, in a chat of one, the chat's own name where it is another. The first is the one the chat began
 * with, and the others are in the order they joined, as the list of chats has them, whatever the speaking order
 * (the characters' IDs say the order they joined in). A chat of several shows their rounds overlapping, the first
 * in front: written last to first in a row drawn from the right (`.chat-rounds`), so the first is painted last.
 * A chat without a character has its title, the model under it.
 */
function drawTitle(s: Screen, h: Header): void {
  const { chat, characters, model } = s.view!;
  const [first, ...others] = [...characters].sort((one, other) => one.id - other.id);
  // Its tab is called as the rail calls the chat, with the first character's round.
  titled(s.node, chatName({ names: first ? [first.name] : [], title: chat.title }), first ? avatarUrl(first) : null);
  const under = others.length ? wording("header-with", { join: others.map((other) => other.name).join(comma()) }) : first && chat.title !== first.name ? chat.title : "";
  const named = JSON.stringify([first?.card_id, first?.name, first?.avatar_url, others.map((other) => other.avatar_url), under, chat.title, model]);
  if (named === h.titleFor || h.title.querySelector(".in-place")) return;
  h.titleFor = named;
  const line = titleLine(s, h, first ? "meta" : "", first ? (under === chat.title ? under : null) : chat.title, under);
  h.title.replaceChildren(
    first
      ? el("a", { className: "ink-link flex ai-c g-10 chat-link", href: `#/library/${first.card_id}` }, rounds(first, others), el("span", { className: "chat-who" }, el("span", { className: "semi" }, first.name), line))
      : el("span", { className: "chat-who" }, line, model && el("span", { className: "meta" }, model)),
    h.modePlace,
  );
}

/** The first character's round, or in a chat of several everyone's, overlapping with the first in front, each naming its character while pointed at. */
function rounds(first: ChatCharacter, others: ChatCharacter[]): HTMLElement {
  if (!others.length) return avatar(first, "ava ava-lg");
  return el("span", { className: "chat-rounds" }, ...[first, ...others].reverse().map((one) => avatar(one, "ava-stack", true)));
}

/**
 * The line of the header the chat's title is written in: `title` where it shows the title, else null, and
 * `other` what it shows then ("with …", or nothing). A click on the title writes it, Enter or leaving saves,
 * Escape takes it back; Rename (`h.rename`) writes it in the line whatever it shows. As the line may stand in
 * the link to the card's page, a click that writes in it does not follow the link. An emptied title is not saved.
 * What it shows is the chat's title as read now, which another window may have changed while it was written.
 */
function titleLine(s: Screen, h: Header, className: string, title: string | null, other: string): HTMLElement {
  const line = el("span", { className });
  let asked = false;
  /** The title shown while its save waits: the chat read has it only once saved. */
  let held: string | null = null;
  h.rename = inPlace(line, {
    label: wording("header-chat-title"),
    limit: TITLE_LIMIT,
    value: () => chatTitle(s.view!.chat.title),
    show: () => {
      line.tabIndex = title === null ? -1 : 0;
      line.classList.toggle("chat-title", title !== null);
      return [title === null ? other : (held ?? chatTitle(s.view!.chat.title))];
    },
    blocked: () => title === null && !asked,
    editing: (on) => {
      if (!on) asked = false;
    },
    commit: (text) => {
      if (!text.trim()) return;
      held = text.trim();
      void renameChat(s.chatId, { title: held }).then(
        (chat) => {
          took(s, chat);
          s.render();
        },
        (error) => {
          held = null;
          if (title !== null && !line.querySelector(".in-place")) line.replaceChildren(chatTitle(s.view!.chat.title));
          announce(wording("header-the-title-was-not", { reason: reason(error) }));
        },
      );
    },
  });
  const begin = h.rename;
  h.rename = () => {
    asked = true;
    begin();
  };
  line.addEventListener("click", (event) => {
    if (title !== null || line.querySelector(".in-place")) event.preventDefault();
  });
  return line;
}

/** Sets the chat to a mode by hand, or has it pick by itself (null). */
const chooseMode = (s: Screen, mode: string | null) =>
  act(s, async () => {
    took(s, await setChatMode(s.chatId, mode));
    await Promise.all([personalityNow(s), toolsNow(s)]);
  });

/** The mode's pill, for a card with modes: Automatic and each mode, the one chosen ticked. */
function drawMode(s: Screen, h: Header): void {
  const { chat, modes } = s.view!;
  const modeNow = JSON.stringify([modes, chat.mode, chat.auto_mode, chat.trashed]);
  if (modeNow === h.modeFor) return;
  h.modeFor = modeNow;
  const byHand = modes.find((mode) => chat.mode !== null && sameMode(mode, chat.mode));
  const pill = el("button", { type: "button", className: "btn btn-quiet btn-fit mode-pill", disabled: chat.trashed }, modeLabel(chat, modes), icon("down", 14));
  const lines: MenuItem[] = [
    { label: wording("header-automatic"), sub: wording("header-automatic-sub"), group: wording("card-modes-mode"), chosen: !byHand, action: () => void chooseMode(s, null) },
    ...modes.map((mode) => ({ label: mode, chosen: mode === byHand, action: () => void chooseMode(s, mode) })),
  ];
  h.modePlace.replaceChildren(...(modes.length ? [menuOn(pill, lines, true)] : []));
}

/** Archives the chat or takes it back out, with the way to undo it. */
const archive = (s: Screen, archived: boolean) =>
  act(s, async () => {
    const put = async (to: boolean) => took(s, await changeChat(s.chatId, { archived: to }));
    await put(archived);
    announce(archived ? wording("header-chat-archived") : wording("header-chat-unarchived"), async () => {
      await put(!archived);
      s.render();
    });
  });

/** Moves the chat to the Trash and leaves for the list of chats, where the notice goes along. */
const remove = (s: Screen) =>
  act(s, async () => {
    await changeChat(s.chatId, { trashed: true });
    const back = async () => {
      await changeChat(s.chatId, { trashed: false });
      location.hash = `#/chats/${s.chatId}`;
    };
    announce(wording("card-box-chat-moved-to-trash"), back, true);
    location.hash = "#/chats";
  });

/** The longest title a chat is given by hand, as the server has it. */
const TITLE_LIMIT = 100;

/** Starts a new chat with this one's characters, in their order, and its settings, and goes there. */
const again = (s: Screen) =>
  act(s, async () => {
    const made = await chatAgain(s.chatId);
    location.hash = `#/chats/${made.chat.id}`;
  });

/** Makes the chat a favourite or no longer one, as the star of its line in the list of chats does. */
const favourite = (s: Screen, to: boolean) =>
  act(s, async () => {
    took(s, await changeChat(s.chatId, { favorite: to }));
    s.render();
  });

/**
 * The chat's menu: "New chat with" its character (or "with these characters") starts one as the chat is set. A chat
 * in the Trash has "Restore" and nothing else, in the notice over the field.
 */
function drawOptions(s: Screen, h: Header): void {
  const { chat, characters } = s.view!;
  const lines = chat.trashed ? "" : chat.archived ? wording("library-actions-unarchive") : wording("library-actions-archive");
  const several = characters.length > 1;
  const newWith = several ? wording("header-new-chat-with-these") : characters.length ? wording("header-new-chat-with", { name: characters[0].name }) : "";
  const starred = chat.favorite;
  const drawn = JSON.stringify([lines, newWith, starred]);
  if (drawn === h.optionsFor) return;
  h.optionsFor = drawn;
  const archived = chat.archived;
  const items: MenuItem[] = [
    { label: wording("voices-rename"), shape: "edit", action: () => h.rename() },
    {
      label: wording("library-actions-add-lorebook"),
      shape: "lorebook",
      action: () => h.lorebooks.add(),
      get hidden() {
        return !h.lorebooks.needed();
      },
    },
    ...(newWith ? [{ label: newWith, shape: "chat" as const, action: () => void again(s) }] : []),
    { label: starred ? wording("header-remove-from-favourites") : wording("header-add-to-favourites"), shape: "star", action: () => void favourite(s, !starred) },
    exportChatLine(s.chatId, wording("header-chat"), (action) => act(s, action)),
    { label: lines, shape: "archive", action: () => void archive(s, !archived) },
    trashItem(() => void remove(s)),
  ];
  h.options.replaceChildren(...(lines ? [menu(wording("header-chat-options"), items)] : []));
}
