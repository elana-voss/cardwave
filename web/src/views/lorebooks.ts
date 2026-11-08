// The library's lorebooks: what a world holds, kept apart from the cards, for
// a chat to take along. They are imported from files or made from scratch (`newLorebook` of lorebook.ts, which
// the empty list offers beside the import), searched and filtered,
// and a row leads to its lorebook's editor (lorebook.ts), as a card's row leads
// to its card (`.row-link`, with the round arrow `.go` where nothing can hover). A lorebook changed in another
// window (the event `lorebook`), and the server heard again after a drop, have the list read anew. The cards'
// own lorebooks are listed too, "in [card]" after the name, without a star; their "…" has Copy to library, Move
// to library (../card/lore-own.ts) and Export, 300 px wide (`.own-menu`). One for every chat says "In every chat".
import { changeLorebook, exportLorebook, importLorebook, listLorebooks } from "../api/client";
import type { Lorebook } from "../api/generated/Lorebook";
import { announce, el, type View } from "../dom";
import { menu } from "../dialogs";
import { icon } from "../icons";
import { type Came, fileImport } from "../library/importing";
import { archiveLine, deleteLine, exported, starButton, undoable } from "../library/library-actions";
import { type Asked, emptyLine, keyed, listScreen, readList } from "../library/list-screen";
import { lorebookAddress, ownLines, ownOf } from "../card/lore-own";
import { newLorebook } from "../lorebook/lorebook-dialog";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";
import { comma, names } from "../format";

/** What the list was last asked for. Kept while the app runs, so coming back shows the same list. */
const asked: Asked = { q: "", show: "all" };
/** What the list says when no lorebook was ever imported. */
const noLorebooks = () => (wording("lorebooks-no-lorebooks-yet-make"));

/** Who use a library lorebook, beside its name: the cards and personas that have it and the chats that took it
 * along; none where the name's line says it already (one for every chat, a card's own). */
export function usedLine(lorebook: Lorebook): string | null {
  if (lorebook.everywhere || lorebook.card) return null;
  const users = names(lorebook.used_by.map(cardTitle));
  if (lorebook.used_by.length && lorebook.chats) return wording("lorebooks-used-by-in-chats", { names: users, count: lorebook.chats });
  if (lorebook.used_by.length) return wording("lorebooks-used-by", { names: users });
  return lorebook.chats ? wording("lorebooks-in-chats", { count: lorebook.chats }) : wording("lorebooks-not-used");
}

/** Imports a lorebook file. */
async function addLorebook(file: File): Promise<Came> {
  const { lorebook, warnings } = await importLorebook(file);
  return { title: lorebook.name, warnings };
}

export function lorebooksView(): View {
  const { node, tools, list, attempt, load, starred } = listScreen({
    title: wording("page-lorebooks"),
    kind: "library",
    search: wording("lorebooks-search-lorebooks"),
    placeholder: wording("lorebooks-name-description-or-entry"),
    unread: wording("lorebooks-couldnt-load"),
    asked,
    read: () => readList(listLorebooks, wording("list-screen-lorebooks"), asked, noLorebooks()),
    show: ([found, none]) => {
      list.replaceChildren(...found.map((lorebook) => keyed(row(lorebook), lorebook.id)));
      const offers = [
        { label: wording("create-new-lorebook"), go: () => newLorebook(node) },
        { label: wording("create-import-lorebook"), go: () => file.click() },
      ];
      if (none) list.append(emptyLine(none, none === noLorebooks() ? offers : []));
    },
  });
  const file = fileImport("lorebook", ".json,application/json", node, addLorebook, (first) => {
    // A new lorebook is in view, whatever the list was searched or filtered for. Once in an import: what is
    // searched for while it goes on stays.
    if (first && (asked.q || asked.show !== "all")) tools.showAll();
    void load();
  });

  /** A card's own lorebook's "…" and a library lorebook's, with its star. */
  function marks(lorebook: Lorebook, act: (action: () => Promise<void>) => Promise<boolean>): HTMLElement[] {
    const own = lorebook.card;
    if (own) {
      const exportLine = { label: wording("library-actions-export"), shape: "export" as const, apart: true, action: () => act(async () => announce(exported(wording("library-actions-quoted", { name: lorebook.name }), await exportLorebook(ownOf(own))))) };
      const more = menu(wording("common-more"), [...ownLines(own, act, () => load()), exportLine]);
      more.classList.add("own-menu");
      return [el("div", { className: "reveal flex" }, more)];
    }
    const put = undoable(lorebook.name, act, async (flags) => {
      await changeLorebook(lorebook.id, flags);
      await load();
    });
    const star = starButton(lorebook, (favorite) => changeLorebook(lorebook.id, { favorite }), act, 18, starred);
    return [el("div", { className: "reveal flex" }, menu(wording("common-more"), [archiveLine(lorebook.archived, put), deleteLine(put)])), star];
  }

  function row(lorebook: Lorebook): HTMLElement {
    const act = (action: () => Promise<void>) => attempt(action, lorebook.name);
    const own = lorebook.card;
    // How many entries it has and the first of their names, and its description under that; one whose entries
    // were all taken out says so. The line is cut where the row ends.
    const named = lorebook.entry_names.filter((name) => name.trim()).slice(0, 12).join(comma());
    const entries = lorebook.entries === 0 ? wording("lorebooks-no-entries") : named ? wording("lorebooks-entries-named", { count: lorebook.entries, names: named }) : wording("lorebooks-entries", { count: lorebook.entries });
    return el(
      "li",
      { className: "item row item-roomy ai-s rel card-row" },
      // A lorebook has no picture: a box with the book keeps its words in line with the other lists'.
      el("span", { className: "icover icover-sq" }, icon("lorebook")),
      el(
        "div",
        { className: "item-text item-text-spaced" },
        el(
          "div",
          { className: "row-head flex ai-b g-8 wrap" },
          el("a", { className: "row-title ttl ink-link row-link", href: lorebookAddress(own ? ownOf(own) : { library: lorebook.id }) }, lorebook.name),
          own && el("span", { className: "meta" }, wording("lorebooks-in", { title: cardTitle(own.title) })),
          lorebook.archived && el("span", { className: "meta" }, wording("add-character-archived")),
          lorebook.everywhere && el("span", { className: "meta" }, wording("lorebooks-in-every-chat")),
          usedLine(lorebook) && el("span", { className: "meta" }, usedLine(lorebook)),
        ),
        el("span", { className: "meta tags ellipsis" }, entries),
        lorebook.description && el("p", { className: "excerpt two-lines" }, lorebook.description),
      ),
      el(
        "div",
        { className: "flex ai-c g-4 f-none rel" },
        ...marks(lorebook, act),
        el("span", { className: "go", ariaHidden: "true" }, icon("go", 14)),
      ),
    );
  }

  void load();
  return {
    node: node,
    // "Create" leads here for a lorebook to import.
    create: () => file.click(),
    onEvent: (event) => void (event.type === "lorebook" && load()),
    onConnected: () => void load(),
  };
}
