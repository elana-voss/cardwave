// The tabs (docs/design.md "Tabs and search"; boards "Tabs · the tab bar", "Tabs · all tabs"): each holds a page
// of the app at its address with its own screen (`View`), kept while the app runs, so its scroll and unsent words
// stay; the tab in view's screen is in `#view` (main.ts's `drawn`) and its address in the address bar, the others'
// out of the page. `go` shows an address in the tab in view, `open` in a new tab, `newTab` the start view; both
// show instead the tab that already holds the page (`samePage`: a lorebook's entries are one page); a move to
// another tab is a step of the browser's history, so Back shows the tab before. Ctrl+click
// and a middle-click on a link of the app open it in a new tab, and in the desktop app Ctrl+T, Ctrl+W, Ctrl+Tab and
// Ctrl+Shift+Tab are the tabs' (`listen`). The tabs, their titles and each one's scroll are kept in the browser
// per account (`restore`), each restored tab's screen made when it is first shown. A screen names its tab by
// `titled` (dom.ts), else the tab is named after its page (`pageOf`). `fit` says how wide the tabs are and how
// many show. Traps: a page out of the document loses its scroll, so a tab that leaves view holds it (`held`); a
// page made anew at a start is drawn as its answers come, so its scroll is put back by each part's key for a
// while, until the user moves it (`putBack`); a screen reads the address as it is made, so it is made after the
// address is set (`draw`). When the language changes, every tab's screen is made anew, with its scroll and what
// the user typed kept (`relanguage`, typed.ts).
import { type View } from "../dom";
import { remember, remembered } from "../storage";
import { inDesktop } from "../desktop";
import type { IconName } from "../icons";
import { pageAt } from "./pages";
import { keyOf, partOf, PUT_BACK_MS, putTyped, type Typed, typedIn, watchTyping } from "./typed";

/** The app's start view, which "+" opens: the list of chats, as a start without an address shows. */
export const START = "#/chats";
/** A tab's width in the bar while there is room, the least it shrinks to, and the room between two (two gaps and the divider). */
export const TAB_WIDE = 200;
export const TAB_LEAST = 140;
export const TAB_SLOT = 5;
/** How long after a scroll stops it is kept, in milliseconds. */
const KEEP_MS = 300;

/** A part's scroll in a tab's page: the part by its key (`keyOf`), how far down and how far right. */
type Scroll = [key: string, top: number, left: number];

export interface Tab {
  address: string;
  /** The tab's screen, made when the tab is first shown. */
  view: View | null;
  title: string;
  /** Whether its screen named it (`titled`), else it is named after its page. */
  named: boolean;
  /** The round's picture: a chat's character, a card's; none for a page of the app, which has its `shape`. */
  picture: string | null;
  shape: IconName;
  /** The parts of its page that were scrolled when it left view, while the app runs. */
  held: [Element, number, number][];
  /** The same as kept for the next start, and as given back by the one before until the page is made. */
  scroll: Scroll[];
  /** What the user typed in its screen, put back when the screen is made anew in another language. */
  typed: Typed | null;
}

/** What is kept of a tab for the next start. */
interface Kept {
  address: string;
  title: string;
  named?: boolean;
  picture: string | null;
  scroll: Scroll[];
}

/** A page's name and drawing, for a tab whose screen has not named it (pages.ts). */
export function pageOf(address: string): { title: string; shape: IconName } {
  const { name, shape } = pageAt(address);
  return { title: name, shape };
}

