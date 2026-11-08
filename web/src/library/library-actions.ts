// What can be done with a library item wherever it shows: the star, the
// changes that can be taken back, the lines of a card's menu, a chat's export,
// and the menu that adds a lorebook of the library.
//
// What is here: the star; `undoable`; `beginChat`, which starts a chat with characters of cards' versions
// and shows it, for every place that does; the menu lines Archive and Delete; a card's menu (on the Character page in groups under rules); `cover`, a
// card's picture in a line of a list; `lorebookRow`, a lorebook's line with its ×; `addLorebookMenu`, the "+" that offers the library's lorebooks in a
// chat's side panel and on a card's page, a menu with the class `long`: no wider than the chat's panel, its
// names on several lines, and scrolling from `--menu-long` on; `exportChatLine`, the menu line "Export" of a
// chat, and `exported`, which hands a file over to be saved and words the notice, for a card and a chat;
// `documentItem`, the menu line "Add a document" of a card; `documentKind`, what a document is by its file's ending.
import { isArt } from "../art";
import { addCardDocument, cardThumbnailUrl, changeCard, exportCard, exportChat, getSettings, startChat, type Download } from "../api/client";
import type { CardSummary } from "../api/generated/CardSummary";
import type { DocumentView } from "../api/generated/DocumentView";
import type { CharacterRef } from "../api/generated/CharacterRef";
import type { Flags } from "../api/generated/Flags";
import type { Lorebook } from "../api/generated/Lorebook";
import { announce, el } from "../dom";
import { menu, type MenuItem } from "../dialogs";
import { save } from "../storage";
import { icon } from "../icons";
import { companionItem } from "./companion-app";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";

/** Runs an action of a screen; see `oneAtATime`. */
type Run = (action: () => Promise<void>) => Promise<unknown>;

/**
 * The menu line "Add document": asks for one file of the kinds a document is read from, a field put into `place`
 * for as long as it asks, gives it with `send`, and says to whom it went (`to`: "the chat", a card's title).
 */
export function documentItem(place: HTMLElement, send: (file: File) => Promise<DocumentView>, to: string, run: Run): MenuItem {
  return {
    label: wording("library-actions-add-document"),
    sub: wording("library-actions-add-document-sub"),
    shape: "document",
    action: () => {
      const field = el("input", { type: "file", accept: ".txt,.md,.markdown,.pdf,.docx", hidden: true });
      field.oncancel = () => field.remove();
      field.onchange = () => {
        const [file] = field.files ?? [];
        field.remove();
        if (!file) return;
        void run(async () => {
          const added = await send(file);
          announce(wording("library-actions-document-added", { name: added.name, to }));
        });
      };
      place.append(field);
      field.click();
    },
  };
}

/** What a document is, by its file's ending: "PDF", "Word", "Markdown" or "Text". */
export function documentKind(name: string): string {
  const ending = name.split(".").pop()?.toLowerCase() ?? "";
  if (ending === "pdf") return wording("library-actions-kind-pdf");
  if (ending === "docx") return wording("library-actions-kind-word");
  return ending === "md" || ending === "markdown" ? wording("library-actions-kind-markdown") : wording("library-actions-kind-text");
}

/**
 * A card's picture as a line of a list draws it (`.cover`, or `size`, e.g. `cover-sm`), asked for in the size made
 * for that; a card without art gets a plain grey box in its place (`.cover-blank`), as a line keeps its picture's room.
 */
export function cover(versionId: number, size = ""): HTMLImageElement {
  const shown = el("img", { className: `cover ${size}`.trim(), src: cardThumbnailUrl(versionId, "row"), alt: "", loading: "lazy" });
  const blank = () => shown.replaceWith(el("span", { className: ["cover", size, "cover-blank"].filter(Boolean).join(" ") }));
  shown.onload = () => {
    if (!isArt(shown)) blank();
  };
  shown.onerror = blank;
  return shown;
}

/**
 * The star that makes an item a favorite or takes that back. `set` changes the
 * item and answers with it as it is then; `changed` is called after that.
 */
export function starButton(
  item: { favorite: boolean },
  set: (favorite: boolean) => Promise<{ favorite: boolean }>,
  run: Run,
  size = 18,
  changed?: () => Promise<void>,
): HTMLButtonElement {
  const star = el("button", { type: "button", className: "quiet icon star btn btn-quiet btn-icon", ariaLabel: wording("library-actions-favourite") }, icon("star", size));
  // The name stays "Favourite", pressed or not; the tooltip says what a click does.
  const mark = () => {
    star.ariaPressed = String(item.favorite);
    star.title = item.favorite ? wording("header-remove-from-favourites") : wording("header-add-to-favourites");
  };
  mark();
  star.onclick = () =>
    run(async () => {
      item.favorite = (await set(!item.favorite)).favorite;
      mark();
      await changed?.();
    });
  return star;
}

/** What a change did to an item, as its notice says it. */
type Done = "archived" | "unarchived" | "trashed";

/** The notice of what was `done` to the item called `title`. */
function doneTo(title: string, done: Done): string {
  if (done === "archived") return wording("library-actions-done-archived", { title });
  return done === "unarchived" ? wording("library-actions-done-unarchived", { title }) : wording("library-actions-done-trashed", { title });
}

/** Makes a change to an item called `title` and says what was `done`, with the way `back`. */
type Put = (flags: Flags, back: Flags, done: Done) => Promise<unknown>;

/** Makes the [`Put`] of an item: `change` makes a change and shows the screen anew. */
export function undoable(title: string, run: Run, change: (flags: Flags) => Promise<void>): Put {
  return (flags, back, done) =>
    run(async () => {
      await change(flags);
      announce(doneTo(title, done), () => change(back));
    });
}

