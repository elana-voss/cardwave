// What the rail decides, without a browser: which link says where one is, the latest chats and how each is
// called, what its button does in a wide and in a narrow window, when the drawer opens and closes, and what it
// says of the account, with the menu of the account's pages. How it looks is the browser tests'; the two rules of styles.css that the rail asks about
// stand in the page here by themselves. The account is account.ts's, which keeps it while the app runs: here
// it is a stand-in that tells the rail what the test says (`told`); the chats are what `chatsAre` says.
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { setElsewhere, watchAccount } from "../account";
import { watchAccounts } from "../settings/accounts";
import type { Account } from "../api/generated/Account";
import type { AccountLine } from "../api/generated/AccountLine";
import { listChats } from "../api/client";
import type { ChatSummary } from "../api/generated/ChatSummary";
import { el, SMALL } from "../dom";
import { chatName } from "../chat-title";
import { makeRail, type Rail } from "./rail";
import { englishText as english, useLanguage } from "../language/language";

vi.mock("../account", async (actual) => {
  const real = await actual<typeof import("../account")>();
  // `elsewhere` is read where it is, as `setElsewhere` changes it.
  return { ...real, watchAccount: vi.fn(), get elsewhere() { return real.elsewhere; } };
});
vi.mock("../settings/accounts", async (actual) => ({ ...(await actual<typeof import("../settings/accounts")>()), watchAccounts: vi.fn() }));
vi.mock("../api/client", async (actual) => ({ ...(await actual<typeof import("../api/client")>()), listChats: vi.fn(async () => []) }));

/** The chats the server has, the newest first: `count` of them, each with a character and a title of its own. */
const chatsAre = (count: number) =>
  vi.mocked(listChats).mockResolvedValue(Array.from({ length: count }, (_, at) => ({ id: at + 1, names: ["Ada"], title: `Talk ${at + 1}` }) as ChatSummary));
/** Lets the rail take the chats it asked for. */
const settled = () => new Promise((done) => setTimeout(done));

/** Tells the rail the account, as account.ts does once the server has said, and after a rename. */
const told = (account: Account) => vi.mocked(watchAccount).mock.lastCall![0](account);
/** Tells the rail the accounts there are, as accounts.ts does. */
const toldAccounts = (lines: AccountLine[]) => vi.mocked(watchAccounts).mock.lastCall![0](lines);

/** Sets the window's width: 600 px or less is a narrow window. */
const width = (px: number) => (window as unknown as { happyDOM: { setViewport(size: { width: number; height: number }): void } }).happyDOM.setViewport({ width: px, height: 800 });

/** What a rail listens to outside itself, to be taken away with it: a rail of a test before would close this test's drawer. */
let listening: [target: EventTarget, kind: string, listener: EventListenerOrEventListenerObject][] = [];

beforeEach(() => {
  localStorage.clear();
  width(1024);
  // A folded rail shows no lines for the library's sections.
  document.head.replaceChildren(el("style", null, 'body[data-rail="narrow"] .nav-chat { display: none }'));
  document.body.replaceChildren(el("nav", { id: "rail" }), el("nav", { id: "topbar" }), el("div", { id: "veil", hidden: true }), el("main", { id: "view" }), el("div", { id: "toast" }));
  for (const target of [document, SMALL]) {
    const add = target.addEventListener.bind(target);
    vi.spyOn(target, "addEventListener").mockImplementation((kind: string, listener: EventListenerOrEventListenerObject, options?: boolean | AddEventListenerOptions) => {
      listening.push([target, kind, listener]);
      add(kind, listener, options);
    });
  }
});

afterEach(() => {
  vi.restoreAllMocks();
  for (const [target, kind, listener] of listening) target.removeEventListener(kind, listener);
  listening = [];
  delete document.body.dataset.rail;
  delete document.body.dataset.drawer;
});

