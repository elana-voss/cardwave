// The box on a card's page: the card's chats, its lorebooks, its expressions (card-expressions.ts) and its 3D figure
// (card-figure.ts), each a part whose first lines show until its chevron opens the rest (`part`). An empty part is
// left out, and the box with all of them; the card menu's "Add a lorebook", "Add expressions" and "Add a 3D figure"
// (`addLines`) show the part and press its "+" (`addTo`), and it stays while the page is open. A lorebook the card
// brings leads to its editor and can be copied into the library; one of the library is attached with "+" and
// detached with its ×.
import { attachLorebook, changeChat, copyLorebook, detachLorebook, libraryLorebooks } from "../api/client";
import type { CardLorebook } from "../api/generated/CardLorebook";
import type { Chat } from "../api/generated/Chat";
import { load, type Card } from "./card-page";
import { announce, el, lineButton } from "../dom";
import { chatTitle } from "../chat-title";
import { ago, moment } from "../format";
import { icon } from "../icons";
import type { MenuItem } from "../dialogs";
import { addLorebookMenu, lorebookRow } from "../library/library-actions";
import { expressionsPart } from "./card-expressions";
import { figurePart } from "./card-figure";
import { lorebookAddress } from "./lore-own";
import { wording } from "../language/language";

/** How many lines of a part of the card's box show before the part is opened. */
const SHOWN_LINES = 3;

/** Draws the box anew. A control named `focus` has the focus then. */
export function drawBox(c: Card, focus?: string): void {
  const redraw = (focus: string) => drawBox(c, focus);
  const expressions = expressionsPart(c, redraw);
  const figure = figurePart(c, redraw);
  c.box.replaceChildren(
    ...[
      chatsPart(c),
      lorebooksPart(c),
      shows(c, "expressions", expressions.rows) && part(c, "expressions", wording("card-box-expressions"), expressions.rows, expressions.tools, wording("card-box-expressions-none")),
      shows(c, "figures", figure.rows) && part(c, "figures", wording("card-box-3d-figure"), figure.rows, figure.tools, wording("card-box-none-the-companion-shows")),
    ].filter((part) => !!part),
  );
  c.box.hidden = c.box.childElementCount === 0;
  if (focus) [...c.box.querySelectorAll("button")].find((button) => button.ariaLabel === focus)?.focus();
}

/** Whether a part of the box shows: with lines, or as the card menu asked for it. */
const shows = (c: Card, key: Revealed, rows: unknown[]) => rows.length > 0 || c.revealed.has(key);
type Revealed = Card["revealed"] extends Set<infer K> ? K : never;

/** What each "Add …" of the card menu is called, by the part it adds to; the part's "+" has the same name. */
const addable = (): [Revealed, string, MenuItem["shape"]][] => ([
  ["lorebooks", wording("library-actions-add-lorebook"), "lorebook"],
  ["expressions", wording("card-expressions-add-expressions"), "expressions"],
  ["figures", wording("card-figure-add-a-3d-figure"), "figure"],
]);

/** Shows the part `key` of the box, though it is empty, and presses its "+": the lorebooks' menu, or the dialog that adds. */
export function addTo(c: Card, key: Revealed): void {
  c.revealed.add(key);
  drawBox(c);
  const name = addable().find(([one]) => one === key)![1];
  [...c.box.querySelectorAll("button")].find((button) => button.ariaLabel === name)?.click();
}

/** The card menu's lines for the parts of the box that do not show, each read anew as the menu opens. */
export function addLines(c: Card): MenuItem[] {
  // A group under a rule; the lorebook says what it is for.
  return addable().map(([key, label, shape], at) => ({
    label,
    shape,
    apart: at === 0,
    sub: key === "lorebooks" ? wording("library-actions-add-lorebook-sub") : undefined,
    action: () => addTo(c, key),
    get hidden() {
      return !!c.box.querySelector(`h2[data-part="${key}"]`);
    },
  }));
}