/**
 * Starts a chat with characters of cards' versions, in speaking order, and shows it: the first is the one the chat
 * is called after, and one of its greetings, the `greeting`th, is in view; the user is `persona`, else the default.
 */
export async function beginChat(characters: CharacterRef[], greeting?: number, persona?: number): Promise<void> {
  const { chat } = await startChat({ characters, greeting, persona_id: persona });
  location.hash = `#/chats/${chat.id}`;
}

/** The menu line that archives an item, or takes it back out. */
export const archiveLine = (archived: boolean, put: Put): MenuItem =>
  archived
    ? { label: wording("library-actions-unarchive"), shape: "archive", action: () => put({ archived: false }, { archived: true }, "unarchived") }
    : { label: wording("library-actions-archive"), shape: "archive", action: () => put({ archived: true }, { archived: false }, "archived") };

/** The menu line "Delete", which does `action`: the last of its menu, under a rule, and red. */
export const deleteItem = (action: () => void): MenuItem => ({ label: wording("common-delete"), shape: "trash", danger: true, apart: true, action });

/** The menu line "Move to Trash", which does `action`, for what can come back from the Trash: placed as "Delete". */
export const trashItem = (action: () => void): MenuItem => ({ ...deleteItem(action), label: wording("card-box-move-to-trash") });

/** The menu line that moves an item to the Trash. */
export const deleteLine = (put: Put): MenuItem => trashItem(() => put({ trashed: true }, { trashed: false }, "trashed"));

/** A lorebook's line in a box of lorebooks: its name, " · in Trash" where it is `trashed`, and its ×, `remove`. */
export const lorebookRow = (name: string, trashed: boolean, remove: HTMLButtonElement): HTMLElement =>
  el("li", { className: "row bline" }, el("span", { className: "f-grow" }, name, trashed && el("span", { className: "meta" }, wording("library-actions-in-trash"))), remove);

/**
 * "Add a lorebook": the lorebooks of the library `toTake`, each to `take`, or the
 * way to the library when it has none to give.
 */
export function addLorebookMenu(toTake: Lorebook[], take: (lorebook: Lorebook) => void): HTMLElement {
  const lines = toTake.map((lorebook) => ({ label: lorebook.name, action: () => take(lorebook) }));
  const toLibrary = { label: wording("library-actions-import-lorebooks-in-the"), action: () => void (location.hash = "#/library/lorebooks") };
  const add = menu(wording("library-actions-add-lorebook"), lines.length ? lines : [toLibrary], "plus", 16);
  add.classList.add("long");
  return add;
}

/** One of a card's characters: its ID in the card and the name it has in a chat. */
type Character = { id: string; name: string };

/**
 * Hands a file over to be saved. Answers how a notice says so of `what`: that it was exported, and where to when that
 * is known; with `alone`, the one character a SillyTavern card holds.
 */
export function exported(what: string, { name, file }: Download, alone?: string): string {
  const folder = save(name, file);
  if (alone) return folder ? wording("library-actions-exported-to-alone", { what, folder, alone }) : wording("library-actions-exported-alone", { what, alone });
  return folder ? wording("library-actions-exported-to", { what, folder }) : wording("library-actions-exported", { what });
}

/**
 * Saves a card as a file, in the format chosen in the settings, and says where
 * to when that is known. A SillyTavern card holds one character: the one given,
 * or else the card's first.
 */
async function exportTo(card: CardSummary, character?: Character): Promise<void> {
  const [{ export_format }, file] = await Promise.all([getSettings(), exportCard(card.id, character?.id)]);
  const alone = export_format === "sillytavern_v3" && card.names.length > 1 && (character?.name ?? card.names[0]);
  announce(exported(wording("library-actions-quoted", { name: cardTitle(card.title) }), file, alone || undefined));
}

/**
 * The menu line that saves a chat as a file SillyTavern opens as a chat, and
 * says so of `what`, which is how the screen's notices call the chat.
 */
export const exportChatLine = (chatId: number, what: string, run: Run): MenuItem => ({
  label: wording("library-actions-export"),
  shape: "export",
  action: () => run(async () => announce(exported(what, await exportChat(chatId)))),
});

/**
 * The lines of a card's menu (board "Card's picture"): in the desktop app make it the companion, add a document,
 * export it, archive it or take it back out, and delete it. `reload` shows the screen anew after a change. Deleting moves the
 * card to the trash; a screen that cannot go on showing it passes its own
 * `remove`. A screen that shows one of the card's characters names it, for the export.
 */
export function cardItems(
  card: CardSummary,
  run: Run,
  reload: () => Promise<void>,
  remove?: () => void,
  character?: Character,
): MenuItem[] {
  const put = undoable(cardTitle(card.title), run, async (flags) => {
    await changeCard(card.id, flags);
    await reload();
  });
  const companion = companionItem(card, run);
  const add = documentItem(document.body, (file) => addCardDocument(card.id, file), cardTitle(card.title), run);
  const exported: MenuItem = { label: wording("library-actions-export-card"), shape: "export", action: () => run(() => exportTo(card, character)) };
  // The Character page's menu in its own order (design.md, "Card page"); the library's as its rows' "…" (design.md, "List rows").
  // There Add a document ends the "Add …" group, and the card's own lines stand under a rule of their own.
  if (remove) return [add, ...[...companion, exported, archiveLine(card.archived, put)].map((item, at) => ({ ...item, apart: at === 0 })), trashItem(remove)];
  return [archiveLine(card.archived, put), exported, add, ...companion, deleteLine(put)];
}
