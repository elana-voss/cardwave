// The lorebook editor's state (`Book`), which views/lorebook.ts makes, and its entry's column (`drawEntry`, with
// "More settings" in `morePart`): each part is saved as it is left, as a card's texts are, with no Save and no
// Cancel. The name is written where it stands (`inPlace`), as is Content, a card's text block with its AI tools
// and versions (`textBlock` of card-block.ts, its `CardPage` the entry). The entry's "…" has Rename and "Delete
// entry" (`drop`, with the notice's Undo). A new entry is kept once it has a name (`drawNew`).
//
// Saves go one after the other (`saveEntry`, `Book.queue`), so a keyword and a switch changed quickly are both
// kept; why one failed stands over the editor. The header's AI tools' changes waiting for Keep stand over the
// entry (`proposalBox` of lore-tools.ts).
import { addEntry, changeEntry, entryDrafts, removeEntry, restoreEntry, type LoreOf } from "../api/client";
import type { EditEntry } from "../api/generated/EditEntry";
import type { EntryChange } from "../api/generated/EntryChange";
import type { LorebookEdit } from "../api/generated/LorebookEdit";
import type { SelectiveLogic } from "../api/generated/SelectiveLogic";
import type { Trigger } from "../api/generated/Trigger";
import { textBlock, type CardPage } from "../card/card-block";
import { inPlace } from "../in-place";
import { announce, el, failure, NARROW, reason, segmented, switchBox } from "../dom";
import { menu } from "../dialogs";
import { count, field } from "../edit-form";
import { keys, NEW, said } from "./entry";
import { icon } from "../icons";
import { proposalBox, type Proposal } from "./lore-tools";
import { MAX_NAME } from "./lorebook-dialog";
import { wording } from "../language/language";

/** The editor of one lorebook: what it shows, and its parts. */
export interface Book {
  /** Which lorebook it is: of the library, or a card's own. */
  readonly of: LoreOf;
  /** The lorebook's address, and the entry it names. */
  readonly base: string;
  at: string | null;
  /** The lorebook as the server gave it. */
  book: LorebookEdit | null;
  /** Whether "More settings" is open. It stays so from one entry to the next. */
  more: boolean;
  /** The entry the column was drawn of, as it read then: `null` for none, and nothing before it was drawn. */
  drawn: string | null | undefined;
  /** The saves on their way, one after the other. */
  queue: Promise<void>;
  /** Aborted as the page is left: an AI tool on its way, the whole lorebook's or Content's, asks the model no more. */
  readonly leaving: AbortController;
  /** The changes of the header's AI tools that wait for Keep or Undo, by entry. */
  proposed: Map<string, Proposal>;
  readonly node: HTMLElement;
  readonly page: HTMLElement;
  readonly notice: HTMLElement;
  /** The bar over the entry of the header's AI tools (lore-tools.ts). */
  readonly bar: HTMLElement;
  readonly column: HTMLElement;
  readonly lines: HTMLElement;
  attempt(action: () => Promise<void>, name?: string): Promise<boolean>;
  /** Reads the lorebook anew, and draws its list. */
  reload(): Promise<void>;
  /** Shows the entry the address names: its line marked, and its column. */
  show(): void;
  /** Draws the list's lines and the entry's column anew, where it is. */
  redraw(): void;
}

/** What the triggers are called, in the order they are offered. */
const triggers = (): [Trigger, string][] => ([
  ["keyword", wording("lorebook-entry-keywords")],
  ["always", wording("lorebook-entry-always")],
  ["vector", wording("lorebook-entry-by-meaning")],
]);

/** What the secondary keywords may ask for. */
const logics = (): [SelectiveLogic, string][] => ([
  ["and_any", wording("lorebook-entry-any-of-these")],
  ["and_all", wording("lorebook-entry-all-of-these")],
  ["not_any", wording("lorebook-entry-none-of-these")],
  ["not_all", wording("lorebook-entry-not-all-of-these")],
]);

/** A choice of several under its name, with what is to be said of it under it. */
const choice = (name: string, control: HTMLElement, hint?: string): HTMLElement =>
  el("div", { className: "fld" }, el("span", { className: "label" }, name), control, hint && el("p", { className: "meta" }, hint));