const rail = () => document.querySelector<HTMLElement>("#rail")!;
const bar = () => document.querySelector<HTMLElement>("#topbar")!;
const veil = () => document.querySelector<HTMLElement>("#veil")!;
const page = () => document.querySelector<HTMLElement>("#view")!;
const toggle = () => document.querySelector<HTMLButtonElement>("#rail-toggle")!;
const menu = () => document.querySelector<HTMLButtonElement>("#drawer-toggle")!;
/** The names of the links that say where one is, in the rail and in the bar. */
const marked = (within: HTMLElement) => [...within.querySelectorAll<HTMLElement>('[aria-current="page"]')].map((link) => link.textContent || link.title);
const link = (name: string) => [...rail().querySelectorAll<HTMLAnchorElement>("a")].find((one) => one.textContent === name)!;
const drawerOpen = () => document.body.dataset.drawer === "open";

/** Makes the rail, whose "Create" shows no screen. */
const make = (): Rail => makeRail(() => null);

/** The account's button, in the rail and in the bar. */
const account = (within: HTMLElement) => within.querySelector<HTMLButtonElement>("button.account")!;

test("the account is called by the name it is told, with its first letter in a round, in the rail and in the bar, and again when it is renamed", () => {
  make();
  // Until it is told, the button is the account's, without a name.
  for (const one of [account(rail()), account(bar())]) expect([one.ariaLabel, one.textContent]).toEqual(["Account", ""]);
  told({ name: "élan", local: true, picture: null });
  expect(account(rail()).ariaLabel).toBe("Account: élan");
  expect(account(bar()).ariaLabel).toBe("Account: élan");
  expect(account(rail()).querySelector(".rail-text")!.textContent).toBe("élan");
  expect(account(rail()).querySelector(".initial")!.textContent).toBe("É");
  expect(account(bar()).textContent).toBe("É");
  // A rename is told the same way.
  told({ name: "Wren", local: true, picture: null });
  expect([account(rail()).ariaLabel, account(rail()).textContent, account(bar()).textContent]).toEqual(["Account: Wren", "WWren", "W"]);
});

test("the account's button opens the menu of the account's pages, in the rail and in the bar, and a line leads to its page", () => {
  make();
  for (const within of [rail(), bar()]) {
    const button = account(within);
    const list = button.parentElement!.querySelector<HTMLElement>('[role="menu"]')!;
    const lines = [...list.querySelectorAll<HTMLElement>('[role="menuitem"]')];
    expect(list.hidden).toBe(true);
    button.click();
    expect(list.hidden).toBe(false);
    expect(lines.map((line) => line.textContent)).toEqual(["Profile", "Settings"]);
    lines[0].click();
    expect(location.hash).toBe("#/account/profile");
    expect(list.hidden).toBe(true);
    button.click();
    lines[1].click();
    expect(location.hash).toBe("#/settings");
  }
});

test("the rail marks the one link that says where one is: a screen's, or the line of the library's section, and the bar the screen's", () => {
  const made = make();
  made.mark("chats");
  expect(marked(rail())).toEqual(["Chats"]);
  expect(marked(bar())).toEqual(["Chats"]);
  made.mark("library", "lorebooks");
  expect(marked(rail())).toEqual(["Lorebooks"]);
  expect(marked(bar())).toEqual(["Library"]);
  made.mark("library", "personas");
  expect(marked(rail())).toEqual(["Personas"]);
  // The account's pages mark the account's button, and not the gear, which leads to one of them too.
  made.mark("account");
  expect(marked(rail())).toEqual(["Account"]);
  expect(rail().querySelector('[aria-current="page"]')).toBe(account(rail()));
  expect(marked(bar())).toEqual(["Account"]);
  // A screen the rail has no link to marks none.
  made.mark("setup");
  expect(marked(rail())).toEqual([]);
  expect(marked(bar())).toEqual([]);
});

test("the groups of lines stand between rules, with no headings, and Memories and Documents say where one is", () => {
  const made = make();
  const after = (line: Element) => line.previousElementSibling?.className;
  expect([after(link("Characters")), after(link("Memories"))]).toEqual(["rail-rule", "rail-rule"]);
  expect(rail().querySelectorAll(".rail-rule")).toHaveLength(2);
  // The character generator is Create's "Character generator", not a line of the rail (the owner, 2026-10-25).
  expect(rail().querySelector('a[href="#/generator"]')).toBeNull();
  expect(rail().textContent).not.toMatch(/Library|Knowledge/);
  expect([link("Memories"), link("Documents")].map((line) => line.getAttribute("href"))).toEqual(["#/knowledge/memories", "#/knowledge/documents"]);
  // Their tooltips say what they hold, which their names alone do not tell a newcomer.
  expect([link("Memories"), link("Documents")].map((line) => line.title)).toEqual(["Memories: what the AI remembers from your chats", "Documents: files the AI reads when it answers"]);
  made.mark("knowledge", "memories");
  expect(marked(rail())).toEqual(["Memories"]);
  expect(marked(bar())).toEqual(["Knowledge"]);
  made.mark("knowledge", "documents");
  expect(marked(rail())).toEqual(["Documents"]);
});

