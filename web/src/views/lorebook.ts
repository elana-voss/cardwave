// A lorebook's editor, one screen for a lorebook of the library (`#/library/lorebooks/{id}[/{reference}|/new]`,
// path "Lorebooks / [name]") and a card's own (`#/library/{card}/lorebook[...]`, or `…/{card}/lorebook.ID[...]`
// for one that is not the card's first; path "Characters / [card] / [name] · this card's own"): its entries
// listed and searched at the right, the one chosen in the middle. The screen stays from one entry to the next
// (`View.moved`), keeping the list's place, the focus and the notice. From 960 px down list and entry are screens
// of their own, by app.css alone (`.at-entry`).
//
// The entry's column, saved part by part as it is left, is ../lorebook/lorebook-entry.ts's; the header's AI tools for the
// whole lorebook are ../lorebook/lore-tools.ts's. A switch in the list is saved at once. The event `lorebook` (of one of
// the library), `card` (of a card's own) and a drop of the server have it read anew (`refresh`): the column is drawn anew only where its
// entry reads otherwise, and not while a field in it is written in (then when it is left). A reading older than
// one taken is dropped (`reload`). What it decides without showing is ../lorebook/entry.ts.
// The header: "Lorebook settings" (../lorebook/lorebook-dialog.ts), the AI tools, and of one of the library the star and
// "…" (Archive, Export, Delete; deleted, the editor gives way to the list), of a card's own "…" with Copy to
// library, Move to library and Export (../card/lore-own.ts; moved, the editor gives way to the library's lorebook).
import { changeLorebook, describeLorebook, exportLorebook, getLorebookEdit, type LoreOf } from "../api/client";
import type { EditEntry } from "../api/generated/EditEntry";
import type { LorebookEdit } from "../api/generated/LorebookEdit";
import { announce, el, failure, newest, noticeBox, oneAtATime, reason, searchField, switchBox, titled, type View } from "../dom";
import { menu } from "../dialogs";
import { entryOf, matches, NEW } from "../lorebook/entry";
import { icon } from "../icons";
import { archiveLine, deleteLine, exported, starButton, undoable } from "../library/library-actions";
import { lorebookAddress, ownLines } from "../card/lore-own";
import { loreTools } from "../lorebook/lore-tools";
import { aboutDialog } from "../lorebook/lorebook-dialog";
import { address, current, drawEntry, linkOf, saveEntry, under, type Book } from "../lorebook/lorebook-entry";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";

/** The editor's header and list, which its drawing reaches beside the entry's column. */
interface Editor extends Book {
  /** The path's parts that the lorebook names: the card's, and the lorebook's. */
  crumbs: HTMLElement;
  name: HTMLElement;
  about: HTMLButtonElement;
  /** The AI tools, the star and "…" of the header, made once the lorebook is read. */
  marks: HTMLElement;
  counted: HTMLElement;
  add: HTMLButtonElement;
  /** What the list is searched for. */
  asked: { q: string };
  /** The readings of the lorebook: one answered after a later one is not taken. */
  readings: ReturnType<typeof newest>;
  /** Why the lorebook could not be read anew, while it stands over the entry. */
  unread: HTMLElement | null;
}

/** The editor of the lorebook `of`, with the entry the address names in view. */
export function lorebookView(of: LoreOf): View {
  const b = editor(of);
  void b.attempt(async () => {
    await reload(b);
    show(b);
    // The entry an address named may be far down the list.
    b.lines.querySelector("[aria-current]")?.scrollIntoView({ block: "nearest" });
  });
  // A change made elsewhere while a field was written in shows once it is left.
  b.column.addEventListener("focusout", (event) => {
    if (b.column.contains(event.relatedTarget as Node | null)) return;
    const given = current(b);
    if (b.drawn !== undefined && (given && JSON.stringify(given)) !== b.drawn) requestAnimationFrame(() => drawEntry(b));
  });
  return {
    node: b.node,
    // A change made in another window, and what may have been changed while the server was not heard.
    onEvent: (event) =>
      void (("library" in of ? event.type === "lorebook" && event.id === of.library : event.type === "card" && event.id === of.card) && reread(b)),
    onConnected: () => void reread(b),
    left: () => b.leaving.abort(),
    // From one entry of the lorebook to the next, the screen stays.
    moved() {
      if (location.hash !== b.base && !location.hash.startsWith(`${b.base}/`)) return false;
      b.at = entryOf(location.hash);
      show(b);
      return true;
    },
  };
}