/** A switch with what it does at its left, as wide as the column. */
function flag(name: string, on: boolean, set: (on: boolean) => void): HTMLElement {
  const toggle = switchBox({ checked: on });
  toggle.onchange = () => set(toggle.checked);
  return el("label", { className: "flex ai-c jc-sb" }, el("span", { className: "label" }, name), toggle);
}

export const address = (b: Book, reference: string | null) => (reference === null ? b.base : `${b.base}/${encodeURIComponent(reference)}`);

/** The entry `reference` as last read. */
export const entryAt = (b: Book, reference: string) => b.book?.entries.find((entry) => entry.reference === reference) ?? null;

/** The entry in view: the one the address names, or the first; none where the lorebook has none, or not that one. */
export function current(b: Book): EditEntry | null {
  if (!b.book) return null;
  if (b.at === NEW) return b.book.blank;
  return (b.at === null ? b.book.entries[0] : entryAt(b, b.at)) ?? null;
}

/** The words under an entry's name in the list, with whether an AI change of it waits. */
export const under = (b: Book, entry: EditEntry) => (b.proposed.has(entry.reference) ? wording("lorebook-entry-ai-change", { said: said(entry) }) : said(entry));

/** The link of an entry's line. */
export const linkOf = (b: Book, reference: string) => [...b.lines.querySelectorAll<HTMLAnchorElement>(".entry-link")].find((link) => link.dataset.reference === reference);

/** Shows the entry `reference` without a new step in the history: the address before names what is gone. */
export function place(b: Book, reference: string | null): void {
  history.replaceState(null, "", address(b, reference));
  b.at = reference;
  b.show();
}

/**
 * Saves `change` of the entry `reference` after the saves before it, its new words a version made by `made`, and
 * reads the lorebook anew. Why it failed stands over the editor; the answer fails then too.
 */
export function saveEntry(b: Book, reference: string, change: EntryChange, made?: string): Promise<void> {
  const done = b.queue.then(async () => {
    await changeEntry(b.of, reference, change, made);
    await b.reload();
    // What was saved is what the column shows: it is not drawn anew for it.
    if (current(b)?.reference === reference) b.drawn = JSON.stringify(current(b));
  });
  b.queue = done.catch((error) => void b.notice.replaceChildren(failure(reason(error))));
  return done;
}

/** Draws the column of the entry in view anew. */
export function drawEntry(b: Book): void {
  if (!b.book) return;
  b.column.hidden = false;
  const given = current(b);
  b.drawn = given && JSON.stringify(given);
  if (!given) {
    b.column.replaceChildren(el("p", { className: "meta" }, b.at === null ? wording("lorebook-entry-this-lorebook-has-no") : wording("lorebook-entry-this-lorebook-has-no-2")));
    return;
  }
  if (b.at === NEW) return drawNew(b);
  const reference = given.reference;
  const entry = structuredClone(given);
  const put = (change: EntryChange) => void saveEntry(b, reference, change).catch(() => undefined);
  const keywords = keys(wording("lorebook-entry-keywords"), wording("lorebook-entry-add-a-keyword"), entry.keywords, () => put({ keywords: [...entry.keywords] }));
  // Keywords are what an entry is used by, but for one that is always used.
  const used = segmented(wording("lorebook-entry-used-when"), triggers(), entry.trigger, (trigger) => {
    keywords.hidden = trigger === "always";
    put({ trigger });
  });
  keywords.hidden = entry.trigger === "always";
  const parts = [
    entryHead(b, given),
    proposalBox(b, given),
    choice(
      wording("lorebook-entry-used-when"),
      used,
      wording("lorebook-entry-by-meaning-used-when"),
    ),
    keywords,
    contentBlock(b, reference),
    ...morePart(b, entry, put),
  ];
  b.column.replaceChildren(...parts.filter((part) => part !== null));
}

