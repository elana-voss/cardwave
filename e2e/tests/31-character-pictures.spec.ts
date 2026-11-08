import { readFileSync } from "node:fs";
import type { APIRequestContext, Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { ccv4File, pictureFile } from "../card";
import { NOW, picture, SIZES, stopClock, storeModel, THEMES } from "../pictures";

// Pictures of a card's screens, each compared with its stored picture, pixel by pixel, at 1440 px in the
// light theme (CLAUDE.md, "Pictures of the screens"): the card's page with its menu open, a text's earlier
// drafts with one pressed, a new card with its first message being written, and the dialogs "Make a picture"
// and "Earlier pictures". The database is this spec's own: a card, five chats and six lorebooks; the
// dialogs' pictures, words and days are answered by the spec (`pictured`), as no model is asked.
//
// The pictures are `character`, `card-drafts`, `new-card`, `make-picture`, `earlier-pictures`, `add-expressions` and `add-figure`. `protector`
// is the card of one character that the pages are pictured of, its personality edited once, on a day the spec answers (`dated`: the day is
// written out in full, and the server edited it today; so too its drafts'). `open` waits for the server's `hello` and the card's picture before anything
// is scrolled or opened (why: ../pictures.ts).

const LONG = Array.from({ length: 6 }, (_, at) => `Paragraph ${at + 1} of the description: who she is at court, what she has sworn, and what she keeps to herself when the hall is full.`).join("\n\n");

/** A card file of the title, with Guinivere as told. */
function file(title: string, personality: string): Buffer {
  const text = (words: string) => JSON.stringify(words);
  return ccv4File(
    `
spec = "ccv4:1.0.0"

[meta-info]
title = ${text(title)}
tags = ["knight", "court intrigue", "slow burn"]
creator = "elana"

[name.guin]
text = "Guinivere"

[description.guin]
text = ${text(LONG)}

[personality.guin]
text = ${text(personality)}

[scenario.guin]
text = "The court is at feast. {{user}} has just arrived."

[dialogue-example.guin]
text = "{{user}}: Is the queen safe?\\n{{char}}: While I stand."

[greeting.one]
text = ${text('*The morning sun filtered through the heavy velvet curtains of my chambers.* "The castle is quiet," *she murmured,* "too quiet for my liking."\n\nShe does not turn from the window.')}

[greeting.two]
text = ${text('*She does not look up from her letters.* "You are late."')}

[greeting.three]
text = "Draw, then."

[creator-note.guin]
text = "Best with a patient persona."

[character.guin]
name-card = "Guinivere"
name-char = "name.guin"
greetings = ["greeting.one", "greeting.two", "greeting.three"]
creator-note = "creator-note.guin"
prompt = ["name.guin", "description.guin", "personality.guin", "scenario.guin", "dialogue-example.guin", "LOREBOOK", "CHAT-HISTORY"]
`,
    [300, 450],
  );
}

/** The card of one character, edited once, and the card of two. */
let protector = 0;

async function make(request: APIRequestContext): Promise<void> {
  await storeModel(request, "picture-model");
  const posted = async (path: string, data: unknown) => {
    const made = await request.post(path, { data });
    expect(made.status(), await made.text()).toBe(201);
    return made.json();
  };
  protector = (await posted("/api/cards", file("The Royal Protector", "Dry, watchful."))).card_id;
  const edit = await (await request.get(`/api/cards/${protector}/edit`)).json();
  edit.characters[0].personality[0].text = "Dry, watchful, exact.";
  expect((await request.put(`/api/cards/${protector}/edit`, { data: edit })).status()).toBe(200);
  expect((await request.patch(`/api/cards/${protector}`, { data: { favorite: true } })).status()).toBe(200);
  const { card } = await (await request.get(`/api/cards/${protector}`)).json();
  for (let chat = 0; chat < 5; chat++) await posted("/api/chats", { characters: [{ version_id: card.version_id, character: "guin" }] });
  const world = (name: string) => JSON.stringify({ description: name, entries: { 0: { uid: 0, key: [], comment: name, content: `${name}.`, constant: true } } });
  const books = ["Kingdom of Camlann", "The Council of Twelve", "Old Roads", "The Royal Guard", "Houses of the North", "Moor"];
  for (const name of books) {
    const { lorebook } = await posted(`/api/lorebooks?name=${encodeURIComponent(name)}.json`, Buffer.from(world(name)));
    // All but the last are the card's; the last is the one "+" has to offer.
    if (name !== "Moor") expect((await request.post(`/api/cards/${protector}/lorebooks`, { data: { lorebook_id: lorebook.id } })).status()).toBe(200);
  }
  // Two expression packs: "Court", which no card has, and "Guinivere", the card's.
  const pack = async (name: string, moods: string[]) => {
    const files = moods.map((mood, at) => ({ name: `${mood}.png`, data: pictureFile([40, 60], 0x30 + at * 0x20).toString("base64") }));
    const given = await request.post(`/api/cards/${protector}/expressions`, { data: { name, files } });
    expect(given.status(), await given.text()).toBe(200);
    return (await given.json()).pack.id;
  };
  const court = await pack("Court", ["anger", "joy", "neutral"]);
  await pack("Guinivere", ["admiration", "amusement", "anger", "caring", "joy", "pride", "neutral"]);
  expect((await request.patch(`/api/expressions/${court}`, { data: { trashed: false } })).status()).toBe(204);
  // Two figures with stills of grey: "Knight", which no card has, and "Guinivere", the card's.
  const figure = async (file: string, name: string, grey: number) => {
    const data = { file_name: name, data: readFileSync(`figures/${file}`).toString("base64"), still: pictureFile([48, 48], grey).toString("base64"), mode: null };
    const given = await request.post(`/api/cards/${protector}/figures`, { data });
    expect(given.status(), await given.text()).toBe(200);
    return (await given.json()).figures.figure.id;
  };
  const knight = await figure("mixamo.glb", "Knight.glb", 0x50);
  await figure("mannequin.vrm", "Guinivere.vrm", 0xb0);
  expect((await request.patch(`/api/figures/${knight}`, { data: { trashed: false } })).status()).toBe(204);
}

test.beforeAll(({ request }) => make(request));

/** The day the page is told `protector` was edited on, at noon. */
const EDITED = Date.UTC(2025, 9, 12, 12);

/** Has the page told that `protector` was edited on `EDITED`, and its drafts saved then: the server saved them today. */
async function dated(page: Page): Promise<void> {
  await page.route(
    (url) => url.pathname === `/api/cards/${protector}`,
    async (route) => {
      if (route.request().method() !== "GET") return route.fallback();
      const response = await route.fetch();
      await route.fulfill({ response, json: { ...(await response.json()), edited_at: EDITED } });
    },
  );
  // A text's drafts, an hour apart, the newest on that day.
  await page.route(
    (url) => url.pathname === `/api/cards/${protector}/drafts`,
    async (route) => {
      const response = await route.fetch();
      const drafts = (await response.json()) as { drafts: { saved: number }[]; deleted: { saved: number }[] };
      const at = (list: { saved: number }[]) => list.map((draft, back) => ({ ...draft, saved: EDITED - back * 3_600_000 }));
      await route.fulfill({ response, json: { drafts: at(drafts.drafts), deleted: at(drafts.deleted) } });
    },
  );
}

// The rail's Guinivere chats say their day and time, made on the real clock: masked, so the pictures hold.
const chats = (page: Page) => [page.locator(".nav-chat", { hasText: "Guinivere" })];
const field = (page: Page, name: string) => page.getByRole("textbox", { name, exact: true });

/**
 * Opens a page of `protector` and waits for its box and for its picture, after which nothing on it moves. The
 * server's first `hello` on the socket has the page read the card anew and draw it again (`onConnected`), which
 * closes a menu opened before it: in a whole run it came late once, so `open` waits for it and for that reading.
 */
async function open(page: Page, address: string): Promise<void> {
  const heard = page.waitForEvent("websocket").then((socket) => socket.waitForEvent("framereceived", (frame) => String(frame.payload).includes('"hello"')));
  await page.goto(address);
  await heard;
  await page.waitForLoadState("networkidle");
  await expect(page.locator(".part").last()).toBeVisible();
  await expect.poll(() => page.locator(".hero-picture img").evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0)).toBe(true);
}

