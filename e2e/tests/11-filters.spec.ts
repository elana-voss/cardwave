import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File } from "../card";

// The panel "Sort and filter": tags pressed count with "Apply", the list then has the cards with them all,
// and a tag that would leave none cannot be pressed.
//
// One database for the file: the test looks at this file's cards only, found by a search of its own. `seek`
// types a search and waits for its answer; `press` presses a tag's pill in the panel and waits until the tags
// were read anew, `applied` presses "Apply" and waits for the list, and `choose` does both.
test.describe.configure({ mode: "serial" });

/** A tag as long as the library keeps one, with nowhere to break it. */
const LONG = `zz${"m".repeat(62)}`;

/** A card of one character with these tags, written as they are given. */
const card = (title: string, tags: string[]) =>
  ccv4File(`
spec = "ccv4:1.0.0"

[meta-info]
title = ${JSON.stringify(title)}
tags = ${JSON.stringify(tags)}

[name.one]
text = ${JSON.stringify(title)}

[greeting.one]
text = "Hello."

[character.one]
name-char = "name.one"
greetings = ["greeting.one"]
prompt = ["CHAT-HISTORY"]
`);

const plover = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, at) => `plover-${String(from + at).padStart(2, "0")}`);

async function add(request: APIRequestContext, file: Buffer): Promise<number> {
  const response = await request.post("/api/cards", { data: file });
  expect(response.status()).toBe(201);
  return (await response.json()).card_id;
}

test.beforeAll(async ({ request }) => {
  // Four cards a search for "osprey" finds, the last of them archived. Their tags are no other card's.
  await add(request, card("Osprey Anchor", ["harbourage", "Slow Tide", "lightkeeping", "R&D, mostly"]));
  await add(request, card("Osprey Beacon", ["harbourage", "lightkeeping", "nightwatch"]));
  await add(request, card("Osprey Cove", ["Harbourage", "nightwatch"]));
  const dune = await add(request, card("Osprey Dune", ["duneland", "nightwatch"]));
  expect((await request.patch(`/api/cards/${dune}`, { data: { archived: true } })).ok()).toBe(true);
  // Two with more tags than are read at a glance.
  await add(request, card("Plover Flock", [...plover(1, 6), "Tern"]));
  await add(request, card("Plover Roost", [...plover(5, 10), "tern", LONG]));
  // One with as many tags as are read at a glance, and one with one more.
  const fulmar = (to: number) => Array.from({ length: to }, (_, at) => `fulmar-${at + 1}`);
  await add(request, card("Fulmar Eight", fulmar(8)));
  await add(request, card("Fulmar Nine", fulmar(9)));
  await add(request, card("Gannet Rock", ["gannet-only", "guano"]));
  await add(request, card("Gannet Stack", ["guano"]));
  await add(request, card("Skua One", ["skua-a", "skua-b"]));
  await add(request, card("Skua Two", ["skua-a"]));
  await add(request, card("Skua Three", ["skua-b"]));
});

const search = (page: Page) => page.getByLabel("Search characters");
const titles = (page: Page) => page.locator(".card-row .row-title");
/** The button "Sort and filter", whose name also says how many tags are chosen. */
const sorting = (page: Page) => page.getByRole("button", { name: /^Sort and filter/ });
const panel = (page: Page) => page.getByRole("dialog", { name: "Sort and filter" });
/** The pills of the tags in view, and the one of a tag as it is written. */
const tags = (page: Page) => panel(page).getByRole("group", { name: "Tags" }).getByRole("button");
const tag = (page: Page, name: string) => panel(page).getByRole("group", { name: "Tags" }).getByRole("button", { name, exact: true });
const pressed = (page: Page) => panel(page).getByRole("group", { name: "Tags" }).getByRole("button", { pressed: true });
const greyed = (page: Page) => panel(page).getByRole("group", { name: "Tags" }).getByRole("button", { disabled: true });
const order = (page: Page, name: string) => panel(page).getByRole("group", { name: "Sort by" }).getByRole("button", { name, exact: true });
const clear = (page: Page) => panel(page).getByRole("button", { name: "Clear all" });
const apply = (page: Page) => panel(page).getByRole("button", { name: "Apply" });

/** Whether a request asks for the list of cards (not for their tags) with the search `q`. */
const asksFor = (address: string, q: string) => {
  const url = new URL(address);
  return url.pathname === "/api/cards" && (url.searchParams.get("q") ?? "") === q;
};
/** The tags a request for the tags names, or `null` for another request. */
const chosen = (address: string) => (new URL(address).pathname === "/api/cards/tags" ? new URL(address).searchParams.getAll("tag") : null);

/** Types a search and waits for its answer, which comes after the typing has paused. */
async function seek(page: Page, q: string): Promise<void> {
  const answered = page.waitForResponse((response) => asksFor(response.url(), q));
  await search(page).fill(q);
  await (await answered).finished();
}

/** Opens the panel, and waits for its tags. */
async function open(page: Page): Promise<void> {
  await sorting(page).click();
  await expect(tags(page).first()).toBeVisible();
}

/** Presses a tag's pill and waits until the tags were read anew with the choice it leaves. */
async function press(page: Page, name: string): Promise<void> {
  const read = page.waitForResponse((response) => chosen(response.url()) !== null);
  await tag(page, name).click();
  await (await read).finished();
}

