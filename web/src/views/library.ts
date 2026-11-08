// The library: the user's cards to search, filter and sort, as a list, as a
// grid of pictures or as large entries to leaf through, import by file, and
// what can be done with a card. The rail leads to its other sections. A card's
// row says "The AI is describing the character…" while the worker model is to describe it, and the
// list is read anew when the server tells of a card queued or described, or changed in another window.
// It is a list screen (../library/list-screen.ts); its layout is chosen in the title bar's view menu (`View.views`).
// `arrange` puts `.sorting` (the order and filter's button) into the bar or, in a narrow window, into the toolbar under the search, also when the
// window crosses 600 px. Its search, filter, order and how far it was scrolled stay while the app runs, so coming
// back shows the list as it was left (`asked`, `scrolled`). Only the cards in and near the view are drawn (../windowed.ts).
// The view By need is Gallery's tiles under the row "I need…" (../library/by-need.ts): only it sends the picks.
// The view Posters is Gallery's tiles with only a poster (../library/poster.ts); a card that has none yet keeps the plain tile.
// It alone asks the list for what a poster shows (`posters`), so coming to it reads the list anew.
import { cardChats, cardTags, cardThumbnailUrl, changeCard, copyLorebook, getCard, getNeeds, getSearchModel, importCard, listCards } from "../api/client";
import type { NeedsOverview } from "../api/generated/NeedsOverview";
import type { CardSummary } from "../api/generated/CardSummary";
import type { Show } from "../api/generated/Show";
import type { Sort } from "../api/generated/Sort";
import { el, SMALL, type View } from "../dom";
import { isArt } from "../art";
import { contextMenu, menu } from "../dialogs";
import { remember, remembered } from "../storage";
import { icon } from "../icons";
import { needRow } from "../library/by-need";
import { poster } from "../library/poster";
import { designOf } from "../library/poster-designs";
import { type Came, fileImport } from "../library/importing";
import { beginChat, cardItems, cover, starButton } from "../library/library-actions";
import { characterWays, emptyLine, keyed, lastSeen, type ListScreen, listScreen, readList } from "../library/list-screen";
import { sortFilter } from "../library/sort-filter";
import { needWords } from "../language/interview";
import { language, wording } from "../language/language";
import { windowed } from "../windowed";
import { cardTitle } from "../card-title";
import { comma } from "../format";

/** How the cards are laid out. */
type Layout = "list" | "gallery" | "discovery" | "by_need" | "posters";

const layouts = (): [Layout, string][] => [
  ["list", wording("library-list")],
  ["gallery", wording("library-gallery")],
  ["discovery", wording("library-discovery")],
  ["by_need", wording("library-by-need")],
  ["posters", wording("library-posters")],
];
/** The layout is kept under this name for the next start. */
const LAYOUT = "library-view";
/** How far the list was scrolled when it was left, to which it scrolls again when it is next read. */
let scrolled = 0;
/** What the list was last asked for. Kept while the app runs, so coming back shows the same list. */
const asked: { q: string; show: Show; sort: Sort; tags: string[]; needs: string[] } = { q: "", show: "all", sort: "last_chatted", tags: [], needs: [] };
/** The layout last chosen; the list at first. */
let layout: Layout = layouts().find(([name]) => name === remembered(LAYOUT))?.[0] ?? "list";

/** Puts the list's order, filter and layout where the window's width has them, on the screen that is shown. */
let arrange = () => {};
SMALL.addEventListener("change", () => arrange());

/**
 * A card's picture, for where it shows large. Without art it takes itself
 * away, and its place stays plain; with art, `shown` is told.
 */
function art(card: CardSummary, shown?: (picture: HTMLImageElement) => void): HTMLImageElement {
  const picture = el("img", { src: cardThumbnailUrl(card.version_id, "tile"), alt: "", loading: "lazy" });
  picture.onload = () => {
    if (isArt(picture)) shown?.(picture);
    else picture.remove();
  };
  picture.onerror = () => picture.remove();
  return picture;
}