/** The entry's name, written where it stands, and its "…": Rename and Delete entry. */
function entryHead(b: Book, given: EditEntry): HTMLElement {
  const name = el("h2", { className: "entry-name m0 fs-title semi" });
  /** The name shown while its save waits: the entry read has it only once saved. */
  let held: string | null = null;
  const shown = () => held ?? entryAt(b, given.reference)?.label ?? given.label;
  const rename = inPlace(name, {
    label: wording("lorebook-entry-entry-name"),
    limit: MAX_NAME,
    value: () => held ?? (entryAt(b, given.reference)?.name || given.label),
    show: () => [shown()],
    // An entry keeps a name: one emptied is not saved.
    commit: (text) => {
      if (!text.trim()) return;
      held = text.trim();
      void saveEntry(b, given.reference, { name: held })
        .catch(() => undefined)
        .then(() => {
          held = null;
          if (!name.querySelector("input")) name.replaceChildren(shown());
        });
    },
  });
  const items = [
    { label: wording("voices-rename"), shape: "edit" as const, action: rename },
    { label: wording("lorebook-entry-delete-entry"), shape: "trash" as const, danger: true, action: () => void b.attempt(() => drop(b, given)) },
  ];
  return el("div", { className: "edit-head flex ai-c g-4" }, name, menu(wording("lorebook-entry-entry-menu"), items));
}

/** The entry's Content: a text block with its AI tools and versions, saved as it is left. */
function contentBlock(b: Book, reference: string): HTMLElement {
  const page: CardPage<EntryChange> = {
    card: () => 0,
    unsaved: (text) => `lorebook.${JSON.stringify(b.of)}.${text}`,
    save: async (change, made) => {
      const asked: EntryChange = {};
      change(asked);
      // Why it failed stands over the editor, and the block shows the words as they are kept.
      return saveEntry(b, reference, asked, made).then(
        () => true,
        () => false,
      );
    },
    drafts: (of) => entryDrafts(b.of, of),
    attempt: b.attempt,
    notice: b.notice,
    gone: b.leaving.signal,
    opened: new Set(),
  };
  return textBlock(page, {
    label: wording("lorebook-entry-content"),
    what: wording("lorebook-entry-what-the-ai-is"),
    about: wording("lorebook-entry-about"),
    read: () => entryAt(b, reference)?.content ?? "",
    write: (change, text) => (change.content = text),
    reference: () => reference,
  });
}

/** The column of a new entry: its name, written in the heading's place as a made entry's is, with which it is kept; a name that could not be kept is written there again, to be tried anew. */
function drawNew(b: Book): void {
  const heading = el("h2", { className: "entry-name m0 fs-title semi" });
  let adding = false;
  const add = (text: string) => {
    const name = text.trim();
    if (!name || adding) return;
    adding = true;
    void b.attempt(async () => {
      const added = await addEntry(b.of, { name });
      await b.reload();
      announce(wording("lorebook-entry-entry-added"));
      place(b, added.reference);
    }).then((done) => {
      adding = done;
      if (done || !heading.isConnected) return;
      begin();
      const field = heading.querySelector<HTMLInputElement>("input");
      if (field) field.value = text;
    });
  };
  const begin = inPlace(heading, {
    label: wording("lorebook-entry-entry-name"),
    placeholder: wording("lorebook-entry-name-the-entry"),
    limit: MAX_NAME,
    value: () => "",
    show: () => [el("span", { className: "c-faint" }, wording("lorebook-entry-name-the-entry"))],
    commit: add,
  });
  b.column.replaceChildren(el("div", { className: "edit-head flex ai-c g-4" }, heading), el("p", { className: "hint" }, wording("lorebook-entry-the-entry-is-kept")));
  begin();
}

