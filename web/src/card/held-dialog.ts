// The dialog "Add …" of what the app holds once and cards share (expression packs, 3D figures; boards "Add
// expressions", "Add a 3D figure"): the items held, each a line with its picture, name, what it is and how many cards
// use it, one chosen with a press and given by "Add"; "From a file…" ("From files…" where many), or files dropped on
// the dialog, keeps a new one and gives it; with none held, Add is gone and the files are the main button. Each part gives its texts, its list and what Add and the files do (`Held`); the dialog closes, draws
// the box anew and says what was added.
import type { Card } from "./card-page";
import { announce, el, fileField, noticeBox, oneAtATime } from "../dom";
import { dialog } from "../dialogs";
import { icon } from "../icons";
import { wording } from "../language/language";

/** From how many items the dialog has a search over its list. */
const SEARCHED_FROM = 9;

const usedBy = (cards: number) => (wording("held-dialog-cards", { count: cards }));

/** What a part gives the dialog. */
export interface Held<T extends { id: number; name: string; cards: number }> {
  /** "Add expressions": the dialog's title, and the control the box has in focus when drawn anew. */
  title: string;
  /** The search's placeholder: "Search packs". */
  searched: string;
  /** What the list says when the app holds none. */
  empty: string;
  /** The files "From a file…" asks for, and whether several. */
  accept: string;
  many: boolean;
  /** Above the list, what the item is for, where there is a choice; `rechoose` after it changed. */
  head?: (rechoose: () => void) => HTMLElement | null;
  picture: (item: T) => HTMLElement;
  /** What the item is, before how many cards use it: "12 expressions"; without it, only who uses it. */
  about?: (item: T) => string;
  /** The item the card, or what `head` chose, has now. */
  current: () => number | null;
  /** Whom it was added to: "this card". */
  addedTo: () => string;
  held: () => Promise<T[]>;
  /** Gives the item the app holds, or keeps the files' and gives it; each answers what was given. */
  give: (id: number) => Promise<T | null>;
  fromFiles: (files: File[]) => Promise<T | null>;
}

/** Opens the dialog over the card page `c`; `redraw` draws its box anew. */
export async function heldDialog<T extends { id: number; name: string; cards: number }>(c: Card, redraw: (focus: string) => void, h: Held<T>): Promise<void> {
  const why = noticeBox();
  const list = el("div", { className: "flex f-col g-4" });
  const add = el("button", { type: "button", className: "btn btn-primary", disabled: true }, wording("account-add-button"));
  const fromFile = el("button", { type: "button", className: "btn btn-secondary" }, h.many ? wording("held-dialog-from-files") : wording("held-dialog-from-a-file"));
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const search = el("input", { type: "search", className: "field", placeholder: h.searched, ariaLabel: h.searched, hidden: true });
  let chosen = h.current();
  const lines: { item: T; line: HTMLButtonElement }[] = [];
  /** The item the card has is the one chosen at first; Add waits for another. */
  const mark = () => {
    for (const { item, line } of lines) line.ariaPressed = String(item.id === chosen);
    add.disabled = chosen === null || chosen === h.current();
  };
  const head = h.head?.(() => {
    chosen = h.current();
    mark();
  });
  const body = el("div", { className: "dlg-body" }, head ?? null, search, list, why);
  const box = dialog(c.node, h.title, body, el("div", { className: "dfoot" }, add, fromFile, cancel));
  box.classList.add("expressions-dialog");
  cancel.onclick = () => box.close();
  const attempt = oneAtATime(why);
  const done = (item: T | null) => {
    box.close();
    redraw(h.title);
    if (item) announce(wording("held-dialog-added-to", { name: item.name, addedTo: h.addedTo() }));
  };
  const files = fileField(box, h.accept, h.many, (picked) =>
    void attempt(async () => {
      if (picked.length) done(await h.fromFiles(picked));
    }),
  );
  body.append(files);
  // A file dropped on the dialog is the item's, not the card's picture, which the page takes.
  for (const kind of ["dragover", "drop"]) box.addEventListener(kind, (event) => event.stopPropagation());
  fromFile.onclick = () => files.click();
  add.onclick = () =>
    void attempt(async () => {
      if (chosen !== null) done(await h.give(chosen));
    });
  await attempt(async () => {
    const held = await h.held();
    chosen = h.current();
    for (const item of held) {
      const line = el(
        "button",
        { type: "button", className: "pk" },
        h.picture(item),
        el("span", { className: "f-grow flex f-col" }, el("span", { className: "medium" }, item.name), el("span", { className: "meta" }, h.about ? wording("held-dialog-item-about", { about: h.about(item), usedBy: usedBy(item.cards) }) : usedBy(item.cards))),
        el("span", { className: "c-accent flex pack-tick" }, icon("check", 18)),
      );
      line.onclick = () => {
        chosen = item.id;
        mark();
      };
      lines.push({ item, line });
    }
    list.replaceChildren(...lines.map(({ line }) => line));
    if (!held.length) {
      // Nothing to choose: Add is gone and the files are the one way, the main button.
      list.replaceChildren(el("p", { className: "meta" }, h.empty));
      add.hidden = true;
      fromFile.className = "btn btn-primary";
    }
    search.hidden = held.length < SEARCHED_FROM;
    search.oninput = () => {
      const q = search.value.trim().toLowerCase();
      for (const { item, line } of lines) line.hidden = !item.name.toLowerCase().includes(q);
    };
    mark();
  });
}