const sorts = (): [Sort, string][] => [
  ["last_chatted", wording("library-last-chat")],
  ["name", wording("common-name")],
  ["added", wording("library-date-added")],
];
/** Imports a card file. What came of it has the lorebooks the card brings that the library can have too: one without entries it keeps none of. */
async function addCard(file: File): Promise<Came> {
  const card = await importCard(file);
  return {
    title: cardTitle(card.title),
    warnings: card.warnings,
    open: `#/library/${card.card_id}`,
    offers: card.lorebooks.flatMap((book) =>
      "reference" in book && book.entries > 0
        ? [{ name: book.name, copy: async () => (await copyLorebook(card.card_id, { reference: book.reference })).name }]
        : [],
    ),
  };
}

/** The tags the list is narrowed by, as an empty list says them: " with the tags “sea” and “keeper”". */
function withTags(tags: string[]): string {
  if (!tags.length) return "";
  const named = new Intl.ListFormat(language()).format(tags.map((tag) => wording("library-actions-quoted", { name: tag })));
  return wording("library-with-tags", { count: tags.length, named });
}


/** Reads the list as it was asked for; in the view By need also what its row shows, and of the picks those a card still has. */
async function readCards(): Promise<[CardSummary[], string, NeedsOverview | null]> {
  const overview = layout === "by_need" ? await getNeeds() : null;
  const need = overview ? asked.needs.filter((picked) => overview.needs.includes(picked)) : [];
  const having = withTags(asked.tags) + (need.length ? wording("library-with-needs") : "");
  const [found, empty] = await readList((query) => listCards({ ...query, sort: asked.sort, tag: asked.tags, need, posters: layout === "posters" }), wording("library-characters"), asked, wording("library-no-cards"), having);
  return [found, empty, overview];
}

export function libraryView(): View {
  /** The cards last read, and what to say when there are none. */
  let cards: CardSummary[] = [];
  let none = "";
  /** In By need, each card's needs, which its tile shows where Gallery's shows the tags. */
  let byCard: NeedsOverview["by_card"] = {};
  let back: number | null = scrolled;
  const needs = needRow(asked.needs, () => void load());

  const { node, bar, tools, list, attempt, load, starred } = listScreen({
    title: wording("page-characters"),
    kind: "library",
    search: wording("add-character-search-characters"),
    placeholder: wording("add-character-name-or-tag"),
    unread: wording("library-couldnt-load"),
    asked,
    read: readCards,
    show: ([found, empty, overview]) => {
      [cards, none] = [found, empty];
      if (overview) needs.show(overview);
      byCard = overview?.by_card ?? {};
      draw();
      // Coming back, the list stands where it was left.
      if (back !== null) node.scrollTop = back;
      back = null;
    },
  });
  // With the search model ready, the search also finds a card by what it is about, and says so.
  getSearchModel().then(
    (model) => {
      const field = tools.node.querySelector("input");
      if (model.state === "ready" && field) field.placeholder = wording("add-character-name-tag-or-about");
    },
    // Without the search model's state the field says what it finds always.
    () => undefined,
  );
  // A card is in the list soon after it has come.
  const file = fileImport("card", ".png,image/png", node, addCard, () => void load());
  // The order and the tags. They stand at the right of the bar; a narrow window has them under the search.
  const sorting = el(
    "div",
    { className: "sorting flex ai-c g-8" },
    sortFilter(
      node,
      sorts(),
      asked,
      () => void load(),
      (tag) => cardTags({ q: asked.q.trim(), show: asked.show, tag, need: layout === "by_need" ? asked.needs : [] }),
      () => (layout === "by_need" ? wording("library-need-sorts") : undefined),
    ),
  );
  arrange = () => (SMALL.matches ? tools.node : bar).append(sorting);
  // By need says its name beside the title: its list is another than the others'.
  const viewName = el("span", { className: "meta" }, `· ${wording("library-by-need")}`);
  arrange();
  const shown = windowed<CardSummary>(list, node);

  /** Lays the cards out anew, in the layout chosen. */
  function draw(): void {
    list.className = { list: "rows-plain", gallery: "gallery", discovery: "entries discovery", by_need: "gallery", posters: "gallery" }[layout];
    const needTile = (card: CardSummary, acts: Acts) => tile(card, acts, (byCard[card.id] ?? []).map(needWords));
    const drawn = { list: row, gallery: tile, discovery: entry, by_need: needTile, posters: posterTile }[layout];
    // Put in only when it is not there: moved, a pill would lose the keyboard's place.
    if (layout !== "by_need") needs.node.remove();
    else if (!needs.node.parentNode) tools.node.after(needs.node);
    if (layout !== "by_need") viewName.remove();
    else bar.querySelector("h1")?.append(viewName);
    shown.draw(cards, (card) => keyed(drawn(card, { attempt, load, starred }), card.id));
    if (none) list.append(emptyLine(none, none === wording("library-no-cards") ? characterWays(() => (location.hash = "#/library/new"), () => file.click()) : []));
  }

  void load();
  // "Create" leads here for a card to import.
  return {
    node: node,
    create: () => file.click(),
    views: {
      list: layouts(),
      now: () => layout,
      choose: (chosen) => {
        // Only By need sends the picks and shows the row: what it shows is read when it is left or come to. Posters
        // alone is sent what a poster shows: its cards are read first where they lack it, so no plain tile flashes.
        const unread = chosen === "posters" && cards.some((card) => !card.poster);
        const read = unread || layout === "by_need" || chosen === "by_need";
        layout = chosen as Layout;
        remember(LAYOUT, layout);
        if (!unread) draw();
        if (read) void load();
      },
    },
    // A card queued or described by the worker model shows "The AI is describing the character…", or its terms and logline; a card changed,
    // or one taken out of the Trash, in another window shows as it is now.
    onEvent: (event) => void (["descriptions", "card", "card_folder", "trash"].includes(event.type) && load()),
    onConnected: () => void load(),
    left: () => {
      scrolled = node.scrollTop;
    },
  };
}