/** Makes the editor's parts and state. */
function editor(of: LoreOf): Editor {
  const base = lorebookAddress(of);
  const asked = { q: "" };
  const name = el("a", { className: "cut here", href: base }, wording("page-lorebook"));
  const crumbs = el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, name);
  const about = el("button", { type: "button", className: "btn btn-quiet btn-fit", disabled: true, onclick: () => describe(b) }, icon("edit", 16), wording("lorebook-lorebook-settings"));
  const marks = el("div", { className: "flex ai-c g-2" });
  const notice = noticeBox();
  const bar = el("div", { className: "banner lore-bar", role: "status", hidden: true });
  const column = el("section", { className: "entry-form w100 flex f-col g-20 mt-8", ariaLabel: wording("lorebook-entry") });
  const page = el(
    "div",
    { className: "main main-form rel" },
    el("header", { className: "pbar" }, crumbs, el("div", { className: "rel flex ai-c g-2" }, about, marks)),
    notice,
    bar,
    column,
  );
  const counted = el("span", { className: "label panel-label" }, wording("lorebook-entries"));
  const add = el("button", { type: "button", className: "btn btn-quiet btn-fit", disabled: true, onclick: () => (location.hash = address(b, NEW)) }, icon("plus", 16), wording("lorebook-new-entry"));
  const lines = el("ul", { className: "rows-plain" });
  const panel = el(
    "aside",
    { className: "lore-entries side-panel bb flex f-col g-12", ariaLabel: wording("lorebook-entries") },
    el("div", { className: "flex ai-c jc-sb" }, counted, add),
    searchField(wording("lorebook-find-an-entry"), wording("lorebook-find-an-entry"), asked, () => drawLines(b), "w100 bb"),
    el("div", { className: "entry-heads flex jc-sb", ariaHidden: "true" }, el("span", { className: "meta fs-caption" }, wording("lorebook-entry")), el("span", { className: "meta fs-caption" }, wording("lorebook-on"))),
    lines,
  );
  const b: Editor = {
    of,
    base,
    at: entryOf(location.hash),
    book: null,
    more: false,
    drawn: undefined,
    queue: Promise.resolve(),
    leaving: new AbortController(),
    proposed: new Map(),
    node: el("section", { className: "lorebook flex" }, page, panel),
    page,
    notice,
    bar,
    column,
    lines,
    attempt: oneAtATime(notice),
    reload: () => reload(b),
    show: () => show(b),
    redraw: () => {
      drawLines(b);
      drawEntry(b);
    },
    crumbs,
    name,
    about,
    marks,
    counted,
    add,
    asked,
    readings: newest(),
    unread: null,
  };
  return b;
}

/**
 * Reads the lorebook anew, and draws its list. The column is drawn by who
 * calls: the list's lines and the column are of the same entries, as read.
 */
async function reload(b: Editor): Promise<void> {
  const mine = b.readings.ask();
  const read = await getLorebookEdit(b.of);
  // A later reading was taken already: this one is older.
  if (!b.readings.take(mine)) return;
  const first = b.book === null;
  b.book = read;
  b.name.textContent = read.name;
  titled(b.node, read.name);
  b.about.disabled = b.add.disabled = false;
  if (first) drawPath(b, read);
  drawMarks(b, read);
  b.counted.textContent = wording("lorebook-entries-2", { count: read.entries.length });
  // A change waiting for an entry that is gone waits no longer.
  for (const reference of b.proposed.keys()) if (!read.entries.some((entry) => entry.reference === reference)) b.proposed.delete(reference);
  drawLines(b);
}

