// What the tabs decide, without a browser: how wide they are and how many show, which addresses are one page and
// what a tab is called, and what showing, opening, closing and a start do to the tabs. A screen is a stand-in
// that says which address it was made for. The bar, the keys and the links are the browser tests' (73-tabs).
import { beforeEach, expect, test, vi } from "vitest";
import { el, titled, type View } from "../dom";
import { remember, remembered } from "../storage";
import { fit, pageOf, samePage, setTabsOn, START, TAB_LEAST, TAB_SLOT, TAB_WIDE, Tabs, type Tab } from "./tabs";

/** The addresses screens were made for, in order. */
let made: string[] = [];
const make = (address: string): View => {
  made.push(address);
  return { node: el("section", { className: "page" }), left: vi.fn() };
};
/** The tabs, the screen of the one in view put into `#view` as main.ts does. */
const tabsOf = () => new Tabs(make, (tab: Tab) => document.querySelector("#view")!.replaceChildren(tab.view!.node));
const addresses = (tabs: ReturnType<typeof tabsOf>) => tabs.list.map((tab) => tab.address);

beforeEach(() => {
  made = [];
  localStorage.clear();
  history.replaceState(null, "", "#/chats");
  document.body.replaceChildren(el("main", { id: "view" }));
});

test("tabs are as wide as they may be while there is room, share it down to the least, and past that the last do not show", () => {
  expect(fit(1000, 3)).toEqual({ width: TAB_WIDE, shown: 3 });
  expect(fit(5 * (160 + TAB_SLOT) - TAB_SLOT, 5)).toEqual({ width: 160, shown: 5 });
  expect(fit(5 * (TAB_LEAST + TAB_SLOT) - TAB_SLOT, 9)).toEqual({ width: TAB_LEAST, shown: 5 });
  expect(fit(10, 4).shown).toBe(1);
});

test("a lorebook's entries are one page, and a tab is named after its page until its screen names it", () => {
  expect(samePage("#/library/lorebooks/3/lore.a", "#/library/lorebooks/3")).toBe(true);
  expect(samePage("#/library/4/lorebook/lore.a", "#/library/4/lorebook")).toBe(true);
  expect(samePage("#/library/4", "#/library/5")).toBe(false);
  expect(pageOf("#/settings/voices")).toEqual({ title: "Voices", shape: "gear" });
  expect(pageOf("#/library/lorebooks")).toEqual({ title: "Lorebooks", shape: "lorebook" });
  const tabs = tabsOf();
  tabs.restore("tabs", "#/library/7");
  expect(tabs.now().title).toBe("Character");
  titled(tabs.now().view!.node, "North Light", "/picture.png");
  expect(tabs.now()).toMatchObject({ title: "North Light", picture: "/picture.png" });
});

test("a page another tab holds shows that tab, and the tab that was in view keeps its own", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "#/settings");
  tabs.open("#/library");
  const library = tabs.now().view;
  tabs.go("#/settings");
  expect(addresses(tabs)).toEqual(["#/settings", "#/library"]);
  expect(tabs.now().address).toBe("#/settings");
  expect(location.hash).toBe("#/settings");
  // Back on the library its screen is the one it had, not one made anew.
  tabs.show(tabs.list[1]);
  expect(tabs.now().view).toBe(library);
  expect(made).toEqual(["#/settings", "#/library"]);
});

test("a page opened in a new tab is opened once; the tab in view goes to an address of its own", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "");
  tabs.open("#/library/personas");
  tabs.open("#/library/personas");
  expect(addresses(tabs)).toEqual([START, "#/library/personas"]);
  const left = tabs.now().view!.left;
  tabs.go("#/knowledge/memories");
  expect(left).toHaveBeenCalled();
  expect(addresses(tabs)).toEqual([START, "#/knowledge/memories"]);
});

test("opening the page in view keeps its screen; a screen let go of no longer counts as in a tab", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "#/settings");
  const settings = tabs.now().view!;
  tabs.open("#/settings");
  expect(tabs.now().view).toBe(settings);
  expect(made).toEqual(["#/settings"]);
  tabs.go("#/library");
  expect(settings.node.hasAttribute("data-tab")).toBe(false);
  const library = tabs.now().view!;
  tabs.newTab();
  tabs.close(tabs.list[0]);
  expect(library.node.hasAttribute("data-tab")).toBe(false);
});

