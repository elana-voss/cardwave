// The rail (boards "Left rail, open" and "Left rail, collapsed"): wide with names, or folded to icons; in a window
// of 600 px or less a bar on top, `#topbar`, whose first button opens the wide rail as a drawer and whose last is
// the magnifier of Search Cardwave (search-panel.ts). The title bar over
// it is titlebar.ts's. The wide rail has Create, Chats with the latest
// chats (`chatName` of chat-title.ts, two of one name with the day and time of each; five and "Show 10 more", read anew at every change of screen, after a reply and at a change of the Trash, `heard`),
// and the `LINES` in groups, a rule before each, no headings (the owner, 2026-10-22: "Open, as folded (a)"); folded,
// the latest chats hide and the rules are short. The account is a button whose menu has the account's pages (`ACCOUNT_PAGES`),
// "Switch account" of accounts.ts where there are other accounts, and this computer's account's "Lock" while a
// password is on (`lock`); beside it the Trash and the gear lead to the Trash page and the settings. `mark` marks where one is: a chat's line where it
// shows, else Chats; a section's line; the account's button on its pages; the bar's screen icon. The chat's split
// view folds the rail while it shows, not as the choice kept (`foldFor`). Traps: the logo
// is `logo.png`, scaled down to 112 by 102 pixels; a line hidden by styles.css is not the one marked (`shown`).
// Its words are language.ts's, set anew when the language changes (`onLanguage`); its menus are made anew then.
import { elsewhere, showRound, watchAccount } from "../account";
import { signOutItem, switchItems, watchAccounts } from "../settings/accounts";
import { listChats, lockApp } from "../api/client";
import type { Account } from "../api/generated/Account";
import type { AccountLine } from "../api/generated/AccountLine";
import type { ChatSummary } from "../api/generated/ChatSummary";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { createMenu } from "./create";
import { searchButton } from "./search-panel";
import { viewButton } from "./view-menu";
import { announce, el, escapeFree, reason, SMALL, type View } from "../dom";
import { chatName } from "../chat-title";
import { dayAt, dayMonth } from "../format";
import { menuOn, type MenuItem } from "../dialogs";
import { remember, remembered } from "../storage";
import { desktop, inDesktop } from "../desktop";
import { icon, type IconName } from "../icons";
import logo from "../logo.png";
import { page } from "./pages";
import { onLanguage, wording } from "../language/language";
import { watchPassword } from "../settings/password";

/** The narrow window's bar's screens: what the address calls each, its name, its address and its drawing. */
const SCREENS = [
  ["chats", () => wording("page-chats"), "#/chats", "chat"],
  ["library", () => wording("place-library"), "#/library", "library"],
  ["knowledge", () => wording("place-knowledge"), "#/knowledge/memories", "knowledge"],
] as const;
/**
 * The rail's groups of lines: what the address calls the group's screen, and of each line what the address calls
 * it, its page (pages.ts) and, where its name alone tells a newcomer little, its tooltip.
 */
const LINES: [string, [string, string, (() => string)?][]][] = [
  [
    "library",
    [
      ["characters", "#/library"],
      ["lorebooks", "#/library/lorebooks"],
      ["personas", "#/library/personas"],
    ],
  ],
  [
    "knowledge",
    [
      ["memories", "#/knowledge/memories", () => wording("rail-memories-tip")],
      ["documents", "#/knowledge/documents", () => wording("rail-documents-tip")],
    ],
  ],
];
/** How many of the latest chats the rail shows at first, and how many more each "Show 10 more" adds. */
const LATEST = 5;
const MORE = 10;
/** What `mark` calls the account's pages, and where the Trash and the gear at the rail's foot lead. */
const ACCOUNT = "account";
const SETTINGS = "#/settings";
const TRASH = "#/settings/trash";
/** Server, the page of this computer's account alone. */
export const SERVER = "#/account/server";
/** The account's pages, as the lines of the account's menu: a name, an address and a drawing each (pages.ts), in the language in use. */
export const accountPages = (): [string, string, IconName][] =>
  ["#/account/profile", SETTINGS, SERVER].map((address) => {
    const { name, shape } = page(address);
    return [name, address, shape];
  });

