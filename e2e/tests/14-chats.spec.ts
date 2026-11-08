import type { APIRequestContext, Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile, ccv4File } from "../card";

// The list of chats: a chat's line shows its picture, the others in it, its card and the newest message, and
// opens the chat.
//
// One database for the file. Every chat is put into the Trash before each test, so that the list holds what
// the test made. `press` presses the mouse on a part of a row, over which the row's link lies (why:
// ../test.ts).
test.describe.configure({ mode: "serial" });

const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
/** Presses the mouse in the middle of a part of a row: the row's link lies over its picture and its words. */
async function press(page: Page, part: Locator, button: "left" | "right" = "left"): Promise<void> {
  // boundingBox does not wait, and is null where the list is drawn anew after coming back.
  let at = null;
  while (!at) {
    await expect(part).toBeVisible();
    at = await part.boundingBox();
  }
  await page.mouse.click(at.x + at.width / 2, at.y + at.height / 2, { button });
}
const titles = (page: Page) => page.locator(".card-row .row-title");
const row = (page: Page, name: string) => page.locator(".card-row", { hasText: name });
const star = (page: Page, name: string) => row(page, name).getByRole("button", { name: "Favourite" });
const more = (page: Page, name: string) => row(page, name).getByRole("button", { name: "More" });

/** A card of Una, called otherwise, with a picture. */
const TERN = `
spec = "ccv4:1.0.0"

[meta-info]
title = "Tern Rock"

[name.una]
text = "Una"

[greeting.gulls]
text = "The *gulls* are loud today."

[character.una]
name-card = "Una"
name-char = "name.una"
greetings = ["greeting.gulls"]
prompt = ["name.una", "CHAT-HISTORY"]
`;

/** Puts every chat into the Trash, where the list does not look. */
test.beforeEach(async ({ request }) => {
  const listed = async (path: string): Promise<{ id: number }[]> => (await request.get(path)).json();
  for (const { id } of [...(await listed("/api/chats")), ...(await listed("/api/chats?show=archived"))]) {
    expect((await request.patch(`/api/chats/${id}`, { data: { trashed: true } })).status()).toBe(200);
  }
});

/** Imports a card past the page and returns the id of its version. */
async function add(request: APIRequestContext, file: Buffer): Promise<number> {
  const response = await request.post("/api/cards", { data: file });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).version_id;
}

/** Starts a chat past the page, with the changes named. Returns its id. */
async function start(request: APIRequestContext, characters: { version_id: number; character: string }[], change?: Record<string, boolean>): Promise<number> {
  const response = await request.post("/api/chats", { data: { characters } });
  expect(response.status(), await response.text()).toBe(201);
  const { id } = (await response.json()).chat;
  if (change) expect((await request.patch(`/api/chats/${id}`, { data: change })).status()).toBe(200);
  return id;
}

/** A card of its own with one character, and a chat with it, which is called as the card is. Returns the chat's id. */
async function chatWith(request: APIRequestContext, name: string, change?: Record<string, boolean>): Promise<number> {
  const version_id = await add(request, cardFile({ name, first_mes: `${name} says hello.` }));
  return start(request, [{ version_id, character: name.toLowerCase().replaceAll(" ", "-") }], change);
}

/** A chat with Una of Tern Rock and Odo of a card of his own. Returns its id and the card version Una is with. */
async function ternChat(request: APIRequestContext): Promise<{ chat: number; version: number }> {
  const version = await add(request, ccv4File(TERN, [40, 60]));
  const characters = [
    { version_id: version, character: "una" },
    { version_id: await add(request, cardFile({ name: "Odo" })), character: "odo" },
  ];
  return { chat: await start(request, characters), version };
}

/** Writes a message into a chat past the page, a moment after whatever was written before. */
async function write(page: Page, chat: number, content: string): Promise<void> {
  await page.waitForTimeout(20);
  expect((await page.request.post(`/api/chats/${chat}/messages`, { data: { content } })).status()).toBe(201);
}

async function open(page: Page): Promise<void> {
  await page.goto("/#/chats");
  await expect(page.locator(".rows-plain > li").first()).toBeVisible();
}

/** Leaves for the library and comes back: the list is made and read anew, in the app that kept running. */
async function comeBack(page: Page): Promise<void> {
  await page.goto("/#/library");
  await expect(page.getByLabel("Search characters")).toBeVisible();
  await open(page);
}