test("a scroll kept from the start before stays kept while the page is drawn", () => {
  const kept = [["div.list@0", 250, 0]];
  remember("tabs", JSON.stringify({ now: 0, tabs: [{ address: "#/settings", title: "Settings", picture: null, scroll: kept }] }));
  tabsOf().restore("tabs", "");
  expect(JSON.parse(remembered("tabs")!).tabs[0].scroll).toEqual(kept);
});

test("closing the tab in view shows the one after it, and closing the last leaves one on the start view", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "#/settings");
  tabs.open("#/library");
  tabs.open("#/generator");
  tabs.show(tabs.list[1]);
  tabs.close(tabs.now());
  expect(tabs.now().address).toBe("#/generator");
  tabs.close(tabs.list[0]);
  tabs.close(tabs.now());
  expect(addresses(tabs)).toEqual([START]);
  expect(location.hash).toBe(START);
});

test("the tabs come back at the next start, with their names, each screen made when its tab is first shown", () => {
  const before = tabsOf();
  before.restore("tabs.1", "#/library/7");
  titled(before.now().view!.node, "North Light");
  before.open("#/settings");
  before.move(before.now(), 0);
  made = [];
  const after = tabsOf();
  after.restore("tabs.1", "");
  expect(addresses(after)).toEqual(["#/settings", "#/library/7"]);
  expect(after.list[1].title).toBe("North Light");
  expect(made).toEqual(["#/settings"]);
  // Another account keeps tabs of its own.
  const other = tabsOf();
  other.restore("tabs.2", "");
  expect(addresses(other)).toEqual([START]);
});

test("an address asked for at the start is shown in the tab in view, or in the tab that holds it", () => {
  tabsOf().restore("tabs", "#/settings");
  const tabs = tabsOf();
  tabs.restore("tabs", "#/library");
  expect(addresses(tabs)).toEqual(["#/library"]);
  tabs.open("#/generator");
  const again = tabsOf();
  again.restore("tabs", "#/library");
  expect(addresses(again)).toEqual(["#/library", "#/generator"]);
  expect(again.now().address).toBe("#/library");
});

test("the keys and Ctrl+click of the tabs do nothing before the tabs are restored: the locked start screen stays", () => {
  const tabs = tabsOf();
  const link = el("a", { href: "#/settings" }, "Settings");
  document.body.append(link);
  link.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true }));
  // Tabs of earlier tests still listen on the document; only this one's list is looked at.
  expect(addresses(tabs)).toEqual([START]);
  tabs.restore("tabs.mine", "");
  link.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true }));
  expect(addresses(tabs)).toEqual([START, "#/settings"]);
});

test("tabs switched off keep the tab in view alone, open a page in it, and come back switched on", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "");
  tabs.open("#/library/personas");
  tabs.open("#/settings");
  setTabsOn(false);
  expect(addresses(tabs)).toEqual(["#/settings"]);
  expect(document.body.hasAttribute("data-tabs-off")).toBe(true);
  tabs.open("#/generator");
  tabs.newTab();
  expect(addresses(tabs)).toEqual([START]);
  const again = tabsOf();
  again.restore("tabs", "");
  expect(addresses(again)).toEqual([START]);
  setTabsOn(true);
  expect(document.body.hasAttribute("data-tabs-off")).toBe(false);
  tabs.open("#/generator");
  expect(addresses(tabs)).toEqual([START, "#/generator"]);
});

test("tabs switched off: a Ctrl+click on a link opens it in place, never in the browser; another window's switch is followed", () => {
  const tabs = tabsOf();
  tabs.restore("tabs", "");
  tabs.open("#/settings");
  setTabsOn(false);
  const link = Object.assign(document.createElement("a"), { href: "#/generator" });
  document.body.append(link);
  const click = new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true, button: 0 });
  link.dispatchEvent(click);
  link.remove();
  expect(click.defaultPrevented).toBe(true);
  expect(addresses(tabs)).toEqual(["#/generator"]);
  // Switched on in another window: the storage event tells this one.
  localStorage.setItem("tabs-on", "on");
  window.dispatchEvent(new StorageEvent("storage", { key: "tabs-on", newValue: "on" }));
  expect(document.body.hasAttribute("data-tabs-off")).toBe(false);
});