/** Answers the card's pictures as the spec has them: four, each of its own grey, on days of their own; and the words and pictures "Make a picture" is given. */
async function pictured(page: Page): Promise<void> {
  const list = [
    { id: 901, source: "imported", added_at: NOW.getTime(), in_use: true },
    { id: 902, source: "made", added_at: NOW.getTime(), in_use: false },
    { id: 903, source: "file", added_at: Date.UTC(2025, 9, 12, 12), in_use: false },
    { id: 904, source: "imported", added_at: Date.UTC(2025, 9, 3, 12), in_use: false },
  ];
  await page.route(`**/api/cards/${protector}/pictures`, (route) => route.fulfill({ json: list }));
  await page.route(`**/api/cards/${protector}/pictures/9*`, (route) => {
    const grey = 0x30 + (Number(route.request().url().slice(-1)) % 5) * 0x28;
    return route.fulfill({ contentType: "image/png", body: pictureFile([240, 360], grey) });
  });
  await page.route("**/api/images", (route) => route.fulfill({ json: { model: "gpt-image-1", base_url: null, has_key: false, key_end: null } }));
  const words = "A woman knight in silver armour at a tall castle window, morning light through heavy velvet curtains, watchful grey eyes, dark hair tied back, a sword at her side, painted in warm oils.";
  await page.route(`**/api/cards/${protector}/pictures/words`, (route) => route.fulfill({ json: { words, provider: "OpenAI" } }));
  let made = 0;
  await page.route(`**/api/cards/${protector}/pictures/made`, (route) => route.fulfill({ status: 201, json: { ...list[++made % 2 ? 1 : 2], in_use: false } }));
}

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;
    /** The pointer leaves for the window's corner, where it points at nothing. */
    const away = (page: Page) => page.mouse.move(width - 2, height - 2);

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(async ({ page }) => {
        await stopClock(page);
        await dated(page);
      });

      test("the card's page: its picture, title and buttons, the star, and its menu open", async ({ page }) => {
        await open(page, `/#/library/${protector}`);
        // In the narrow window the card's head is stacked, and the menu would open under the window's foot: the
        // page stands where its title is at the top, so that the menu's opening does not move it.
        if (width <= 600) await page.locator(".hero-text").evaluate((node) => node.scrollIntoView({ block: "start" }));
        await page.locator(".hero-acts").getByRole("button", { name: "Character menu" }).click();
        await page.getByRole("menuitem", { name: "Archive" }).hover();
        await expect(page.getByRole("menuitem", { name: "Move to Trash" })).toBeInViewport({ ratio: 1 });
        await picture(page, named("character"), chats(page));
      });

      test("the card's page in Details: the picture and its box at the left, the texts as lines at the right", async ({ page }) => {
        await open(page, `/#/library/${protector}`);
        await chooseView(page, "Details");
        await expect(page.locator(".cdv")).toBeVisible();
        await away(page);
        await picture(page, named("card-details"), chats(page));
      });

      test("a text's earlier drafts: the list under its clock, and the draft pressed shown against the text", async ({ page }) => {
        await open(page, `/#/library/${protector}`);
        const personality = page.locator("section.tb", { has: page.getByRole("heading", { name: "Personality", exact: true }) });
        await personality.scrollIntoViewIfNeeded();
        await personality.hover();
        await personality.getByRole("button", { name: "Earlier versions of Personality" }).click();
        await page.getByRole("menuitem").nth(1).click();
        await expect(personality.locator("del.ch")).toBeVisible();
        await away(page);
        await picture(page, named("card-drafts"), chats(page));
      });

      test("a new card: the empty page with its title written and its first message being written", async ({ page }) => {
        await page.goto("/#/library/new");
        await field(page, "Title").fill("The Lighthouse Keeper");
        await page.locator(".tb-body").first().click();
        await field(page, "First message").fill("*The lamp turns above you.* \"You came on the last boat.\"");
        await away(page);
        await picture(page, named("new-card"), chats(page));
      });

      test("Make a picture: the words the AI wrote of the card, and the first of two pictures made", async ({ page }) => {
        await pictured(page);
        await open(page, `/#/library/${protector}`);
        await page.locator(".hero-picture").hover();
        await page.getByRole("button", { name: "Make a picture" }).click();
        const making = page.getByRole("dialog", { name: "Make a picture" });
        await expect(making.getByRole("img", { name: "The new picture" })).toBeVisible();
        await making.getByRole("button", { name: "Draw again from these words" }).click();
        await making.getByRole("button", { name: "Previous picture" }).click();
        await expect(making.getByText("1 of 2")).toBeVisible();
        await away(page);
        await picture(page, named("make-picture"), chats(page));
      });

      test("Earlier pictures: every picture the card had, with where it came from and its day, one chosen", async ({ page }) => {
        await pictured(page);
        await open(page, `/#/library/${protector}`);
        await page.locator(".hero-picture").hover();
        await page.getByRole("button", { name: "Earlier pictures" }).click();
        const earlier = page.getByRole("dialog", { name: "Earlier pictures" });
        await expect.poll(() => earlier.locator(".thumb img").evaluateAll((all: HTMLImageElement[]) => all.length === 4 && all.every((image) => image.complete && image.naturalWidth > 0))).toBe(true);
        await earlier.locator(".thumb").nth(1).click();
        await away(page);
        await picture(page, named("earlier-pictures"), chats(page));
      });

      test("Add expressions: the packs the app holds, one chosen", async ({ page }) => {
        await open(page, `/#/library/${protector}`);
        await page.getByRole("button", { name: "Add expressions" }).click();
        const adding = page.getByRole("dialog", { name: "Add expressions" });
        await adding.getByRole("button", { name: /Court/ }).click();
        await expect.poll(() => adding.locator(".strip img").evaluateAll((all: HTMLImageElement[]) => all.every((image) => image.complete && image.naturalWidth > 0))).toBe(true);
        await away(page);
        await picture(page, named("add-expressions"), chats(page));
      });

      test("Add a 3D figure: the figures the app holds, the card's chosen", async ({ page }) => {
        await open(page, `/#/library/${protector}`);
        await page.getByRole("button", { name: "Add a 3D figure" }).click();
        const adding = page.getByRole("dialog", { name: "Add a 3D figure" });
        await expect.poll(() => adding.locator("img.fig").evaluateAll((all: HTMLImageElement[]) => all.length === 2 && all.every((image) => image.complete && image.naturalWidth > 0))).toBe(true);
        await away(page);
        await picture(page, named("add-figure"), chats(page));
      });

    });
  }
}