/** The account's pages that `account` has. */
export const pagesOf = (account: Account | undefined) => accountPages().filter(([, address]) => address !== SERVER || account?.local);
/** The rail is wide, with names, or narrow, with icons only. The choice is kept under this name for the next start. */
const RAIL = "rail";

export interface Rail {
  /** Marks where one is: the `screen` as the address calls it, and its `section`, of the chats a chat's number. */
  mark(screen: string, section?: string): void;
  /** Shows the rail, or takes it away: first run has none. */
  show(now: boolean): void;
  /** Hears what the server tells: a reply that ended, or a chat that named itself, may change which chats are the latest, and their names. */
  heard(event: ServerEvent): void;
}

/** "Lock": the server waits for the password, the companion closes, and the page starts anew on the start screen. */
async function lock(): Promise<void> {
  try {
    await lockApp();
  } catch (error) {
    announce(reason(error));
    return;
  }
  if (inDesktop()) await desktop("companion_quit").catch(() => {});
  location.reload();
}

/**
 * Makes the rail and the narrow window's bar.
 * `open` shows the screen at an address and answers with it, for "Create"; `shown` answers with the screen
 * shown, for the narrow bar's view menu (view-menu.ts).
 */
export function makeRail(open: (address: string) => View | null, shown: () => View | null = () => null): Rail {
  const rail = document.querySelector<HTMLElement>("#rail")!;
  const bar = document.querySelector<HTMLElement>("#topbar")!;

  const picture = (alt: string) => el("img", { className: "rail-logo", src: logo, alt });
  /** A line of the rail with its icon and its name, which is its tooltip (or `tip`) where the rail is folded. */
  const line = (name: string, href: string, shape: IconName, tip = name) => el("a", { className: "nav", href, title: tip }, icon(shape), named(name));
  /** The bar's link to each screen, its icon alone. */
  const icons = new Map<string, HTMLElement>();
  for (const [screen, name, href, shape] of SCREENS) icons.set(screen, el("a", { className: "rail-ic", href, title: name(), ariaLabel: name() }, icon(shape)));
  const chats = line(wording("page-chats"), "#/chats", "chat");
  /** The lines under the headings, by their screen and their section. */
  const sections = new Map(LINES.map(([screen, lines]) => [screen, new Map(lines.map(([section, href, tip]) => [section, line(page(href).name, href, page(href).shape, tip?.())]))]));
  /** The rule between two groups of lines: a line in the wide rail, a short one in the folded. */
  const rule = () => el("div", { className: "rail-rule", role: "separator" });
  const latest = latestChats(mark);
  const who = accountButtons();
  const { account, barAccount } = who;
  icons.set(ACCOUNT, barAccount);

  const toggle = el("button", { type: "button", id: "rail-toggle", className: "btn btn-quiet btn-icon btn-lg" }, icon("left"));
  const plus = () => el("button", { type: "button", ariaLabel: wording("rail-create"), title: wording("rail-create") }, icon("plus"));
  const [create, barCreate] = [plus(), plus()];
  create.className = "create";
  create.append(named(wording("rail-create")));
  barCreate.className = "btn btn-secondary btn-icon btn-lg";
  const footLink = (href: string, name: string, shape: IconName) => el("a", { className: "btn btn-quiet btn-icon btn-lg foot-link", href, title: name, ariaLabel: name }, icon(shape));
  const trash = footLink(TRASH, wording("page-trash"), "trash");
  const gear = footLink(SETTINGS, wording("page-settings"), "gear");
  const [accountMenu, barAccountMenu] = who.menus();
  const brand = named(wording("app-name"));
  const brandPicture = picture(wording("app-name"));
  let [createdMenu, barCreatedMenu] = [createMenu(create, open), createMenu(barCreate, open)];
  rail.replaceChildren(
    el("div", { className: "rail-head" }, el("span", { className: "rail-brand" }, picture(""), brand), toggle),
    el("div", { className: "rail-create" }, createdMenu),
    chats,
    latest.list,
    latest.more,
    ...LINES.flatMap(([screen]) => [rule(), ...sections.get(screen)!.values()]),
    el("span", { className: "rail-spacer" }),
    el("div", { className: "rail-foot" }, accountMenu, trash, gear),
  );
  const menu = el("button", { type: "button", id: "drawer-toggle", className: "btn btn-quiet btn-icon btn-xl", ariaLabel: wording("rail-open-menu"), title: wording("rail-open-menu"), ariaExpanded: "false" }, icon("menu"));
  bar.replaceChildren(menu, brandPicture, el("span", { className: "f-grow" }), viewButton("btn btn-quiet btn-icon btn-xl", shown), barCreatedMenu, icons.get("chats")!, icons.get("library")!, icons.get("knowledge")!, barAccountMenu, searchButton("btn btn-quiet btn-icon btn-xl"));
  who.watch();

  /** Where one is. */
  let here: { screen: string; section?: string } = { screen: "" };

  /**
   * Marks where one is, on one link of the rail: the nearest that the rail
   * shows as it stands, a chat's line and then Chats, or a section's line. The
   * bar has the screens alone, and marks the screen's.
   */
  function mark(): void {
    const lines = sections.get(here.screen);
    // A page under a section that names none of its lines (a card's page, its lorebook) is under the first.
    const candidates =
      here.screen === "chats" ? [latest.lines.get(Number(here.section)), chats] : here.screen === ACCOUNT ? [account] : [lines && (lines.get(here.section ?? "") ?? [...lines.values()][0])];
    const shown = candidates.find((link) => link && getComputedStyle(link).display !== "none");
    const set = (link: HTMLElement, now: boolean) => (now ? link.setAttribute("aria-current", "page") : link.removeAttribute("aria-current"));
    const all = [chats, account, ...latest.lines.values(), ...[...sections.values()].flatMap((lines) => [...lines.values()])];
    for (const link of all) set(link, link === shown);
    for (const [name, link] of icons) set(link, name === here.screen);
  }

  const drawer = folding({ rail, bar, toggle, menu }, mark);

  // Every word of the rail and the bar anew, in the language in use; Create's menus made anew.
  onLanguage(() => {
    const said = (link: HTMLElement, name: string, tip = name) => {
      link.title = tip;
      if (link.ariaLabel !== null) link.ariaLabel = name;
      const text = link.querySelector(".rail-text");
      if (text) text.textContent = name;
    };
    for (const [screen, name] of SCREENS) said(icons.get(screen)!, name());
    said(chats, wording("page-chats"));
    for (const [screen, lines] of LINES) for (const [section, href, tip] of lines) said(sections.get(screen)!.get(section)!, page(href).name, tip?.());
    for (const button of [create, barCreate]) said(button, wording("rail-create"));
    said(trash, wording("page-trash"));
    said(gear, wording("page-settings"));
    menu.ariaLabel = menu.title = wording("rail-open-menu");
    brand.textContent = brandPicture.alt = wording("app-name");
    const [made, barMade] = [createMenu(create, open), createMenu(barCreate, open)];
    createdMenu.replaceWith(made);
    barCreatedMenu.replaceWith(barMade);
    [createdMenu, barCreatedMenu] = [made, barMade];
    mark();
  });

  return {
    mark(screen, section) {
      here = { screen, section };
      mark();
      latest.read();
    },
    show(now) {
      rail.hidden = bar.hidden = !now;
      if (!now) drawer(false);
    },
    heard(event) {
      if (["reply_ended", "chat_title", "trash", "chat", "messages"].includes(event.type)) latest.read();
    },
  };
}