/** "More settings": its opener, and position, depth, order, secondary keywords, probability, scan depth and matching, each saved as it is left. */
function morePart(b: Book, entry: EditEntry, put: (change: EntryChange) => void): HTMLElement[] {
  /** A field for a number, saved when it is left with a right one; a wrong one is red with its range (`count`). */
  const number = <K extends "depth" | "order" | "probability" | "scan_depth">(what: K, value: number | null, limits: Parameters<typeof count>[2]) => {
    let typed: number | null = null;
    const node = count(value, (now) => (typed = now), limits);
    node.onchange = () => {
      if (!node.validity.valid) return;
      if (typed !== null) put({ [what]: typed });
      typed = null;
    };
    return node;
  };
  const deep = number("depth", entry.depth, { least: 0 });
  const depth = field(wording("prompt-depth"), deep, [], wording("lorebook-entry-how-many-messages-before"));
  depth.hidden = !entry.at_depth;
  const places: [boolean, string][] = [
    [false, wording("lorebook-entry-with-the-character")],
    [true, wording("lorebook-entry-at-depth-in-the")],
  ];
  const position = segmented<boolean>(wording("lorebook-entry-position"), places, entry.at_depth, (at_depth) => {
    depth.hidden = !at_depth;
    put({ at_depth });
  });
  const logic = segmented(wording("lorebook-entry-secondary-count"), logics(), entry.logic, (logic) => put({ logic }));
  // Without secondary keywords there is nothing to choose.
  const secondHint = el("p", { className: "meta" }, wording("lorebook-entry-a-keyword-alone-is"));
  const second = keys(
    wording("lorebook-entry-secondary-keywords"),
    wording("lorebook-entry-add-a-keyword"),
    entry.secondary,
    () => {
      logic.hidden = entry.secondary.length === 0;
      put({ secondary: [...entry.secondary] });
    },
    logic,
    secondHint,
  );
  logic.hidden = entry.secondary.length === 0;
  const rest = el(
    "div",
    { className: "flex f-col g-20", id: "entry-more", hidden: !b.more },
    choice(wording("lorebook-entry-position"), position, wording("lorebook-entry-where-the-ai-reads")),
    depth,
    field(wording("lorebook-entry-order"), number("order", entry.order, {}), [], wording("lorebook-entry-entries-with-a-higher")),
    second,
    field(wording("lorebook-entry-chance"), number("probability", entry.probability, { least: 0, most: 100 }), [], wording("lorebook-entry-the-chance-that-the")),
    field(wording("lorebook-dialog-messages-searched"), number("scan_depth", entry.scan_depth || null, { least: 1, empty: 0 }), [], wording("lorebook-entry-how-many-of-the")),
    flag(wording("lorebook-entry-case-sensitive"), entry.case_sensitive, (case_sensitive) => put({ case_sensitive })),
    flag(wording("lorebook-entry-whole-words"), entry.whole_words, (whole_words) => put({ whole_words })),
  );
  const opener = el("button", { type: "button", className: "textbtn as-s" }, icon(b.more ? "up" : "down", 14), wording("lorebook-entry-more-settings"));
  opener.setAttribute("aria-expanded", String(b.more));
  opener.setAttribute("aria-controls", rest.id);
  opener.onclick = () => {
    b.more = !b.more;
    rest.hidden = !b.more;
    opener.setAttribute("aria-expanded", String(b.more));
    opener.firstElementChild?.replaceWith(icon(b.more ? "up" : "down", 14));
  };
  return [opener, rest];
}

/** Takes an entry out of the lorebook, and says so with the way back. */
async function drop(b: Book, entry: EditEntry): Promise<void> {
  const index = b.book?.entries.findIndex((other) => other.reference === entry.reference) ?? 0;
  await b.queue;
  const removed = await removeEntry(b.of, entry.reference);
  b.proposed.delete(entry.reference);
  await b.reload();
  // The entry that took its place is in view, or the last; the list, where that is a screen of its own.
  const next = b.book?.entries[Math.min(index, b.book.entries.length - 1)];
  const after = NARROW.matches ? null : (next?.reference ?? null);
  place(b, after);
  announce(wording("lorebook-entry-entry-deleted", { label: entry.label }), async () => {
    const back = await restoreEntry(b.of, removed);
    await b.reload();
    const to = NARROW.matches ? null : back.reference;
    // Where the deletion left the screen, the entry put back takes that place in the history; from where the
    // user has gone on to since, it is a step of its own, and the way back leads there again.
    if (b.at === after || location.hash === address(b, to)) place(b, to);
    else location.hash = address(b, to);
  });
}