test("a page under the library that names no section, or one the library has not, is under Characters", () => {
  const made = make();
  made.mark("library");
  expect(marked(rail())).toEqual(["Characters"]);
  made.mark("library", "versions");
  expect(marked(rail())).toEqual(["Characters"]);
});

test("the rail's button folds and unfolds it, says which it does, and the choice is kept", () => {
  make();
  expect(document.body.dataset.rail).toBe("wide");
  expect(toggle().ariaLabel).toBe("Collapse sidebar");
  expect(toggle().ariaExpanded).toBe("true");
  toggle().click();
  expect(document.body.dataset.rail).toBe("narrow");
  expect(toggle().ariaLabel).toBe("Expand sidebar");
  expect(toggle().ariaExpanded).toBe("false");
  expect(localStorage.getItem("rail")).toBe("narrow");
  toggle().click();
  expect(document.body.dataset.rail).toBe("wide");
  expect(toggle().ariaLabel).toBe("Collapse sidebar");
  expect(localStorage.getItem("rail")).toBe("wide");
});

test("the rail starts as it was left, and wide where nothing is kept", () => {
  make();
  expect(document.body.dataset.rail).toBe("wide");
  localStorage.setItem("rail", "narrow");
  make();
  expect(document.body.dataset.rail).toBe("narrow");
  expect(toggle().ariaLabel).toBe("Expand sidebar");
});

test("a chat is called by its character and its title, by one of them where that is all, and a chat without a character by its title", () => {
  expect(chatName({ names: ["Ada"], title: "At the docks" })).toBe("Ada · At the docks");
  expect(chatName({ names: ["Ada", "Bo"], title: "" })).toBe("Ada");
  expect(chatName({ names: ["Ada"], title: "Ada" })).toBe("Ada");
  expect(chatName({ names: [], title: "Notes" })).toBe("Notes");
});

test("under Chats the five latest chats, and “Show 10 more” adds ten each time until all show", async () => {
  chatsAre(17);
  const made = make();
  made.mark("chats");
  await settled();
  const lines = () => [...rail().querySelectorAll<HTMLAnchorElement>(".rail-chats a")];
  const more = rail().querySelector<HTMLButtonElement>(".more-link")!;
  expect(lines().map((line) => line.textContent)).toEqual(["Ada · Talk 1", "Ada · Talk 2", "Ada · Talk 3", "Ada · Talk 4", "Ada · Talk 5"]);
  expect(lines()[0].getAttribute("href")).toBe("#/chats/1");
  expect([more.hidden, more.textContent]).toEqual([false, "Show 10 more"]);
  more.click();
  expect(lines()).toHaveLength(15);
  more.click();
  expect(lines()).toHaveLength(17);
  expect(more.hidden).toBe(true);
});

test("two latest chats of the same name on the same day say the day and time of each", async () => {
  const at = (hour: number) => new Date(2020, 9, 12, hour, 2).getTime();
  vi.mocked(listChats).mockResolvedValue(
    [
      { id: 1, names: ["Gwen"], title: null, updated_at: at(14) },
      { id: 2, names: ["Gwen"], title: null, updated_at: at(9) },
      { id: 3, names: ["Ada"], title: null, updated_at: at(8) },
    ] as unknown as ChatSummary[],
  );
  make().mark("chats");
  await settled();
  const lines = [...rail().querySelectorAll<HTMLAnchorElement>(".rail-chats a")].map((line) => line.textContent);
  expect(lines).toEqual(["Gwen · 12 Oct 2020, 14:02", "Gwen · 12 Oct 2020, 09:02", "Ada"]);
});

