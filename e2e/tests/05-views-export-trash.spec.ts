import { readFileSync } from "node:fs";
import type { APIRequestContext, Page } from "@playwright/test";
import { chooseView, expect, test, viewLine } from "../test";
import { cardFile, ccv4File, readCard, type CardParts } from "../card";

// The library's three views (list, Gallery and Discovery, chosen in the view menu), a card's export from its row, with the texts'
// history where the switch in Settings › Data asks for it, and the Trash's Restore of a card with its chats.
//
// One database for the file: the tests look only at their own cards, found by search. `find` searches and
// `rest` waits until the list lies still (why: ../test.ts); `fillTrash` puts what the Trash's test needs
// there, past the page.
test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const search = (page: Page) => page.getByLabel("Search characters");
const row = (page: Page, title: string) => page.locator(".card-row", { hasText: title });
const toast = (page: Page) => page.locator("#toast");

/** A card with two characters. */
const PIER = `
spec = "ccv4:1.0.0"

[meta-info]
title = "The Vellum Pier"
tags = ["vellum"]

[name.una]
text = "Una"

[name.odo]
text = "Odo"

[greeting.una]
text = "Una waves."

[character.una]
name-card = "Una (pilot)"
name-char = "name.una"
greetings = ["greeting.una"]
prompt = ["name.una", "CHAT-HISTORY"]

[character.odo]
name-card = "Odo (diver)"
name-char = "name.odo"
prompt = ["name.odo", "CHAT-HISTORY"]
`;

const ids: Record<"vera" | "vito" | "pier" | "bare", number> = { vera: 0, vito: 0, pier: 0, bare: 0 };

async function add(request: APIRequestContext, file: Buffer): Promise<number> {
  const response = await request.post("/api/cards", { data: file });
  expect(response.status()).toBe(201);
  return (await response.json()).card_id;
}

test.beforeAll(async ({ request }) => {
  const vera = { name: "Vera Vellum", tags: ["vellum", "ink"], first_mes: "*Vera looks up.* Hello {{user}}.", description: "A scribe." };
  // Vera has a picture, upright; the others carry the one-pixel stub of a card made without art.
  ids.vera = await add(request, cardFile(vera, [40, 60]));
  ids.vito = await add(request, cardFile({ name: "Vito Vellum", tags: ["vellum"], first_mes: "Vito nods." }));
  ids.pier = await add(request, ccv4File(PIER));
  ids.bare = await add(request, ccv4File('spec = "ccv4:1.0.0"\n\n[meta-info]\ntitle = "Bare Vellum"\ntags = ["vellum"]\n'));
});

/** Waits until what the page was just told (an answer, a scroll) has been shown. */
const rest = (page: Page) => page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));

/**
 * Searches for this file's cards. The search waits for the typing to pause and
 * draws the list anew then: only after that answer is the list at rest.
 */
async function find(page: Page): Promise<void> {
  if ((await search(page).inputValue()) === "vellum") return;
  const answered = page.waitForResponse((response) => /\/api\/cards\?(.*&)?q=vellum(&|$)/.test(response.url()));
  await search(page).fill("vellum");
  await (await answered).finished();
  await rest(page);
}

/** Opens the library with this file's cards, by name: the bare one, the pier, Vera, Vito. */
async function vellum(page: Page): Promise<void> {
  await page.goto("/#/library");
  await page.getByRole("button", { name: /^Sort and filter/ }).click();
  const panel = page.getByRole("dialog", { name: "Sort and filter" });
  await panel.getByRole("button", { name: "Name", exact: true }).click();
  await panel.getByRole("button", { name: "Apply" }).click();
  await expect(panel).toHaveCount(0);
  await find(page);
  await expect(page.locator(".rows-plain .row-title, .tile-title, .entry-title")).toHaveText(["Bare Vellum", "The Vellum Pier", "Vera Vellum", "Vito Vellum"]);
}

/** Does what starts a download, and returns the file's name and what the card file holds. */
async function saved(page: Page, start: () => Promise<void>): Promise<{ name: string; card: CardParts }> {
  const [download] = await Promise.all([page.waitForEvent("download"), start()]);
  return { name: download.suggestedFilename(), card: readCard(readFileSync(await download.path())) };
}

async function exportFromRow(page: Page, title: string): Promise<void> {
  await row(page, title).hover();
  await row(page, title).getByRole("button", { name: "More" }).click();
  await item(page, "Export as card file").click();
}

// The library's views.