/** Whether two addresses are of one page: a lorebook's entries are its page's, so its first four parts say. */
export function samePage(one: string, other: string): boolean {
  const page = (address: string) => (/^#\/library\/(lorebooks\/\d+|\d+\/lorebook)/.test(address) ? address.split("/").slice(0, 4).join("/") : address);
  return page(one) === page(other);
}

/**
 * How wide each of `count` tabs is in `room` pixels, and how many of them show: as wide as `TAB_WIDE` while
 * there is room, shared down to `TAB_LEAST`, and past that the last ones do not show. One always shows.
 */
export function fit(room: number, count: number): { width: number; shown: number } {
  const shown = Math.max(1, Math.min(count, Math.floor((room + TAB_SLOT) / (TAB_LEAST + TAB_SLOT))));
  const width = Math.max(TAB_LEAST, Math.min(TAB_WIDE, Math.floor((room + TAB_SLOT) / shown - TAB_SLOT)));
  return { width, shown };
}

/** The parts of `node`, itself among them, that are scrolled, with how far. */
function scrolled(node: HTMLElement): [Element, number, number][] {
  return [node, ...node.querySelectorAll("*")].filter((part) => part.scrollTop || part.scrollLeft).map((part) => [part, part.scrollTop, part.scrollLeft]);
}

/**
 * Puts the scroll kept of a page made anew back as its parts are drawn, every frame for `PUT_BACK_MS`: a page
 * drawn again on an answer (a chat on the server's first word) would lose it. The user's own move ends it; `done`
 * is told when it ends.
 */
function putBack(node: HTMLElement, scroll: Scroll[], done: () => void): void {
  const end = Date.now() + PUT_BACK_MS;
  const moved = new AbortController();
  moved.signal.addEventListener("abort", done);
  for (const type of ["wheel", "pointerdown", "keydown", "touchstart"]) node.addEventListener(type, () => moved.abort(), { capture: true, signal: moved.signal });
  const frame = () => {
    if (moved.signal.aborted) return;
    for (const [key, top, left] of scroll) {
      const part = partOf(node, key);
      if (part && (part.scrollTop !== top || part.scrollLeft !== left)) part.scrollTo(left, top);
    }
    if (Date.now() < end) requestAnimationFrame(frame);
    else moved.abort();
  };
  frame();
}

function tabOf(address: string, from?: Kept): Tab {
  const page = pageOf(address);
  const named = Boolean(from?.named);
  return { address, view: null, title: named ? from!.title : page.title, named, picture: from?.picture ?? null, shape: page.shape, held: [], scroll: from?.scroll ?? [], typed: null };
}

/**
 * The tabs. `make` makes the screen of an address, `drawn` puts the tab in view's into the page. With `alone`
 * (the desktop app's window of one page) there is one tab and nothing is kept. A move to another tab is a step
 * of the browser's history, so Back goes to the tab before; a step back to an address another tab holds shows that tab.
 */
export class Tabs {
  /** The tabs in the bar's order. */
  readonly list: Tab[] = [tabOf(START)];
  private shown: Tab = this.list[0];
  private readonly watching: (() => void)[] = [];
  /** The key the tabs are kept under, once restored; none in the window of one page. */
  private kept: string | null = null;
  /** The tab whose kept scroll is being put back, which is not measured meanwhile. */
  private settling: Tab | null = null;

  constructor(
    private readonly make: (address: string) => View,
    private readonly drawn: (tab: Tab) => void,
    private readonly alone = false,
  ) {
    watchTyping();
    if (alone) return;
    listen(this);
    // A scroll is kept a moment after it stops, for the next start.
    let later = 0;
    document.addEventListener("scroll", () => {
      clearTimeout(later);
      later = window.setTimeout(() => this.keep(), KEEP_MS);
    }, true);
  }

  /** The tab in view. */
  now(): Tab {
    return this.shown;
  }

  /** The tab that holds the page at `address`, where one does. */
  holding(address: string): Tab | undefined {
    return this.list.find((t) => samePage(t.address, address));
  }

  /** Shows `tab`, as a step of the browser's history. */
  show(tab: Tab): void {
    this.switchTo(tab, true);
  }

  /** Shows `address` in the tab in view, made anew also where it is the one shown; the tab that holds it, where another does. */
  go(address: string): void {
    const holder = this.holding(address);
    if (holder && holder !== this.shown) {
      this.switchTo(holder, false);
      if (holder.address === address) return;
      history.replaceState(null, "", address);
    }
    const now = this.shown;
    // A screen that shows the new address itself stays: a lorebook's editor from one entry to the next.
    if (now.view && now.address !== address && now.view.moved?.()) {
      now.address = address;
      return this.told();
    }
    drop(now);
    Object.assign(now, tabOf(address), { view: null });
    this.draw(now, false);
  }

  /** Shows `address` in a new tab; the tab that holds it, where one does, as it is where it is the page it shows. */
  open(address: string): void {
    const holder = this.holding(address);
    if (holder?.address === address) return this.show(holder);
    if (holder) return this.go(address);
    this.add(tabOf(address));
  }

  /** A new tab on the start view. */
  newTab(): void {
    this.add(tabOf(START));
  }

  /** Closes `tab`; the last leaves one on the start view. */
  close(tab: Tab): void {
    const at = this.list.indexOf(tab);
    if (at < 0) return;
    drop(tab);
    this.list.splice(at, 1);
    if (!this.list.length) this.list.push(tabOf(START));
    if (tab !== this.shown) return this.told();
    this.shown = this.list[Math.min(at, this.list.length - 1)];
    this.draw(this.shown, false);
  }

  /** Puts `tab` at `to` in the bar's order. */
  move(tab: Tab, to: number): void {
    const at = this.list.indexOf(tab);
    if (at < 0 || at === to) return;
    this.list.splice(at, 1);
    this.list.splice(Math.max(0, Math.min(to, this.list.length)), 0, tab);
    this.told();
  }

  /** Shows the tab after the one in view (`by` 1), or the one before (-1), round from the last to the first. */
  step(by: 1 | -1): void {
    this.show(this.list[(this.list.indexOf(this.shown) + by + this.list.length) % this.list.length]);
  }

  /** Takes the tabs kept under `key` of the start before, and shows `asked` in the tab in view (as `go`), where the start was asked for an address. */
  restore(key: string, asked: string): void {
    if (!this.alone) this.read(key);
    if (asked && !samePage(asked, this.shown.address)) {
      const holder = this.holding(asked);
      if (holder) this.shown = holder;
      else Object.assign(this.shown, tabOf(asked));
    }
    if (asked) this.shown.address = asked;
    this.draw(this.shown, false);
  }

  /**
   * The language changed: each tab named after its page is named anew, and each tab's screen is made anew, with its
   * scroll and what the user typed in it put back; the tab in view's at once, the others' when they are shown.
   */
  relanguage(): void {
    for (const t of this.list) {
      if (!t.named) t.title = pageOf(t.address).title;
      if (!t.view) continue;
      const node = t.view.node;
      const scroll = t === this.shown ? scrolled(node) : t.held;
      t.scroll = scroll.map(([part, top, left]): Scroll => [keyOf(node, part), top, left]);
      t.typed = typedIn(node);
      drop(t);
      Object.assign(t, { view: null, held: [] });
    }
    this.draw(this.shown, false);
  }

  /** Is told whenever the tabs, their order, their names or the one in view changed; each watcher so told. */
  watch(changed: () => void): void {
    this.watching.push(changed);
  }

  private read(key: string): void {
    this.kept = key;
    let read: { now?: number; tabs?: Kept[] } = {};
    try {
      read = JSON.parse(remembered(key) ?? "{}");
    } catch {
      // What was kept cannot be read: one tab, then.
    }
    const given = (read.tabs ?? []).filter((one) => typeof one?.address === "string" && one.address.startsWith("#/"));
    if (!given.length) return;
    this.list.splice(0, this.list.length, ...given.map((one) => tabOf(one.address, one)));
    this.shown = this.list[Math.min(Math.max(0, read.now ?? 0), this.list.length - 1)];
  }

  private add(tab: Tab): void {
    this.leave();
    this.shown = tab;
    this.list.push(tab);
    this.draw(tab, true);
  }

  private switchTo(tab: Tab, step: boolean): void {
    if (tab === this.shown) return;
    this.leave();
    this.shown = tab;
    this.draw(tab, step);
  }

  /** Keeps the tabs for the next start, the scroll of the tab in view as it is now. First run is kept as the start view. */
  private keep(): void {
    if (!this.kept) return;
    const now = this.shown;
    if (now.view && now !== this.settling) now.scroll = scrolled(now.view.node).map(([part, top, left]) => [keyOf(now.view!.node, part), top, left]);
    const tabs: Kept[] = this.list.map((t) => (t.address.startsWith("#/setup") ? { address: START, title: pageOf(START).title, picture: null, scroll: [] } : { address: t.address, title: t.title, named: t.named, picture: t.picture, scroll: t.scroll }));
    remember(this.kept, JSON.stringify({ now: this.list.indexOf(now), tabs }));
  }

  private told(): void {
    this.keep();
    for (const changed of this.watching) changed();
  }

  /** Makes the tab's screen for its address, and hears the name the screen gives it. */
  private made(t: Tab): View {
    const view = this.make(t.address);
    // What is drawn in it knows by this that it is in a tab, also while the tab is out of view (tools.ts).
    view.node.toggleAttribute("data-tab", true);
    const name = () => {
      if (!view.node.dataset.title || t.view !== view) return;
      t.title = view.node.dataset.title;
      t.named = true;
      t.picture = view.node.dataset.picture || null;
      this.told();
    };
    view.node.addEventListener("titled", name);
    t.view = view;
    name();
    return view;
  }

  /**
   * Shows the tab in view: its address (a new step of the history with `step`), its screen (made where it was
   * not), and its scroll as it left it, or as kept.
   */
  private draw(t: Tab, step: boolean): void {
    if (location.hash !== t.address) (step ? history.pushState : history.replaceState).call(history, null, "", t.address);
    const fresh = !t.view;
    const view = t.view ?? this.made(t);
    this.drawn(t);
    if (fresh && t.typed) putTyped(view.node, t.typed);
    t.typed = null;
    if (fresh && t.scroll.length) {
      this.settling = t;
      putBack(view.node, t.scroll, () => {
        if (this.settling === t) this.settling = null;
      });
    }
    for (const [part, top, left] of t.held.splice(0)) part.scrollTo(left, top);
    this.told();
  }

  /** The tab in view leaves view: what of its page is scrolled is held. */
  private leave(): void {
    if (this.shown.view) this.shown.held = scrolled(this.shown.view.node);
    this.keep();
  }
}

/** A tab's screen is done with: it is told it was left, and what it drew no longer counts as in a tab (tools.ts). */
function drop(tab: Tab): void {
  tab.view?.left?.();
  tab.view?.node.removeAttribute("data-tab");
}

/** The link of the app that an event is on: one whose address is a page of the app. */
const linkOf = (event: MouseEvent) => (event.target instanceof Element ? event.target.closest<HTMLAnchorElement>("a[href^='#/']") : null);

/**
 * Ctrl+click and a middle-click on a link of the app open its page in a new tab, caught before the link's own
 * click and the browser's tab; the scroll that a middle press would start is not. The desktop app's keys of the tabs.
 */
function listen(tabs: Tabs): void {
  const catching = (event: MouseEvent, now: boolean) => {
    const link = linkOf(event);
    if (!link || !now) return;
    event.preventDefault();
    event.stopPropagation();
    tabs.open(link.getAttribute("href")!);
  };
  document.addEventListener("click", (event) => catching(event, event.button === 0 && (event.ctrlKey || event.metaKey)), true);
  document.addEventListener("auxclick", (event) => catching(event, event.button === 1), true);
  document.addEventListener("mousedown", (event) => event.button === 1 && linkOf(event) && event.preventDefault(), true);
  document.addEventListener("keydown", (event) => {
    if (!inDesktop() || !event.ctrlKey || event.altKey || event.metaKey) return;
    const key = event.key.toLowerCase();
    if (key === "tab") tabs.step(event.shiftKey ? -1 : 1);
    else if (key === "t" && !event.shiftKey) tabs.newTab();
    else if (key === "w" && !event.shiftKey) tabs.close(tabs.now());
    else return;
    event.preventDefault();
  });
}