/** A name in the rail, which a folded rail hides. */
const named = (name: string) => el("span", { className: "rail-text" }, name);

/**
 * The latest chats under Chats, the newest first (`list`), and the button that shows ten more each time
 * (`more`); `lines` are the lines drawn, by the chat's number, and `read` reads the chats anew. `mark` is asked
 * after each drawing.
 */
function latestChats(mark: () => void) {
  const list = el("div", { className: "rail-chats flex f-col g-2" });
  const more = el("button", { type: "button", className: "more-link", hidden: true }, wording("rail-show-more", { count: MORE }));
  onLanguage(() => (more.textContent = wording("rail-show-more", { count: MORE })));
  const lines = new Map<number, HTMLElement>();
  let known: ChatSummary[] = [];
  let showing = LATEST;
  function drawChats(): void {
    lines.clear();
    const chats = known.slice(0, showing);
    const names = chats.map(chatName);
    // Lines of one name say the day of each, and the time where another of that name falls on the same day.
    const days = chats.map((chat) => dayMonth(chat.updated_at));
    const told = (at: number) => {
      const twins = names.flatMap((name, other) => (other !== at && name === names[at] ? [other] : []));
      if (twins.length === 0) return names[at];
      const when = twins.some((other) => days[other] === days[at]) ? dayAt(chats[at].updated_at) : days[at];
      return `${names[at]} · ${when}`;
    };
    chats.forEach((chat, at) => {
      const name = told(at);
      lines.set(chat.id, el("a", { className: "nav-chat", href: `#/chats/${chat.id}`, title: name }, name));
    });
    list.replaceChildren(...lines.values());
    more.hidden = known.length <= showing;
    mark();
  }
  more.onclick = () => {
    showing += MORE;
    drawChats();
  };
  /** The reading of the chats whose answer counts: one that comes after a later one is not taken. */
  let reading = 0;
  function read(): void {
    const mine = ++reading;
    listChats().then(
      (all) => {
        if (mine !== reading) return;
        known = all;
        drawChats();
      },
      () => {},
    );
  }
  return { list, more, lines, read };
}