test("the view menu lays the cards out as a list, a grid or large entries, and stays as it was left", async ({ page }) => {
  await vellum(page);
  const ticked = async (name: string) => {
    await expect(await viewLine(page, name)).toHaveAttribute("aria-checked", "true");
    await page.keyboard.press("Escape");
  };
  await ticked("List");
  await expect(page.getByRole("group", { name: "View" })).toHaveCount(0);
  await expect(page.locator(".card-row")).toHaveCount(4);
  await expect(page.locator(".entry")).toHaveCount(0);

  await chooseView(page, "Gallery");
  await expect(page.locator("[role=menu][aria-label=View]:visible")).toHaveCount(0);
  await ticked("Gallery");
  await expect(page.locator(".tile")).toHaveCount(4);
  await expect(page.locator(".card-row")).toHaveCount(0);

  await chooseView(page, "Discovery");
  await expect(page.locator(".tile")).toHaveCount(0);
  await expect(page.locator(".entry")).toHaveCount(4);
  await expect(page.locator(".card-row")).toHaveCount(0);
  // The search, the filter and the order are the list's.
  await expect(page.locator(".entry-title")).toHaveText(["Bare Vellum", "The Vellum Pier", "Vera Vellum", "Vito Vellum"]);
  await search(page).fill("vellum ink");
  await expect(page.locator(".entry-title")).toHaveText(["Vera Vellum"]);

  // Coming back from another screen shows the same view, and so does the next start.
  await page.getByRole("link", { name: "Chats", exact: true }).click();
  await page.locator("#rail").getByRole("link", { name: "Characters", exact: true }).click();
  await expect(page.locator(".entry-title")).toHaveText(["Vera Vellum"]);
  await page.reload();
  await expect(page.locator(".entry").first()).toBeVisible();
  await ticked("Discovery");
  await expect(page.locator(".card-row")).toHaveCount(0);
  await chooseView(page, "List");
  await expect(page.locator(".card-row").first()).toBeVisible();
  await page.reload();
  await ticked("List");
  await expect(page.locator(".card-row").first()).toBeVisible();
  await expect(page.locator(".entry")).toHaveCount(0);
});

test("a theme chosen in the view menu shows in Settings at once, and one picked there keeps the field's focus", async ({ page }) => {
  await page.goto("/#/settings");
  const field = page.getByRole("button", { name: "Theme" });
  await chooseView(page, "Dark");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await expect(field).toHaveText("Dark");
  await field.click();
  await page.getByRole("menuitemradio", { name: "Neon Wave light" }).click();
  await expect(field).toHaveText("Neon Wave light");
  await expect(field).toBeFocused();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "neonwave-light");
  await expect(await viewLine(page, "Neon Wave light")).toHaveAttribute("aria-checked", "true");
});

test("a look chosen dresses the whole app at once, stays at the next start, and Compact still shrinks it", async ({ page }) => {
  await page.goto("/#/library");
  const html = page.locator("html");
  const token = (name: string) => html.evaluate((root, name) => getComputedStyle(root).getPropertyValue(name).trim(), name);
  await chooseView(page, "Outrun");
  await expect(html).toHaveAttribute("data-theme", "outrun");
  expect(await token("--page")).toBe("#140832");
  await expect(page.locator("body")).toHaveCSS("font-family", /^"Exo 2"/);
  expect(await html.evaluate(async () => (await document.fonts.load('16px "Michroma"')).length)).toBe(1);
  await page.reload();
  await expect(html).toHaveAttribute("data-theme", "outrun");
  await chooseView(page, "Compact");
  await expect(html).toHaveAttribute("data-density", "compact");
  expect(await token("--s16")).toBe("12px");
  expect(await token("--page")).toBe("#140832");
  await page.keyboard.press("Escape"); // Compact leaves the menu open
  await chooseView(page, "Retrowave");
  expect(await token("--page")).toBe("#ffe6c4");
  await expect(html).toHaveCSS("color-scheme", "light");
});

// Export.

test("Export in a row's menu saves the card as a SillyTavern card, named after it", async ({ page }) => {
  await vellum(page);
  const { name, card } = await saved(page, () => exportFromRow(page, "Vera Vellum"));
  expect(name).toBe("Vera Vellum.png");
  expect(card.sillytavern.ccv3.spec).toBe("chara_card_v3");
  expect(card.sillytavern.chara.spec).toBe("chara_card_v2");
  for (const written of [card.sillytavern.ccv3.data, card.sillytavern.chara.data]) {
    expect(written).toMatchObject({ name: "Vera Vellum", description: "A scribe.", first_mes: "*Vera looks up.* Hello {{user}}.", tags: ["vellum", "ink"] });
  }
  expect(card.ccv4).toEqual({});
  await expect(toast(page)).toHaveText("“Vera Vellum” exported.");
});

