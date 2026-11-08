// What the library's lists are made of: chats, characters, lorebooks and personas (views/). `listScreen` is
// such a screen's scaffold: the bar with the section's name, the search and All / Favourites / Archived, the
// notice and the list, with the runner of its actions and its reader; Personas has the search alone (`plain`). The screen draws its own rows and
// calls `load` once it is made.
//
// The parts other screens use too: `pageTitle`, a section's name at the head of its page; `listTools`, the
// search and All / Favourites / Archived; `readList`, which reads a list as it was asked for and says why it is
// empty; `emptyLine`, the line of an empty list, with the buttons that begin a section that holds nothing;
// `characterWays`, the ways to a character while the library has none (the library's and New chat's);
// `lastSeen`, when something last happened to a row's item, at the row's right, which hands a press on to
// the row's link; `keyed`, which names the item a row shows, for the resting mouse.
import type { Show } from "../api/generated/Show";
import { el, failure, latest, noticeBox, oneAtATime, reason, searchField, segmented } from "../dom";
import { ago, moment } from "../format";
import { wording } from "../language/language";

const shows = (): [Show, string][] => [
  ["all", wording("list-screen-all")],
  ["favorites", wording("list-screen-favourites")],
  ["archived", wording("add-character-archived")],
];

/** A button leading elsewhere: its words and where it goes. */
export interface Way {
  label: string;
  go: () => void;
}

/** The ways to a character while the library has none: "New character", which `make` begins, and "Import card", which `bring` does. */
export const characterWays = (make: () => void, bring: () => void): Way[] => [
  { label: wording("create-new-card"), go: make },
  { label: wording("create-import-card"), go: bring },
];

/** Names the item `row` shows, so a list read anew under a resting mouse tells a row that stayed from one that moved there. */
export function keyed<T extends HTMLElement>(row: T, item: number | string): T {
  row.dataset.key = String(item);
  return row;
}

/** A section's name at the head of its page, as "Chats" is; the rail leads to the other sections. */
export const pageTitle = (name: string): HTMLElement => el("h1", { className: "title ptitle" }, name);

/** What a section's list is asked for: words to search for, and which of its items. */
export interface Asked {
  q: string;
  show: Show;
}

/**
 * The search field and the All / Favourites / Archived switch over a section's
 * list, showing what the list was last asked for; `load` reads it anew. A
 * `plain` list (Personas) has the search alone.
 * `showAll` asks for all of the section again, with nothing searched for; the
 * list is then read by whoever calls.
 */
export function listTools(label: string, placeholder: string, asked: Asked, load: () => void, plain = false): { node: HTMLElement; showAll(): void } {
  const tools = () => {
    const search = searchField(label, placeholder, asked, load, "search-list");
    if (plain) return [search];
    const show = segmented(wording("list-screen-show"), shows(), asked.show, (show) => {
      asked.show = show;
      load();
    });
    // All leaves the archived out, which its tooltip says.
    show.querySelector("button")!.title = wording("list-screen-all-but-archived");
    return [search, show];
  };
  const node = el("div", { className: "flex ai-c g-12 wrap" }, ...tools());
  const showAll = () => {
    Object.assign(asked, { q: "", show: "all" });
    node.replaceChildren(...tools());
  };
  return { node, showAll };
}

/**
 * Reads a section's list as it was asked for, with `list`. Answers with what
 * was found and, when that is nothing, with what the empty list says: that
 * nothing matches, that all of the section's `many` are archived, or `none`
 * when the section holds nothing at all. A list that `list` narrows further
 * says how in `having` (" with the tag “sea”"), for what the empty list says. A section
 * without an archive (`archive` false: personas) is never asked for its archived.
 */
export async function readList<T>(
  list: (query: Asked) => Promise<T[]>,
  many: string,
  asked: Asked,
  none: string,
  having = "",
  archive = true,
): Promise<[T[], string]> {
  const { show } = asked;
  const q = asked.q.trim();
  const found = await list({ q, show });
  if (found.length) return [found, ""];
  if (q) return [found, wording("list-screen-none-match", { many, having, q })];
  if (show === "favorites") return [found, having ? wording("list-screen-no-favorites-having", { having }) : wording("list-screen-no-favorites")];
  if (show === "archived") return [found, wording("list-screen-none-archived", { many, having })];
  if (archive && (await list({ q: "", show: "archived" })).length) return [found, wording("list-screen-all-archived", { many, having })];
  return [found, having ? wording("list-screen-none-having", { many, having }) : none];
}

/**
 * The line a list has when it is empty, which says why. Where the section
 * holds nothing at all, `offers` are the buttons under it that begin it, side by side.
 */
export function emptyLine(said: string, offers: Way[] = []): HTMLElement {
  if (!offers.length) return el("li", { className: "empty" }, said);
  const buttons = offers.map(({ label, go }) => el("button", { type: "button", className: "btn btn-secondary", onclick: go }, label));
  return el("li", { className: "empty flex f-col ai-start g-12" }, el("span", null, said), el("div", { className: "flex g-8" }, ...buttons));
}