/** The path: "Lorebooks / [name]", or of a card's own "Characters / [card] / [name] · this card's own". */
function drawPath(b: Editor, read: LorebookEdit): void {
  const card = read.card;
  if (!card) return b.crumbs.replaceChildren(el("a", { href: "#/library/lorebooks" }, wording("page-lorebooks")), "/", b.name);
  b.crumbs.replaceChildren(
    el("a", { href: "#/library" }, wording("page-characters")),
    "/",
    el("a", { className: "cut", href: `#/library/${card.card_id}` }, cardTitle(card.title)),
    "/",
    b.name,
    el("span", { className: "meta" }, wording("lorebook-this-cards-own")),
  );
}

/** An entry's line in the list: its link, with what is said of it, and its switch, saved at once. */
function entryLine(b: Editor, entry: EditEntry): HTMLElement {
  const toggle = switchBox({ checked: entry.enabled, ariaLabel: wording("lorebook-on-2", { label: entry.label }), title: wording("lorebook-use-this-entry") });
  toggle.onchange = async () => {
    const on = toggle.checked;
    // In line with the other saves (`saveEntry`): a keyword typed just before is kept first.
    const set = await b.attempt(() => saveEntry(b, entry.reference, { enabled: on }), entry.label);
    if (!set) toggle.checked = entry.enabled;
  };
  const link = el("a", { className: "entry-link ink-link item-text", href: address(b, entry.reference) }, el("span", { className: "entry-label item-label" }, entry.label), el("span", { className: "meta ellipsis" }, under(b, entry)));
  link.dataset.reference = entry.reference;
  return el("li", { className: "entry-line item row item-side item-line g-10" }, link, toggle);
}

/** The line of the new entry while it is named: "New entry", marked. */
function newLine(b: Editor): HTMLElement {
  const link = el("a", { className: "entry-link ink-link item-text", href: address(b, NEW) }, el("span", { className: "entry-label item-label" }, wording("lorebook-new-entry")));
  link.dataset.reference = NEW;
  return el("li", { className: "entry-line item row item-side item-line g-10" }, link);
}

/** Draws the list anew: the entries the search leaves, with the one in view marked. */
function drawLines(b: Editor): void {
  if (!b.book) return;
  const found = b.book.entries.filter((entry) => matches(entry, b.asked.q));
  const none = b.book.entries.length === 0 ? wording("lorebook-no-entries-yet") : wording("lorebook-no-entry-found");
  // The focus stays on the line it was on, on its link or its switch: the lines are drawn anew after a change
  // made in another window too.
  const had = document.activeElement;
  const focused = had instanceof HTMLElement && b.lines.contains(had) ? had.closest("li")?.querySelector<HTMLElement>(".entry-link")?.dataset.reference : undefined;
  const onSwitch = had instanceof HTMLElement && had.matches(".switch");
  // A new entry being named has its line at the end, where it is kept, marked as the one in view.
  const adding = b.at === NEW ? [newLine(b)] : [];
  b.lines.replaceChildren(...found.map((entry) => entryLine(b, entry)), ...(found.length === 0 && !adding.length ? [el("li", { className: "meta none" }, none)] : []), ...adding);
  if (focused !== undefined) {
    const link = linkOf(b, focused);
    (onSwitch ? link?.parentElement?.querySelector<HTMLElement>(".switch") : link)?.focus();
  }
  mark(b);
}

/** Marks the line of the entry in view, and none else. */
function mark(b: Editor): void {
  const chosen = b.at === NEW ? NEW : current(b)?.reference;
  for (const link of b.lines.querySelectorAll<HTMLAnchorElement>(".entry-link")) link.ariaCurrent = link.dataset.reference === chosen ? "true" : null;
}