test("the switch \"Include earlier versions of each text\" puts each text's earlier drafts into a CCV4 card exported", async ({ page, request }) => {
  await vellum(page);
  const edit = await (await request.get(`/api/cards/${ids.vera}/edit`)).json();
  edit.characters[0].description[0].text = "A scribe of the pier.";
  expect((await request.put(`/api/cards/${ids.vera}/edit`, { data: edit })).status()).toBe(200);
  expect((await request.patch("/api/settings", { data: { export_format: "ccv4" } })).status()).toBe(200);
  const files = async () => Object.keys((await saved(page, () => exportFromRow(page, "Vera Vellum"))).card.ccv4);

  // Off at first: the card goes without its history.
  expect(await files()).not.toContain("user/0001_revision.toml");

  await page.goto("/#/settings/advanced");
  const toggle = page.getByRole("switch", { name: "Include earlier versions of each text" });
  await expect(toggle).toBeEnabled();
  await expect(toggle).not.toBeChecked();
  await toggle.click();
  await expect(toggle).toBeChecked();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).export_history).toBe(true);
  await vellum(page);
  expect(await files()).toContain("user/0001_revision.toml");

  expect((await request.patch("/api/settings", { data: { export_format: "sillytavern_v3", export_history: false } })).status()).toBe(200);
});

// The Gallery.

// The Trash.

const trashRow = (page: Page, title: string) => page.locator(".trash .row", { hasText: title });

/** Starts a chat with a card's first character, past the page. Returns the chat's id. */
async function chatWith(request: APIRequestContext, card: number): Promise<number> {
  const detail = await (await request.get(`/api/cards/${card}`)).json();
  const characters = [{ version_id: detail.card.version_id, character: detail.characters[0].id }];
  const response = await request.post("/api/chats", { data: { characters } });
  expect(response.status()).toBe(201);
  return (await response.json()).chat.id;
}

const chats: Record<"vera" | "vito", number> = { vera: 0, vito: 0 };

/** Empties the Trash, then deletes Vito, who has a chat, and one chat with Vera by itself. */
async function fillTrash(request: APIRequestContext): Promise<void> {
  for (const [card, restore] of [[ids.vito, true], [ids.vera, true]] as const) {
    await request.patch(`/api/cards/${card}`, { data: { trashed: !restore } });
  }
  expect((await request.delete("/api/trash")).status()).toBe(204);
  chats.vito ||= await chatWith(request, ids.vito);
  chats.vera = await chatWith(request, ids.vera);
  expect((await request.patch(`/api/chats/${chats.vera}`, { data: { trashed: true } })).status()).toBe(200);
  expect((await request.patch(`/api/cards/${ids.vito}`, { data: { trashed: true } })).status()).toBe(200);
}

async function openTrash(page: Page): Promise<void> {
  await page.goto("/#/settings/trash");
  await expect(page.locator(".trash .row, .rows-plain .meta").first()).toBeVisible();
}

test("Restore brings an item back from the Trash, a card with its chats", async ({ page, request }) => {
  await fillTrash(request);
  await openTrash(page);
  await trashRow(page, "Vito Vellum").getByRole("button", { name: "Restore" }).click();
  await expect(toast(page)).toHaveText("“Vito Vellum” restored.");
  await expect(page.locator(".trash .row .ttl")).toHaveText(["Vera Vellum"]);
  expect((await (await request.get(`/api/cards/${ids.vito}`)).json()).card.trashed).toBe(false);
  expect((await (await request.get(`/api/chats/${chats.vito}`)).json()).chat.trashed).toBe(false);

  await page.locator(".trash .row").getByRole("button", { name: "Restore" }).click();
  await expect(page.getByText("The Trash is empty.")).toBeVisible();
  await expect(button(page, "Empty Trash")).toHaveCount(0);
  expect((await (await request.get(`/api/chats/${chats.vera}`)).json()).chat.trashed).toBe(false);
  // It is among the chats again.
  await page.goto("/#/chats");
  await expect(page.locator(`#view a[href="#/chats/${chats.vera}"]`)).toBeVisible();
});

test("Delete forever asks with the item's name and its chats, and its button says Delete forever", async ({ page, request }) => {
  await fillTrash(request);
  await openTrash(page);
  const vito = trashRow(page, "Vito Vellum");
  await expect(vito.getByRole("button", { name: "Restore" })).toHaveAttribute("title", "Brings back the character and its chat");
  await vito.getByRole("button", { name: "Delete forever" }).click();
  await expect(vito).toContainText("Delete “Vito Vellum” and its chat forever? They can’t be brought back.");
  await vito.getByRole("button", { name: "Delete forever" }).click();
  await expect(page.locator(".trash .row .ttl")).toHaveText(["Vera Vellum"]);
});
