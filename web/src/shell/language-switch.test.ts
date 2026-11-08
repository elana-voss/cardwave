// The live switch of the language (language.ts), shown by a made-up language: every text of en.ftl wrapped in
// ‹ ›. The title bar and its tabs are said anew, and each tab's screen made anew with what the user typed in it
// and the focus kept; a tab its screen named keeps that name. The rail's are rail.test.ts's.
import { afterEach, beforeEach, expect, test } from "vitest";
import { englishText as english, onLanguage, useLanguage } from "../language/language";
import { el, titled, type View } from "../dom";
import { Tabs, type Tab } from "./tabs";
import { makeTitleBar } from "./titlebar";

/** The made-up language: English, each text wrapped. */
const madeUp = english.replace(/^([a-z][\w-]*) = (.*)$/gm, "$1 = ‹$2›");

/** The screens made, in order: each a field. */
let made: View[] = [];
const make = (): View => {
  const view = { node: el("section", { className: "page" }, el("input", { className: "name" }), el("textarea", { className: "note" })) };
  made.push(view);
  return view;
};

beforeEach(() => {
  made = [];
  localStorage.clear();
  history.replaceState(null, "", "#/chats");
  // The bar draws its tabs only where it has a width, which happy-dom gives no element.
  const bar = el("header", { id: "titlebar" });
  Object.defineProperty(bar, "clientWidth", { value: 1440 });
  document.body.replaceChildren(bar, el("main", { id: "view" }));
});

afterEach(() => useLanguage("en"));

/** Lets the frames that put the typed text back run. */
const frames = () => new Promise((done) => setTimeout(done, 50));

test("the title bar and the tabs' names switch at once, and the tab in view's screen is made anew with what was typed in it kept", async () => {
  const tabs = new Tabs(make, (tab: Tab) => document.querySelector("#view")!.replaceChildren(tab.view!.node));
  tabs.restore("tabs", "#/settings/voices");
  makeTitleBar(tabs);
  // As main.ts does, once the tabs are restored.
  const stop = onLanguage(() => tabs.relanguage());
  tabs.open("#/library/3");
  titled(tabs.now().view!.node, "North Light", null);
  tabs.open("#/library");
  const first = made.at(-1)!.node;
  const field = first.querySelector("textarea")!;
  field.value = "half a sentence";
  field.dispatchEvent(new Event("input", { bubbles: true }));
  field.focus();

  useLanguage("xx", madeUp);
  const bar = document.querySelector<HTMLElement>("#titlebar")!;
  expect(tabs.list.map((tab) => tab.title)).toEqual(["‹Voices›", "North Light", "‹Characters›"]);
  expect(bar.querySelector(".titlebar-name")!.textContent).toBe("‹Cardwave›");
  expect(bar.querySelector<HTMLElement>(".tabs")!.ariaLabel).toBe("‹Tabs›");
  expect(bar.querySelector<HTMLElement>(".tx")!.title).toBe("‹Close tab›");
  // The screen in view is a new one, in the page, with the text and the focus back; the others are made when shown.
  const now = tabs.now().view!.node;
  expect(now).not.toBe(first);
  expect(document.querySelector("#view")!.firstElementChild).toBe(now);
  await frames();
  expect(now.querySelector("textarea")!.value).toBe("half a sentence");
  expect(now.querySelector("input")!.value).toBe("");
  expect(document.activeElement).toBe(now.querySelector("textarea"));
  expect(tabs.list.map((tab) => tab.view !== null)).toEqual([false, false, true]);
  stop();
});