test("two latest chats of the same name on different days say only the day of each", async () => {
  vi.mocked(listChats).mockResolvedValue(
    [
      { id: 1, names: ["Gwen"], title: null, updated_at: new Date(2020, 9, 12, 14, 2).getTime() },
      { id: 2, names: ["Gwen"], title: null, updated_at: new Date(2020, 9, 11, 9, 2).getTime() },
      { id: 3, names: ["Ada"], title: null, updated_at: new Date(2020, 9, 10, 8, 2).getTime() },
    ] as unknown as ChatSummary[],
  );
  make().mark("chats");
  await settled();
  const lines = [...rail().querySelectorAll<HTMLAnchorElement>(".rail-chats a")].map((line) => line.textContent);
  expect(lines).toEqual(["Gwen · 12 Oct 2020", "Gwen · 11 Oct 2020", "Ada"]);
});

test("a chat's page marks its line among the latest chats, and Chats where the line does not show: folded, or not among them", async () => {
  chatsAre(7);
  const made = make();
  made.mark("chats", "3");
  await settled();
  expect(marked(rail())).toEqual(["Ada · Talk 3"]);
  expect(marked(bar())).toEqual(["Chats"]);
  made.mark("chats", "7");
  await settled();
  expect(marked(rail())).toEqual(["Chats"]);
  // Folded, the latest chats do not show; the section's line does, with its icon.
  made.mark("chats", "3");
  await settled();
  toggle().click();
  expect(marked(rail())).toEqual(["Chats"]);
  made.mark("library", "lorebooks");
  await settled();
  expect(marked(rail())).toEqual(["Lorebooks"]);
});

test("in a narrow window the bar's first button opens the rail as a drawer: the page under it is not reached, and the focus is on the button that closes it", () => {
  make();
  width(500);
  expect(toggle().ariaLabel).toBe("Close sidebar");
  expect(toggle().ariaExpanded).toBe("true");
  expect(menu().ariaExpanded).toBe("false");
  expect(drawerOpen()).toBe(false);

  menu().click();
  expect(drawerOpen()).toBe(true);
  expect(veil().hidden).toBe(false);
  expect([page().inert, bar().inert]).toEqual([true, true]);
  expect(menu().ariaExpanded).toBe("true");
  expect(document.activeElement).toBe(toggle());
});

test("a press beside the drawer closes it, and so does its own button, which gives the focus back and folds nothing", () => {
  make();
  width(500);
  menu().click();
  veil().click();
  expect(drawerOpen()).toBe(false);
  expect(veil().hidden).toBe(true);
  expect([page().inert, bar().inert]).toEqual([false, false]);
  expect(menu().ariaExpanded).toBe("false");

  menu().click();
  toggle().click();
  expect(drawerOpen()).toBe(false);
  expect(document.activeElement).toBe(menu());
  expect(document.body.dataset.rail).toBe("wide");
  expect(localStorage.getItem("rail")).toBeNull();
});

test("Escape closes the drawer and gives the focus back, unless the Escape was a menu's in it", () => {
  make();
  width(500);
  const escape = (from: Element) => from.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
  menu().click();
  // A menu in the drawer that closed on the Escape has taken it for itself.
  const taking = (event: Event) => event.preventDefault();
  rail().addEventListener("keydown", taking);
  escape(rail());
  expect(drawerOpen()).toBe(true);
  rail().removeEventListener("keydown", taking);

  escape(rail());
  expect(drawerOpen()).toBe(false);
  expect(document.activeElement).toBe(menu());
  // Another key closes nothing.
  menu().click();
  rail().dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }));
  expect(drawerOpen()).toBe(true);
});

test("a line of the drawer that is taken closes it, a link's or a menu's, and a press elsewhere in it does not", () => {
  make();
  width(500);
  menu().click();
  rail().querySelector<HTMLElement>(".rail-brand")!.click();
  expect(drawerOpen()).toBe(true);
  link("Lorebooks").click();
  expect(drawerOpen()).toBe(false);

  menu().click();
  const create = rail().querySelector<HTMLElement>(".rail-create")!;
  create.querySelector("button")!.click();
  expect(drawerOpen()).toBe(true);
  [...create.querySelectorAll<HTMLElement>('[role="menuitem"]')].find((line) => line.textContent === "Import card")!.click();
  expect(drawerOpen()).toBe(false);
});