/**
 * The account: its picture or the first letter of its name in a round, and in the wide rail the name beside
 * it. It is a button that opens the menu of the account's pages, and of the accounts to switch to: over it in
 * the rail, at whose foot it stands, and under it in the bar, back from its right edge. `menus` are the two
 * menus as first made, to be put in place before `watch` hears the account and the accounts.
 */
function accountButtons() {
  const letter = () => el("span", { className: "initial initial-sm", ariaHidden: "true" });
  const [initial, barInitial, called] = [letter(), letter(), named("")];
  const who = (...holds: HTMLElement[]) => el("button", { type: "button", title: wording("rail-account"), ariaLabel: wording("rail-account") }, ...holds);
  const [account, barAccount] = [who(initial, called), who(barInitial)];
  account.className = "nav account";
  barAccount.className = "rail-ic account";
  let me: Account | undefined;
  let others: AccountLine[] = [];
  let passwordOn = false;
  /** The menus of the account, made anew when the account, the accounts or whether a password is on change. */
  function menus(): [HTMLElement, HTMLElement] {
    const pages: MenuItem[] = pagesOf(me).map(([label, address, shape]) => ({ label, shape, action: () => (location.hash = address) }));
    if (me?.local && passwordOn) pages.push({ label: wording("rail-lock"), shape: "lock", action: () => void lock() });
    const switching = switchItems(others, me?.local ?? false).map((item, at) => (at === 0 ? { ...item, apart: true } : item));
    // A lone account on another device signs out all the same, as the menu's last line.
    const items = others.length > 1 ? [...pages, ...switching] : elsewhere ? [...pages, signOutItem(true)] : pages;
    const made: [HTMLElement, HTMLElement] = [menuOn(account, items), menuOn(barAccount, items, "end")];
    for (const menu of made) menu.classList.add("account-menu");
    return made;
  }
  let [accountMenu, barAccountMenu] = menus();
  const remake = () => {
    const [made, barMade] = menus();
    accountMenu.replaceWith(made);
    barAccountMenu.replaceWith(barMade);
    [accountMenu, barAccountMenu] = [made, barMade];
  };
  watchPassword((on) => {
    passwordOn = on;
    remake();
  });
  /** The button's name: with the account's where it is known. */
  const name = () => {
    account.title = barAccount.title = wording("rail-account");
    account.ariaLabel = barAccount.ariaLabel = me ? wording("rail-account-named", { name: me.name }) : wording("rail-account");
  };
  onLanguage(() => {
    name();
    remake();
  });
  /** Hears the account and the accounts. The name is the account's, which the server tells, and again when it is changed; without it the button says "Account" alone. */
  function watch(): void {
    watchAccount((now) => {
      called.textContent = now.name;
      showRound(initial, now);
      showRound(barInitial, now);
      const local = me?.local;
      me = now;
      name();
      if (local !== now.local) remake();
    });
    watchAccounts((lines) => {
      others = lines;
      remake();
    });
  }
  return { account, barAccount, menus: (): [HTMLElement, HTMLElement] => [accountMenu, barAccountMenu], watch };
}