test("a chat's line shows its picture, the others in it, its card and the newest message, and opens the chat", async ({ page, request }) => {
  const { chat, version } = await ternChat(request);
  await chatWith(request, "Pell Fenn");
  await open(page);
  await expect(titles(page)).toHaveText(["Pell Fenn", "Una"]);

  // It is called after its first character: the others and their cards are named beside that.
  const una = row(page, "Una");
  await expect(una.locator(".row-head > *")).toHaveText(["Una", "with Odo", "listed in Characters as Tern Rock, Odo"]);
  await expect(una.locator("img.cover")).toHaveAttribute("src", `/api/card-versions/${version}/image?size=96x128`);
  await expect(una.locator(".excerpt")).toHaveText("The gulls are loud today.");
  await expect(una.locator(".last")).toHaveText("Today");
  await expect(una.locator(".last")).toHaveAttribute("title", /^Last message: \d/);
  await expect(star(page, "Una")).toHaveAttribute("aria-pressed", "false");
  await expect(star(page, "Una")).toHaveAttribute("title", "Add to Favourites");
  // A starred row's star is the accent star alone, not a pressed icon button's tinted box.
  await star(page, "Una").click();
  await expect(star(page, "Una")).toHaveAttribute("aria-pressed", "true");
  await page.mouse.move(0, 0);
  await expect(star(page, "Una")).toHaveCSS("background-color", "rgba(0, 0, 0, 0)");
  await star(page, "Una").click();
  await expect(star(page, "Una")).toHaveAttribute("aria-pressed", "false");
  // The search says it finds, and All that it leaves the archived out.
  await expect(page.getByPlaceholder("Find a chat or character")).toBeVisible();
  await expect(page.getByRole("group", { name: "Show" }).getByRole("button", { name: "All" })).toHaveAttribute("title", "All but the archived");
  // A chat with the one character its card is called after says neither.
  await expect(row(page, "Pell Fenn").locator(".row-head > *")).toHaveText(["Pell Fenn"]);
  await expect(row(page, "Pell Fenn").locator(".excerpt")).toHaveText("Pell Fenn says hello.");

  // What was written last, as plain words.
  await write(page, chat, "*Waves* at the `gulls`.");
  await comeBack(page);
  await expect(titles(page)).toHaveText(["Una", "Pell Fenn"]);
  await expect(una.locator(".excerpt")).toHaveText("Waves at the gulls.");

  // All of the line opens the chat: its picture, its words, and the day at its right.
  for (const part of [una.locator("img.cover"), una.locator(".excerpt"), una.locator(".last")]) {
    await press(page, part);
    await expect(page).toHaveURL(new RegExp(`#/chats/${chat}$`));
    await expect(page.locator("#composer")).toBeVisible();
    await open(page);
  }
  // Not the star, and not the line's menu.
  await star(page, "Una").click();
  await expect(star(page, "Una")).toHaveAttribute("aria-pressed", "true");
  await more(page, "Una").click();
  await expect(item(page, "Archive")).toBeVisible();
  await expect(page).toHaveURL(/#\/chats$/);
});

test("a chat's line shows a bin while pointed at, which moves the chat to the Trash with Undo", async ({ page, request }) => {
  const chat = await chatWith(request, "Rook Hale");
  await chatWith(request, "Ivo Marsh");
  await open(page);
  const pell = row(page, "Rook Hale");
  const bin = pell.getByRole("button", { name: "Move to Trash" });
  // It stands with the line's menu, which shows while the line is pointed at.
  const shown = pell.locator(".reveal").filter({ has: page.getByRole("button", { name: "Move to Trash" }) });
  await page.mouse.move(0, 0);
  await expect(shown).toHaveCSS("opacity", "0");
  await pell.hover();
  await expect(shown).toHaveCSS("opacity", "1");

  await bin.click();
  const notice = page.locator("#toast");
  await expect(notice).toContainText("“Rook Hale” moved to Trash.");
  await expect(titles(page)).toHaveText(["Ivo Marsh"]);
  expect((await (await request.get(`/api/chats/${chat}`)).json()).chat.trashed).toBe(true);
  await notice.getByRole("button", { name: "Undo" }).click();
  await expect(titles(page)).toHaveText(["Ivo Marsh", "Rook Hale"]);
});

test("a long list of chats has in the page only the lines in and near the view, and scrolled to its end shows the last", async ({ page, request }) => {
  const version_id = await add(request, cardFile({ name: "Wren Vale" }));
  const made = await Promise.all(Array.from({ length: 120 }, () => start(request, [{ version_id, character: "wren-vale" }])));
  await open(page);
  const lines = page.locator(".card-row");
  await expect(lines.first()).toHaveAttribute("aria-setsize", "120");
  expect(await lines.count()).toBeLessThan(60);
  await lines.first().evaluate((line) => {
    let scroller = line.parentElement!;
    while (scroller.scrollHeight <= scroller.clientHeight) scroller = scroller.parentElement!;
    scroller.scrollTop = scroller.scrollHeight;
  });
  await expect(lines.last()).toHaveAttribute("aria-posinset", "120");
  // The newest written first: the last line is the first chat started.
  await expect(lines.last().locator(".row-link")).toHaveAttribute("href", `#/chats/${Math.min(...made)}`);
});