/** Makes the choice in the panel the list's, and waits for the list. */
async function applied(page: Page): Promise<void> {
  const listed = page.waitForResponse((response) => new URL(response.url()).pathname === "/api/cards");
  await apply(page).click();
  await (await listed).finished();
  await expect(panel(page)).toHaveCount(0);
}

/** Opens the panel, presses these tags' pills and applies. */
async function choose(page: Page, ...names: string[]): Promise<void> {
  await open(page);
  for (const name of names) await press(page, name);
  await applied(page);
}

/** Opens the library on the cards a search finds, by name. */
async function library(page: Page, q: string): Promise<void> {
  await page.goto("/#/library");
  await sorting(page).click();
  await order(page, "Name").click();
  await applied(page);
  await seek(page, q);
}

const OSPREY = ["Osprey Anchor", "Osprey Beacon", "Osprey Cove", "Osprey Dune"];
const OSPREY_TAGS = ["duneland", "harbourage", "lightkeeping", "nightwatch", "R&D, mostly", "Slow Tide"];

/** Opens the library on the four cards of "osprey", the archived one last. */
async function osprey(page: Page): Promise<void> {
  await library(page, "osprey");
  await expect(titles(page)).toHaveText(OSPREY);
}

test("the page beside the panel is not dimmed, and the Tags say a character needs every one picked", async ({ page }) => {
  await osprey(page);
  await open(page);
  const backdrop = await panel(page).evaluate((box) => getComputedStyle(box, "::backdrop").backgroundColor);
  expect(backdrop).toBe("rgba(0, 0, 0, 0)");
  await expect(panel(page)).toContainText("Characters with every tag you pick show.");
  await page.keyboard.press("Escape");
});

test("tags pressed count with Apply: the list then has the cards with them all, and a tag that would leave none cannot be pressed", async ({ page }) => {
  await osprey(page);
  await open(page);

  // A pill pressed is chosen in the panel: the tags are read anew with it, the list is not.
  const lists: string[] = [];
  page.on("request", (request) => {
    if (new URL(request.url()).pathname === "/api/cards") lists.push(request.url());
  });
  const read = page.waitForRequest((request) => chosen(request.url()) !== null);
  await press(page, "lightkeeping");
  expect(chosen((await read).url())).toEqual(["lightkeeping"]);
  await expect(tag(page, "lightkeeping")).toHaveAttribute("aria-pressed", "true");
  // It keeps the focus though the tags were drawn anew.
  await expect(tag(page, "lightkeeping")).toBeFocused();
  // The tags stay where they are. What no card left has cannot be pressed.
  await expect(tags(page)).toHaveText(OSPREY_TAGS);
  await expect(greyed(page)).toHaveText(["duneland"]);
  await expect(clear(page)).toBeEnabled();
  await expect(titles(page)).toHaveText(OSPREY);
  expect(lists).toEqual([]);
  await expect(sorting(page)).toHaveAccessibleName("Sort and filter");

  // Apply asks for the list with the tag, closes the panel and gives the focus back to the button, which says so.
  const asked = page.waitForRequest((request) => asksFor(request.url(), "osprey"));
  await applied(page);
  expect(new URL((await asked).url()).searchParams.getAll("tag")).toEqual(["lightkeeping"]);
  await expect(titles(page)).toHaveText(["Osprey Anchor", "Osprey Beacon"]);
  await expect(sorting(page)).toHaveAccessibleName("Sort and filter: 1 tag chosen");
  await expect(sorting(page)).toHaveClass(/\bon\b/);
  await expect(sorting(page)).toBeFocused();

  // Both tags: the one card that has both, where each alone leaves two and three.
  await open(page);
  await expect(pressed(page)).toHaveText(["lightkeeping"]);
  await press(page, "nightwatch");
  await expect(greyed(page)).toHaveText(["duneland", "R&D, mostly", "Slow Tide"]);
  await expect(pressed(page)).toHaveText(["lightkeeping", "nightwatch"]);
  await applied(page);
  await expect(titles(page)).toHaveText(["Osprey Beacon"]);
  await expect(sorting(page)).toHaveAccessibleName("Sort and filter: 2 tags chosen");

  // One unpressed. The search goes on finding the archived card, and lists it last.
  await choose(page, "lightkeeping");
  await expect(titles(page)).toHaveText(["Osprey Beacon", "Osprey Cove", "Osprey Dune"]);
  await choose(page, "nightwatch");
  await expect(titles(page)).toHaveText(OSPREY);
  await expect(sorting(page)).toHaveAccessibleName("Sort and filter");
  await expect(sorting(page)).not.toHaveClass(/\bon\b/);

  // A tag is found whatever its case, and one with a space, a comma and an "&" as it is written.
  await choose(page, "harbourage");
  await expect(titles(page)).toHaveText(["Osprey Anchor", "Osprey Beacon", "Osprey Cove"]);
  await choose(page, "R&D, mostly", "Slow Tide");
  await expect(titles(page)).toHaveText(["Osprey Anchor"]);
  await expect(sorting(page)).toHaveAccessibleName("Sort and filter: 3 tags chosen");
});