/** Folds the rail, or unfolds it, without keeping it as the choice: set once the rail is made (`folding`). */
let folder: ((wide: boolean) => void) | null = null;

/** Folds the rail to its icons while `on` (the chat's split view is open), not kept as the choice; then it is as kept again. */
export function foldFor(on: boolean): void {
  folder?.(!on && remembered(RAIL) !== "narrow");
}

/**
 * Folding the `rail` by its head's button `toggle`, and its drawer in a narrow window, opened by the `bar`'s
 * `menu`. `mark` is asked whenever what the rail shows changes. Answers with what opens and closes the drawer.
 */
function folding(
  { rail, bar, toggle, menu }: Record<"rail" | "bar" | "toggle" | "menu", HTMLElement>,
  mark: () => void,
): (now: boolean, back?: boolean) => void {
  const page = document.querySelector<HTMLElement>("#view")!;
  const veil = document.querySelector<HTMLElement>("#veil")!;

  /** Says what the button in the rail's head does: it folds and unfolds the rail, and closes the drawer the rail is in a narrow window. */
  function name(): void {
    const wide = document.body.dataset.rail !== "narrow";
    toggle.ariaExpanded = String(SMALL.matches || wide);
    toggle.ariaLabel = SMALL.matches ? wording("rail-close-menu") : wide ? wording("rail-collapse") : wording("rail-expand");
  }

  function fold(wide: boolean): void {
    document.body.dataset.rail = wide ? "wide" : "narrow";
    name();
    mark();
  }

  /**
   * Opens the rail as a drawer over the page, in a narrow window, or closes
   * it. What lies under it is not reached while it is open. With `back` the
   * focus goes to the button that opened it.
   */
  function drawer(now: boolean, back = false): void {
    if (now) document.body.dataset.drawer = "open";
    else delete document.body.dataset.drawer;
    veil.hidden = !now;
    page.inert = bar.inert = now;
    menu.ariaExpanded = String(now);
    if (now) toggle.focus();
    else if (back) menu.focus();
  }
  const isOut = () => document.body.dataset.drawer !== undefined;

  menu.onclick = () => drawer(true);
  veil.onclick = () => drawer(false);
  toggle.onclick = () => {
    if (SMALL.matches) return drawer(false, true);
    const wide = document.body.dataset.rail === "narrow";
    fold(wide);
    remember(RAIL, wide ? "wide" : "narrow");
  };
  // A line of the drawer that is taken closes it before it does what it does: a window that it opens finds the page reached again.
  rail.addEventListener(
    "click",
    (event) => {
      if (isOut() && (event.target as Element).closest("a, [role=menuitem]")) drawer(false);
    },
    true,
  );
  // An Escape that closed a menu in the drawer was that menu's.
  document.addEventListener("keydown", (event) => {
    if (!escapeFree(event) || !isOut()) return;
    event.preventDefault();
    drawer(false, true);
  });
  // A window made narrow or wide changes what the rail is, and so what it shows.
  SMALL.addEventListener("change", () => {
    drawer(false);
    name();
    mark();
  });
  onLanguage(name);
  // Where the browser keeps nothing, the rail is wide at every start.
  fold(remembered(RAIL) !== "narrow");
  folder = fold;
  return drawer;
}