/** Shows the entry the address names: its line marked, and its column. */
function show(b: Editor): void {
  b.node.classList.toggle("at-entry", b.at !== null);
  // Drawn anew, not only marked: the new entry's line comes and goes with its address.
  drawLines(b);
  drawEntry(b);
  b.page.scrollTo({ top: 0 });
}

/**
 * Reads the lorebook anew, after a change made in another window or after a drop: the list shows it as it reads
 * now, and so does the column where its entry reads otherwise, unless a field in it is written in.
 */
async function refresh(b: Editor): Promise<void> {
  await reload(b);
  // A column that was never drawn, as its first reading failed, is shown as the address names it, and why that
  // reading failed is said no longer.
  if (b.drawn === undefined) {
    b.notice.replaceChildren();
    return show(b);
  }
  const given = current(b);
  if ((given && JSON.stringify(given)) === b.drawn) return;
  if (b.column.contains(document.activeElement)) return;
  drawEntry(b);
}

/** `refresh`, with why it failed over the entry until a reading does not fail. */
const reread = (b: Editor) =>
  refresh(b).then(
    () => {
      b.unread?.remove();
      b.unread = null;
    },
    (error) => {
      b.unread = failure(reason(error));
      b.notice.replaceChildren(b.unread);
    },
  );

/** The header's AI tools, star and "…" of the lorebook as read: a card's own has no star, Archive or Delete. */
function drawMarks(b: Editor, read: LorebookEdit): void {
  const act = (action: () => Promise<void>) => b.attempt(action, read.name);
  const exportLine = { label: wording("library-actions-export"), shape: "export" as const, action: () => act(async () => announce(exported(wording("library-actions-quoted", { name: read.name }), await exportLorebook(b.of)))) };
  const tools = b.marks.querySelector(".lore-tools") ?? loreTools(b);
  tools.classList.add("lore-tools");
  if (!("library" in b.of)) {
    // Moved, it is the library's: its editor is shown, and its Undo shows the card's own again.
    const lines = read.card ? ownLines(read.card, act, (moved) => void (moved && (location.hash = moved))) : [];
    b.marks.replaceChildren(tools, menu(wording("lorebook-lorebook-menu"), [...lines, { ...exportLine, apart: true }]));
    return;
  }
  const id = b.of.library;
  const put = undoable(read.name, act, async (flags) => {
    await changeLorebook(id, flags);
    // Moved to the Trash, it has no editor: the list of lorebooks is shown, where the notice's Undo is.
    if (flags.trashed) location.hash = "#/library/lorebooks";
    else await reload(b);
  });
  b.marks.replaceChildren(tools, starButton(read, (favorite) => changeLorebook(id, { favorite }), act), menu(wording("lorebook-lorebook-menu"), [archiveLine(read.archived, put), exportLine, deleteLine(put)]));
}

/** Opens "Lorebook settings": the lorebook's name, description, scan depth and token budget, and of one of the library "Use in every chat". */
function describe(b: Editor): void {
  const book = b.book;
  if (!book) return;
  aboutDialog(
    b.node,
    wording("lorebook-lorebook-settings"),
    book.name,
    book.description,
    async (called, described, box, numbers) => {
      await b.queue;
      await describeLorebook(b.of, { name: called, description: described, ...numbers });
      // As they are kept. The entries stay those the list and the column are of: read anew, a switch of
      // the list would be set of one entry and the column show another.
      const kept = await getLorebookEdit(b.of);
      if (b.book) Object.assign(b.book, { name: kept.name, description: kept.description, scan_depth: kept.scan_depth, token_budget: kept.token_budget, everywhere: kept.everywhere });
      b.name.textContent = kept.name;
      titled(b.node, kept.name);
      box.close();
    },
    { ...book, everywhere: "library" in b.of ? book.everywhere : undefined },
  );
}