/** A part of the box: its name with what adds to it, over its lines, a few of which show until its chevron opens the rest. */
function part(c: Card, key: keyof Card["all"], name: string, rows: HTMLElement[], tools: HTMLElement[] = [], none = ""): HTMLElement {
  const title = el("h2", null, name);
  title.dataset.part = key;
  const head = el("div", { className: "bhead" }, title, ...tools);
  const open = (now: boolean) => {
    c.all[key] = now;
    rows.forEach((row, at) => (row.hidden = !now && at >= SHOWN_LINES));
  };
  if (rows.length > SHOWN_LINES) {
    const more = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-box-show-all", { count: rows.length, key: name }) }, icon("down", 16));
    more.onclick = () => {
      open(!c.all[key]);
      more.ariaExpanded = String(c.all[key]);
    };
    more.ariaExpanded = String(c.all[key]);
    head.append(more);
  }
  open(c.all[key]);
  return el("div", { className: "part" }, head, rows.length ? el("ul", null, ...rows) : el("p", { className: "meta" }, none));
}

/** The card's chats, the one written in last first. Each opens its chat, and its trash icon moves it to the Trash. */
function chatsPart(c: Card): HTMLElement | null {
  if (c.chats.length === 0) return null;
  const trash = (chat: Chat) =>
    c.attempt(async () => {
      const put = async (trashed: boolean) => {
        await changeChat(chat.id, { trashed });
        await load(c);
      };
      await put(true);
      announce(wording("card-box-chat-moved-to-trash"), () => put(false));
    });
  const rows = c.chats.map((chat) =>
    el(
      "li",
      { className: "bline row" },
      el("span", { className: "f-grow flex ai-c g-10" }, el("a", { className: "ink-link", href: `#/chats/${chat.id}` }, chatTitle(chat.title)), el("span", { className: "meta", title: moment(chat.updated_at) }, wording("card-box-chat-ago", { ago: ago(chat.updated_at) }))),
      lineButton(wording("card-box-move-chat-to-trash"), wording("card-box-move-to-trash"), "trash", () => trash(chat)),
    ),
  );
  return part(c, "chats", wording("card-box-this-cards-chats"), rows);
}

/**
 * The card's lorebooks. Those it brings are part of it: each can be copied into the library, for other cards
 * and chats. Then those of the library attached to it, each with the × that detaches it. "+" attaches one of
 * the library's that the card does not have yet.
 */
function lorebooksPart(c: Card): HTMLElement | null {
  if (!shows(c, "lorebooks", c.lorebooks)) return null;
  const card = c.id!;
  const change = (answer: () => Promise<CardLorebook[]>) =>
    c.attempt(async () => {
      c.lorebooks = await answer();
      // The line acted on may be gone: the "+" has the focus.
      drawBox(c, wording("library-actions-add-lorebook"));
    });
  const copy = (reference: string, label: string) =>
    c.attempt(async () => {
      const made = await copyLorebook(card, { reference });
      // The copy is one more lorebook of the library for the "+" to offer.
      c.library = await libraryLorebooks();
      drawBox(c, label);
      announce(wording("card-box-copied-to-the-library", { name: made.name }));
    });
  const row = (book: CardLorebook): HTMLElement => {
    if ("lorebook_id" in book) {
      const lorebook = book.lorebook_id;
      const detach = lineButton(wording("card-box-remove-from-this-card-2", { name: book.name }), wording("card-box-remove-from-this-card"), "close", () => change(() => detachLorebook(card, lorebook)));
      return lorebookRow(book.name, book.trashed, detach);
    }
    const { reference, name } = book;
    const label = wording("card-box-copy-to-library-2", { name });
    return el(
      "li",
      { className: "bline row" },
      el("span", { className: "f-grow flex ai-c g-10" }, el("a", { href: lorebookAddress({ card, book: reference }) }, name), el("span", { className: "meta" }, wording("card-box-this-characters-own"))),
      // The library keeps no lorebook without entries.
      book.entries > 0 && lineButton(label, wording("card-box-copy-to-library"), "copy", () => copy(reference, label)),
    );
  };
  const attached = c.lorebooks.flatMap((book) => ("lorebook_id" in book ? [book.lorebook_id] : []));
  const toTake = c.library.filter((lorebook) => !attached.includes(lorebook.id));
  const add = addLorebookMenu(toTake, (lorebook) => change(() => attachLorebook(card, { lorebook_id: lorebook.id })));
  return part(c, "lorebooks", wording("page-lorebooks"), c.lorebooks.map(row), [add], wording("persona-form-none-yet"));
}
