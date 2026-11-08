// The Trash: the cards, chats, personas and lorebooks that were deleted, and the expression packs and 3D figures no
// card has any more, to restore or to delete for good.
//
// A page under the settings, with the path "Settings / Trash" and, while it holds something, "Empty Trash" at
// the bar's right; under the bar a column (`.trash`) with how long an item stays and the items as list rows
// (`.rows-plain > .item.row`, the design system's parts), each with what can be done
// with it at its right, in a place as wide in every row (`.side-acts`): how many days are left, "Restore" and "Delete forever". What cannot be taken back asks in
// its place (`irreversible`, by `askFirst` of dialogs.ts): the place holds the question in red, the red button
// that does it and "Cancel", which has the focus. A new kind of item in the Trash gets its line in `DOORS` and in `kindOf` (the server's
// side: crates/cw-library/src/trash.rs). A change of the Trash in another window has it read anew.
import { wording } from "../language/language";
import {
  changeCard,
  changeChat,
  changeExpressionPack,
  changeFigure,
  changeLorebook,
  changePersona,
  deleteCard,
  deleteChat,
  deleteExpressionPack,
  deleteFigure,
  deleteLorebook,
  deletePersona,
  emptyTrash,
  getTrash,
} from "../api/client";
import type { TrashItem } from "../api/generated/TrashItem";
import { announce, el, noticeBox, oneAtATime, type View } from "../dom";
import { chatTitle } from "../chat-title";
import { askFirst } from "../dialogs";
import { DAY_MS, comma, daysLeft, moment } from "../format";
import { icon } from "../icons";
import { cover } from "../library/library-actions";
import { cardTitle } from "../card-title";

/**
 * Fills `place` with `before` and a quiet red button for what cannot be taken
 * back, which asks first, in that place: all of it becomes the question, the
 * red button that does it and "Cancel", which has the focus then, so a second
 * Enter does no harm.
 */
function irreversible(place: HTMLElement, before: HTMLElement[], label: string, question: string, yes: string, action: () => void): void {
  const ask = el("button", { type: "button", className: "btn btn-danger btn-fit" }, label);
  const offer = () => place.replaceChildren(...before, ask);
  ask.onclick = () =>
    askFirst(place, question, yes, action, () => {
      offer();
      ask.focus();
    });
  offer();
}

/** How an item is put back or deleted for good, by its kind. */
const DOORS = {
  card: { change: changeCard, remove: deleteCard },
  chat: { change: changeChat, remove: deleteChat },
  persona: { change: changePersona, remove: deletePersona },
  lorebook: { change: changeLorebook, remove: deleteLorebook },
  expression_pack: { change: (id: number, { trashed }: { trashed: boolean }) => changeExpressionPack(id, { trashed }), remove: deleteExpressionPack },
  figure: { change: (id: number, { trashed }: { trashed: boolean }) => changeFigure(id, { trashed }), remove: deleteFigure },
};

/**
 * What an item is, in a few words: a character, with the chats that went
 * along; a chat and whom it is with; a persona or a lorebook, with the chats
 * that have it and will be without it.
 */
function kindOf(item: TrashItem): string {
  if (item.kind === "expression_pack") return wording("trash-expressions");
  if (item.kind === "figure") return wording("trash-figure");
  if (item.kind === "chat") return item.cards.length ? wording("trash-chat-with", { names: item.cards.join(comma()) }) : wording("trash-chat");
  if (item.kind === "persona" || item.kind === "lorebook") {
    if (item.kind === "persona") return item.chats === 0 ? wording("trash-persona") : wording("trash-persona-used", { count: item.chats });
    return item.chats === 0 ? wording("trash-lorebook") : wording("trash-lorebook-used", { count: item.chats });
  }
  if (item.chats === 0) return wording("trash-character");
  return wording("trash-character-chats", { count: item.chats });
}

export function trashView(): View {
  const list = el("ul", { className: "rows-plain" });
  const notice = noticeBox();
  const about = el("p", { className: "hint" });
  // Said in the list's place while the Trash holds nothing.
  const none = el("p", { className: "meta m0", hidden: true }, wording("trash-empty"));
  const all = el("div", { className: "confirm flex ai-c jc-e g-8" });
  const node = el(
    "section",
    { className: "main" },
    el(
      "header",
      { className: "page-head" },
      el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-trash"))),
      all,
    ),
    el("div", { className: "trash w100 flex f-col g-12" }, none, about, notice, list),
  );
  const attempt = oneAtATime(notice);

  async function load(): Promise<void> {
    const { days, items } = await getTrash();
    about.textContent = wording("trash-about", { days: String(days) });
    const emptied = () =>
      attempt(async () => {
        await emptyTrash();
        await load();
        announce(wording("trash-emptied"));
      });
    all.replaceChildren();
    if (items.length > 0) irreversible(all, [], wording("trash-empty-trash"), wording("trash-delete-all-ask", { count: items.length }), wording("trash-empty-trash"), emptied);
    list.replaceChildren(...items.map((item) => row(item, days)));
    none.hidden = items.length > 0;
  }

  function row(item: TrashItem, days: number): HTMLElement {
    const title = item.kind === "chat" ? chatTitle(item.title) : item.kind === "card" ? cardTitle(item.title) : item.title;
    const { change, remove: removed } = DOORS[item.kind];
    const done = (change: (id: number) => Promise<unknown>, said: string) =>
      attempt(async () => {
        await change(item.id);
        await load();
        announce(said);
      }, title);
    const restore = () => done((id) => change(id, { trashed: false }), wording("trash-restored", { title }));
    const remove = () => done(removed, wording("trash-deleted", { title }));
    const left = daysLeft(item.trashed_at + days * DAY_MS);
    // A character takes its chats with it, both ways; Restore and the question say so.
    const chats = item.kind === "card" ? item.chats : 0;
    // What can be done with it, in one place at the row's right, as wide in every row.
    const side = el("div", { className: "side-acts confirm flex ai-c jc-e g-8 f-none" });
    irreversible(
      side,
      [
        el("span", { className: "meta left", title: wording("trash-deleted-at", { when: moment(item.trashed_at) }) }, wording("trash-days-left", { count: left })),
        el("button", { type: "button", className: "btn btn-secondary", onclick: restore, ...(chats > 0 && { title: wording("trash-restore-chats", { count: chats }) }) }, wording("trash-restore")),
      ],
      wording("trash-delete-forever"),
      chats > 0 ? wording("trash-delete-forever-ask-chats", { title, count: chats }) : wording("trash-delete-forever-ask", { title }),
      wording("trash-delete-forever"),
      remove,
    );
    return el(
      "li",
      { className: "item row item-roomy" },
      item.kind === "card"
        ? cover(item.version_id)
        : el("span", { className: "icover" }, icon(item.kind === "expression_pack" ? "expressions" : item.kind)),
      el(
        "div",
        { className: "item-text g-2" },
        el("span", { className: "ttl" }, title),
        el("span", { className: "meta" }, kindOf(item)),
      ),
      side,
    );
  }

  void attempt(load);
  // What was put in, taken out or deleted in another window.
  return { node: node, onEvent: (event) => void (event.type === "trash" && attempt(load)), onConnected: () => void attempt(load) };
}
