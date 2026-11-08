// The list of chats: searched, shown as all, favorites or archived, in the
// order chosen, each with its star and what can be done with it.
//
// It is a list screen (../library/list-screen.ts), as the library's characters are: a row leads to its chat (`.row-link`),
// with the chat's menu at its right and on a right-click, and its order is chosen in the panel "Sort"
// (sort-filter.ts), whose button stands at the right of the bar. A chat's picture is its first card's
// (`picture`), and a card without art has the chat's drawing in a grey box there. The page has the class
// `chats`, which has the library's rules for a toolbar and a narrow row in styles.css. While nothing exists, no
// chat and no card, the page is the fresh start (create.ts) under its bar, without the search or Sort; a new chat is begun from Create. A
// chat started, changed, written in or put in the Trash in another window has the list read anew. A wide
// window's line shows, while pointed at, a bin before its menu, which moves the chat to the Trash as the menu's
// Delete does, with Undo in the notice. Only the chats in and near the view are drawn (../windowed.ts).
import { changeChat, listCards, listChats } from "../api/client";
import type { ChatSort } from "../api/generated/ChatSort";
import type { ChatSummary } from "../api/generated/ChatSummary";
import type { Show } from "../api/generated/Show";
import { freshStart } from "../shell/create";
import { el, type View } from "../dom";
import { isArt } from "../art";
import { chatTitle } from "../chat-title";
import { contextMenu, menu, type MenuItem } from "../dialogs";
import { icon } from "../icons";
import { archiveLine, cover, deleteLine, exportChatLine, starButton, undoable } from "../library/library-actions";
import { emptyLine, keyed, lastSeen, listScreen, readList } from "../library/list-screen";
import { sortFilter } from "../library/sort-filter";
import { wording } from "../language/language";
import { windowed } from "../windowed";
import { cardTitle } from "../card-title";
import { comma } from "../format";

/** What the list was last asked for. Kept while the app runs, so coming back shows the same list. */
const asked: { q: string; show: Show; sort: ChatSort } = { q: "", show: "all", sort: "last_written" };
/** The orders, the list's own first. */
const sorts = (): [ChatSort, string][] => ([
  ["last_written", wording("chats-last-message")],
  ["name", wording("common-name")],
  ["started", wording("chats-date-started")],
]);
/** What the list says when no chat was ever started. */
const noChats = () => (wording("chats-no-chats-yet"));

/**
 * A chat's picture in its row: that of the card version its first character
 * is of. A card without art, or a chat whose card is not told, has the chat's
 * drawing in a grey box of that size.
 */
function picture(versionId: number | undefined): HTMLElement {
  const blank = () => el("span", { className: "icover cover" }, icon("chat"));
  if (versionId === undefined) return blank();
  const shown = cover(versionId);
  const none = () => shown.replaceWith(blank());
  shown.onload = () => {
    if (!isArt(shown)) none();
  };
  shown.onerror = none;
  return shown;
}

/** The list of chats; `open` shows a screen, for the fresh start's lines. */
export function chatsView(open: (address: string) => View | null): View {
  const { node, bar, tools, list, attempt, load, starred } = listScreen({
    title: wording("page-chats"),
    kind: "chats",
    search: wording("chats-search-chats"),
    placeholder: wording("chats-chat-character-or-card"),
    unread: wording("chats-couldnt-load"),
    asked,
    read: async () => {
      const read = await readList((query) => listChats({ ...query, sort: asked.sort }), wording("list-screen-chats"), asked, noChats());
      // Without a chat and without a card nothing exists: the page is the fresh start.
      const fresh = read[1] === noChats() && (await listCards()).length === 0;
      return [read, fresh] as const;
    },
    show: ([[found, none], fresh]) => {
      list.hidden = tools.node.hidden = sort.hidden = fresh;
      shown.draw(found, (chat) => keyed(row(chat), chat.id));
      node.querySelector(".fresh")?.remove();
      if (fresh) node.append(freshStart(open));
      else if (none) list.append(emptyLine(none));
    },
  });
  const sort = bar.appendChild(sortFilter(node, sorts(), asked, () => void load()));
  const shown = windowed<ChatSummary>(list, node);

  /**
   * A chat as a line of the list. All of it opens the chat: the title is the
   * link, and reaches over the line (`.row-link`). A wide window has beside
   * the title who else is in the chat and which cards it is from, and at the
   * right the chat's menu and when it was last written in; a narrow one has
   * those names as one line, and of what stands at the right the star alone.
   * Where nothing can hover, a round arrow at the line's end says that it
   * leads on.
   */
  function row(chat: ChatSummary): HTMLElement {
    const title = chatTitle(chat.title);
    const act = (action: () => Promise<void>) => attempt(action, title);
    const put = undoable(title, act, async (flags) => {
      await changeChat(chat.id, flags);
      await load();
    });
    const star = starButton(chat, (favorite) => changeChat(chat.id, { favorite }), act, 18, starred);
    // The chat is called after its first character: the others are named, and its cards where they are called otherwise.
    const others = chat.names.slice(1).join(comma());
    const cards = chat.cards.map((card) => cardTitle(card.title)).filter((card) => card !== title);
    const [withThem, fromThem] = [others && wording("chats-with", { others }), cards.length > 0 && wording("chats-from", { join: cards.join(comma()) })];
    const both = [withThem, fromThem].filter(Boolean).join(" · ");
    const remove = deleteLine(put);
    const items = (): MenuItem[] => [archiveLine(chat.archived, put), exportChatLine(chat.id, wording("library-actions-quoted", { name: title }), act), remove];
    const bin = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("card-box-move-to-trash"), title: wording("card-box-move-to-trash"), onclick: () => remove.action() }, icon("trash", 18));
    const link = el("a", { className: "row-title ttl ink-link row-link", href: `#/chats/${chat.id}` }, title);
    // The chat's menu, on a right-click too: a narrow window's row has no "…".
    contextMenu(link, items);
    return el(
      "li",
      { className: "item row item-roomy ai-s rel card-row" },
      chat.names.length ? picture(chat.cards[0]?.version_id) : el("span", { className: "icover cover" }, icon("robot")),
      el(
        "div",
        { className: "item-text item-text-spaced" },
        el(
          "div",
          { className: "row-head flex ai-b g-8 wrap" },
          link,
          withThem && el("span", { className: "meta wide-only" }, withThem),
          fromThem && el("span", { className: "meta wide-only" }, fromThem),
          chat.archived && el("span", { className: "meta" }, wording("add-character-archived")),
        ),
        both && el("span", { className: "meta narrow-only" }, both),
        chat.excerpt && el("p", { className: "excerpt two-lines" }, chat.excerpt),
      ),
      el(
        "div",
        { className: "flex ai-c g-4 f-none rel" },
        el("div", { className: "reveal flex g-4 wide-only" }, bin, menu(wording("common-more"), items())),
        lastSeen(link, wording("chats-last-message"), chat.updated_at),
        star,
        el("span", { className: "go", ariaHidden: "true" }, icon("go", 14)),
      ),
    );
  }

  void load();
  // A chat started, changed, written in, put in the Trash or taken out in another window.
  return { node: node, onEvent: (event) => void (["trash", "chat", "messages"].includes(event.type) && load()), onConnected: () => void load() };
}