/** What the cards' rows, tiles and entries do through the screen. */
type Acts = Pick<ListScreen, "attempt" | "load" | "starred">;

/** What is done with a card from where it shows: going on with its chat ("Continue", else "New chat", as its page), its menu and its star. */
function controls(card: CardSummary, { attempt, load, starred }: Acts) {
  const act = (action: () => Promise<void>) => attempt(action, cardTitle(card.title));
  // Goes on with the chat written in last; a card without a chat starts one with its character.
  const chat = async () => {
    const [last] = await cardChats(card.id);
    if (last) {
      location.hash = `#/chats/${last.id}`;
      return;
    }
    const {
      card: newest,
      characters: [one],
    } = await getCard(card.id);
    if (!one) throw new Error(wording("add-character-holds-no-character"));
    await beginChat([{ version_id: newest.version_id, character: one.id }]);
  };
  const star = starButton(card, (favorite) => changeCard(card.id, { favorite }), act, 18, starred);
  return {
    chat: el(
      "button",
      { type: "button", className: "btn btn-secondary", title: card.last_chat_title ?? "", onclick: () => act(chat) },
      icon("chat", 16),
      card.last_chat_at === null ? wording("page-chat") : wording("library-continue-chat"),
    ),
    more: menu(wording("common-more"), cardItems(card, act, load)),
    star,
  };
}

/** The names a card's characters have in a chat, where they say more than its title: "as Una, Odo". */
const namesOf = (card: CardSummary) => {
  const names = card.names.join(comma());
  return names !== "" && names !== card.title && wording("library-as", { names });
};

/** Gives what shows a card the card's menu, on a right-click. */
const menuOf = (card: CardSummary, link: HTMLElement, { attempt, load }: Acts) => contextMenu(link, () => cardItems(card, (action) => attempt(action, cardTitle(card.title)), load));

/**
 * A card as a line of the list. All of it opens the card's page: the title
 * is the link, and reaches over the line (`.row-link`). A wide window has
 * the names beside the title, the tags under it, and at the right what is
 * done with the card and when it was last chatted with; a narrow one has
 * names and tags as one line, and of those at the right the star alone.
 * Where nothing can hover, a round arrow at the line's end says that it
 * leads on.
 */