/**
 * When something last happened to a row's item, at the row's right in a wide
 * window: how long ago, and pointed at, the moment, after what `about` calls
 * it. As it says more when pointed at, it takes the pointer, and hands a press
 * and a right-click on to the row's `link`. `said` words what happened then
 * ("Chatted today"), given the time small as it stands inside a sentence.
 */
export function lastSeen(link: HTMLElement, about: string, at: number | null, said?: (when: string) => string): HTMLElement {
  const when = at === null ? "" : ago(at);
  const words = said && when ? said(when.charAt(0).toLowerCase() + when.slice(1)) : when;
  // Nothing yet happened: an empty place, no title.
  const last = el("span", { className: "meta when last wide-only" }, words);
  if (at !== null) last.title = wording("list-screen-last-seen", { about, at: moment(at) });
  for (const kind of ["click", "contextmenu"]) {
    last.addEventListener(kind, (event) => {
      event.preventDefault();
      link.dispatchEvent(new MouseEvent(kind, event));
    });
  }
  return last;
}

/** A list screen as `listScreen` makes it. */
export interface ListScreen {
  /** The page, `section.page` with the screen's class. */
  node: HTMLElement;
  /** The bar at its head, with the section's name. */
  bar: HTMLElement;
  tools: { node: HTMLElement; showAll(): void };
  list: HTMLUListElement;
  notice: HTMLElement;
  /** Runs one of the screen's actions, saying in the notice why it failed. */
  attempt: (action: () => Promise<void>, name?: string) => Promise<boolean>;
  /** Reads the list anew. */
  load: () => Promise<void>;
  /** Reads the list anew after a star was pressed, where it is of favorites only; elsewhere the row stays, and the star keeps the focus. */
  starred: () => Promise<void>;
}

/**
 * Makes a list screen: the page `section.page.<kind>` under the bar named
 * `title`, with the search (`search`, its `placeholder`) over the list
 * `asked` is for. `read` reads the list, and `show` is given the answer to the
 * newest reading. A reading that fails says `unread` (and why, unless the reason
 * is only that something went wrong) with Try again; the search and switch stay
 * usable, so a search that cannot be read can be changed. Where a list read anew
 * brings another item (`keyed`) under a resting mouse, the list takes no press
 * until the mouse moves, so a row that moved there is not opened by a click meant
 * for the one before; where the same item stays there, its row takes the click.
 * A touch leaves no such rest, as the next tap would be lost. A `plain` list has
 * no All / Favourites / Archived.
 */
export function listScreen<A>(made: {
  title: string;
  kind: string;
  search: string;
  placeholder: string;
  unread: string;
  asked: Asked;
  read: () => Promise<A>;
  show: (answer: A) => void;
  plain?: boolean;
}): ListScreen {
  const list = el("ul", { className: "rows-plain" });
  const notice = noticeBox();
  const tools = listTools(made.search, made.placeholder, made.asked, () => void load(), made.plain);
  const bar = el("header", { className: "pbar" }, pageTitle(made.title));
  const node = el("section", { className: `main main-list ${made.kind}` }, bar, tools.node, notice, list);
  const said = (error: unknown) => {
    const why = reason(error);
    const words = why === wording("error-internal") ? made.unread : `${made.unread} ${why}`;
    const again = el("button", { type: "button", className: "btn btn-secondary", onclick: () => void load() }, wording("setup-try-again"));
    return el("div", { className: "flex f-col ai-start g-8" }, failure(words), again);
  };
  const shown = (answer: A) => {
    const before = under();
    made.show(answer);
    if (mouse && under() !== before) resting = true;
    // After the screen's own drawing, which may set the list's classes anew.
    list.classList.toggle("still", resting);
  };
  // Where a mouse rests, told by its own events: a touch screen's `:hover` stays on the last tap.
  let mouse: { x: number; y: number } | null = null;
  let resting = false;
  /** The item of the row under the mouse, by the rows' places: a list at rest takes no pointer. */
  const under = () => {
    if (!mouse) return undefined;
    const { x, y } = mouse;
    const at = [...list.children].find((row) => {
      const box = row.getBoundingClientRect();
      return x >= box.left && x < box.right && y >= box.top && y < box.bottom;
    });
    return at && (at as HTMLElement).dataset.key;
  };
  const pointed = (event: PointerEvent) => (mouse = event.pointerType === "mouse" ? { x: event.clientX, y: event.clientY } : null);
  list.addEventListener("pointerenter", pointed);
  // A pointer that moves, or leaves the list, has left its rest.
  const moved = () => {
    resting = false;
    list.classList.remove("still");
  };
  list.addEventListener("pointerleave", () => ((mouse = null), moved()));
  list.addEventListener("pointermove", (event) => (pointed(event), moved()));
  const load: () => Promise<void> = latest(notice, made.read, shown, said);
  const starred = async () => {
    if (made.asked.show === "favorites") await load();
  };
  return { node, bar, tools, list, notice, attempt: oneAtATime(notice), load, starred };
}