test("a window made wide closes the drawer, and the button folds the rail again", () => {
  make();
  width(500);
  menu().click();
  width(1024);
  expect(drawerOpen()).toBe(false);
  expect(veil().hidden).toBe(true);
  expect(page().inert).toBe(false);
  expect(toggle().ariaLabel).toBe("Collapse sidebar");
  toggle().click();
  expect(document.body.dataset.rail).toBe("narrow");
});

test("first run has no rail: taken away, the rail and the bar are hidden and the drawer is closed", () => {
  const made = make();
  width(500);
  menu().click();
  made.show(false);
  expect([rail().hidden, bar().hidden]).toEqual([true, true]);
  expect(drawerOpen()).toBe(false);
  expect(page().inert).toBe(false);
  made.show(true);
  expect([rail().hidden, bar().hidden]).toEqual([false, false]);
});

test("where there are other accounts, the account's menu has them to switch to under its pages, and this computer's account has Server", () => {
  make();
  const lines = () => [...account(rail()).parentElement!.querySelectorAll<HTMLElement>('[role="menu"] button')].map((line) => line.textContent);
  told({ name: "Wren", local: true, picture: null });
  toldAccounts([{ id: 1, name: "Wren", local: true, current: true, password: false }]);
  expect(lines()).toEqual(["Profile", "Settings", "Sharing"]);
  toldAccounts([
    { id: 1, name: "Wren", local: true, current: true, password: false },
    { id: 2, name: "Ada", local: false, current: false, password: true },
  ]);
  expect(lines()).toEqual(["Profile", "Settings", "Sharing", "Wren", "Ada", "Add account"]);
  expect(account(rail()).parentElement!.querySelector(".menu-group")!.textContent).toBe("Switch account");
  // Another account has no Server, and adds none.
  told({ name: "Ada", local: false, picture: "/api/account/picture?at=1" });
  expect(lines()).toEqual(["Profile", "Settings", "Wren", "Ada"]);
  expect(account(rail()).querySelector(".initial img")!.getAttribute("src")).toBe("/api/account/picture?at=1");
});

test("on another device the account's menu ends with Sign out, a lone account's too", () => {
  setElsewhere(true);
  try {
    make();
    const lines = () => [...account(rail()).parentElement!.querySelectorAll<HTMLElement>('[role="menu"] button')].map((line) => line.textContent);
    told({ name: "Ada", local: false, picture: null });
    toldAccounts([{ id: 2, name: "Ada", local: false, current: true, password: true }]);
    expect(lines()).toEqual(["Profile", "Settings", "Sign out"]);
  } finally {
    setElsewhere(false);
  }
});

test("the rail's foot has the account, the Trash and the gear, the Trash leading to the Trash page and named in its tooltip", () => {
  make();
  const foot = rail().querySelector<HTMLElement>(".rail-foot")!;
  const [, trash, gear] = [...foot.children] as HTMLAnchorElement[];
  expect(foot.children[0].querySelector("button.account")).toBe(account(rail()));
  expect([trash.getAttribute("href"), trash.title, trash.ariaLabel]).toEqual(["#/settings/trash", "Trash", "Trash"]);
  expect([gear.getAttribute("href"), gear.title]).toEqual(["#/settings", "Settings"]);
});

test("the rail's words switch with the language, without the rail made anew", () => {
  make();
  told({ name: "Wren", local: true, picture: null });
  // The made-up language: English, each text wrapped.
  useLanguage("xx", english.replace(/^([a-z][\w-]*) = (.*)$/gm, "$1 = ‹$2›"));
  try {
    expect([...rail().querySelectorAll(".rail-text")].map((text) => text.textContent).slice(0, 4)).toEqual(["‹Cardwave›", "‹Create›", "‹Chats›", "‹Characters›"]);
    expect([account(rail()).ariaLabel, menu().ariaLabel, toggle().ariaLabel]).toEqual(["‹Account: Wren›", "‹Open sidebar›", "‹Collapse sidebar›"]);
    expect(bar().querySelector<HTMLElement>(".rail-ic")!.title).toBe("‹Chats›");
    const lines = [...account(rail()).parentElement!.querySelectorAll<HTMLElement>('[role="menuitem"]')].map((line) => line.textContent);
    expect(lines).toEqual(["‹Profile›", "‹Settings›", "‹Sharing›"]);
  } finally {
    useLanguage("en");
  }
});