function row(card: CardSummary, acts: Acts): HTMLElement {
  const { chat, more, star } = controls(card, acts);
  const names = namesOf(card);
  const tags = card.tags.join(" · ");
  const both = [names, tags].filter(Boolean).join(" · ");
  const link = el("a", { className: "row-title ttl ink-link row-link", href: `#/library/${card.id}` }, cardTitle(card.title));
  menuOf(card, link, acts);
  return el(
    "li",
    { className: "item row item-roomy ai-s rel card-row" },
    cover(card.version_id),
    el(
      "div",
      { className: "item-text item-text-spaced" },
      el(
        "div",
        { className: "row-head flex ai-b g-8 wrap" },
        link,
        names && el("span", { className: "meta wide-only" }, names),
        card.archived && el("span", { className: "meta" }, wording("add-character-archived")),
        card.describing && el("span", { className: "meta" }, wording("character-describing")),
      ),
      tags && el("span", { className: "meta tags wide-only" }, tags),
      both && el("span", { className: "meta narrow-only" }, both),
      card.excerpt && el("p", { className: "excerpt two-lines" }, card.excerpt),
    ),
    el(
      "div",
      { className: "flex ai-c g-4 f-none rel" },
      el("div", { className: "reveal flex g-4 wide-only" }, chat, more),
      lastSeen(link, wording("library-last-chat"), card.last_chat_at, (when) => wording("library-chatted", { when })),
      star,
      el("span", { className: "go", ariaHidden: "true" }, icon("go", 14)),
    ),
  );
}

/**
 * A card as a picture in a grid, with its title under it and then, in one
 * line, that it is archived or else its names. All of it is one link to the
 * card's page, with nothing to press: a favorite carries a star as a mark,
 * and what can be done with the card is in the menu a right-click opens.
 * Pointed at or in focus, the picture shows the card's first words and tags, or By need's `marks`, its needs.
 */
function tile(card: CardSummary, acts: Acts, marks = card.tags): HTMLElement {
  const tags = marks.join(" · ");
  const words =
    (card.excerpt || tags) &&
    el(
      "span",
      { className: "tile-hover", ariaHidden: "true" },
      card.excerpt && el("span", { className: "tile-log" }, card.excerpt),
      tags && el("span", { className: "tile-tags" }, tags),
    );
  const state = card.archived ? wording("add-character-archived") : namesOf(card);
  const link = el(
    "a",
    { className: "tile", href: `#/library/${card.id}` },
    el(
      "span",
      { className: "tile-art" },
      // The words stand on the picture: a card without art shows none.
      art(card, (picture) => {
        if (words) picture.after(words);
      }),
      card.favorite && el("span", { className: "fav", role: "img", ariaLabel: wording("library-actions-favourite") }, icon("star", 14)),
    ),
    el("span", { className: "tile-title", title: cardTitle(card.title) }, cardTitle(card.title)),
    state && el("span", { className: "tile-sub" }, state),
  );
  menuOf(card, link, acts);
  return el("li", null, link);
}

/** A card as a poster, which alone fills the tile; while it has no design, the plain tile. */
function posterTile(card: CardSummary, acts: Acts): HTMLElement {
  const design = designOf(card.poster);
  if (!design || !card.poster) return tile(card, acts);
  const link = el("a", { className: "tile", href: `#/library/${card.id}`, ariaLabel: `${cardTitle(card.title)}. ${card.poster.tagline}` }, el("span", { className: "tile-art" }, poster(card, card.poster, design)));
  menuOf(card, link, acts);
  return el("li", null, link);
}

/** A card as a large entry: its picture beside its tags, title and first words. All of it opens the card's page. */
function entry(card: CardSummary, acts: Acts): HTMLElement {
  const half = el("span", { className: "art" });
  // The picture keeps its shape, on a blurred copy of itself that fills the half.
  half.append(
    art(card, (picture) => {
      const blurred = el("span", { className: "art-bg" });
      blurred.style.backgroundImage = `url("${picture.src}")`;
      half.prepend(blurred);
    }),
  );
  const link = el(
    "a",
    { className: "entry", href: `#/library/${card.id}` },
    half,
    el(
      "span",
      { className: "etext" },
      card.tags.length > 0 && el("span", { className: "meta" }, card.tags.join(" · ")),
      el("span", { className: "entry-title t-display" }, cardTitle(card.title)),
      el("span", { className: "short-rule" }),
      card.excerpt && el("span", { className: "logline m0" }, card.excerpt),
    ),
  );
  menuOf(card, link, acts);
  return el("li", null, link);
}
