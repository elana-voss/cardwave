import { readFileSync } from "node:fs";
import type { Download, Page } from "@playwright/test";
import { cardFile } from "../card";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";

// Run-through "working with cards": a user's work with a card and its chat, by clicks and typing alone, each story
// going on from the one before (`serial`). The start is where 90's stories end, made through `request`: the stand-in
// `api` the chat model, a card this file builds (`CARD`) imported, a chat with her greeting. The card is edited (her name
// in chats and her description) and the chat shows the name and sends the description; the chat is continued,
// swiped and found again by Ctrl+K; the chat is exported with its messages and versions (a chat is not imported
// back: "A chat file imported" is a Won't do of the plan); the card is exported, moved to the Trash (its chat with
// it) and imported back as it was edited. Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (10,
// 03, 78, 05, 15).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;

const GREETING = "Oh, hello there! I didn't hear you come in. Welcome to the Grand Archives. Are you looking for something specific, or just browsing the stacks?";
const CARD = cardFile({
  name: "Aria",
  nickname: "Aria the Librarian",
  description: "Aria tends the archives.",
  first_mes: GREETING,
});
const NAME = "Aria Vell";
const DESCRIPTION = "Aria keeps the Grand Archives and knows where every star chart lies.";
const QUESTION = "Where are the star charts?";
const FIRST = "The east wing holds them.";
const SECOND = "Up the spiral stair, in the east wing.";

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "key-run-through-0123456789" })).status()).toBe(200);
  const imported = await request.post("/api/cards", { data: CARD });
  expect(imported.status(), await imported.text()).toBe(201);
  const { version_id } = await imported.json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id, character: "aria" }] } });
  expect(started.status(), await started.text()).toBe(201);
});
test.afterAll(() => api.close());

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const rail = (page: Page, name: string) => page.locator("#rail").getByRole("link", { name, exact: true });
const texts = (page: Page) => page.locator(".message .text");
const newest = (page: Page) => page.locator(".message").last();
/** A text of the card on its page, by its name, as it shows while not written in. */
const shows = (page: Page, name: string) => page.locator(".reading section.tb", { has: page.getByRole("heading", { name, exact: true }) }).locator(".tb-body");
const toast = (page: Page) => page.locator("#toast span");

/** Opens the chat from the list of chats. */
async function openChat(page: Page): Promise<void> {
  await page.goto("/#/chats");
  await page.locator("main").getByRole("link", { name: new RegExp(NAME.split(" ")[0]) }).first().click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(texts(page).first()).toHaveText(GREETING);
}

/** Does what starts a download and returns it. */
async function downloaded(page: Page, start: () => Promise<void>): Promise<Download> {
  const [download] = await Promise.all([page.waitForEvent("download"), start()]);
  return download;
}

test("the card is edited on its page, and the chat shows her new name in chats and sends her new description", async ({ page }) => {
  await page.goto("/#/chats");
  await rail(page, "Characters").click();
  await page.getByRole("link", { name: "Aria", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Aria", level: 1 })).toBeVisible();
  await shows(page, "Description").click();
  const description = page.getByRole("textbox", { name: "Description", exact: true });
  await description.fill(DESCRIPTION);
  await description.evaluate((node) => (node as HTMLElement).blur());
  await expect(shows(page, "Description")).toHaveText(DESCRIPTION);
  await page.locator(".side").getByText("Aria the Librarian", { exact: true }).click();
  await page.getByRole("textbox", { name: "Name in the chat", exact: true }).fill(NAME);
  await page.getByRole("textbox", { name: "Name in the chat", exact: true }).press("Enter");
  await expect(page.locator(".side")).toContainText(`Plays ${NAME}`);

  await openChat(page);
  await expect(page.locator(".message").first()).toContainText(NAME);
  api.next([FIRST]);
  const composer = page.getByLabel("Message", { exact: true });
  await composer.fill(QUESTION);
  await composer.press("Enter");
  await expect(texts(page)).toHaveText([GREETING, QUESTION, FIRST]);
  expect(JSON.stringify(api.asked.at(-1)?.body.messages)).toContain(DESCRIPTION);
});

test("the chat is continued, swiped, and found again by Ctrl+K from another screen", async ({ page }) => {
  await openChat(page);
  await expect(texts(page)).toHaveText([GREETING, QUESTION, FIRST]);
  api.next([SECOND]);
  await button(page, "Write again").click();
  await expect(texts(page)).toHaveText([GREETING, QUESTION, SECOND]);
  await expect(newest(page).locator(".count")).toHaveText("2 / 2");
  await newest(page).getByRole("button", { name: "Previous version" }).click();
  await expect(newest(page).locator(".count")).toHaveText("1 / 2");
  await expect(texts(page)).toHaveText([GREETING, QUESTION, FIRST]);
  api.next(["Mind the third step."]);
  const composer = page.getByLabel("Message", { exact: true });
  await composer.fill("Thank you.");
  await composer.press("Enter");
  await expect(texts(page)).toHaveText([GREETING, QUESTION, FIRST, "Thank you.", "Mind the third step."]);

  await rail(page, "Characters").click();
  await expect(page.getByRole("link", { name: "Aria", exact: true })).toBeVisible();
  await page.keyboard.press("Control+k");
  const search = page.getByRole("dialog", { name: "Search Cardwave" });
  await search.getByRole("searchbox", { name: "Search Cardwave" }).fill("aria");
  await search.getByRole("group").filter({ hasText: /^Chats/ }).locator(".hit").first().click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(texts(page)).toHaveText([GREETING, QUESTION, FIRST, "Thank you.", "Mind the third step."]);
});

test("the chat is exported with its messages and the versions of the swiped reply", async ({ page }) => {
  await openChat(page);
  await button(page, "Chat options").click();
  const file = await downloaded(page, () => item(page, "Export").click());
  expect(file.suggestedFilename()).toMatch(/\.jsonl$/);
  await expect(toast(page)).toHaveText("Chat exported.");
  const lines = readFileSync(await file.path(), "utf8").split("\n").map((line) => JSON.parse(line));
  expect(lines[0]).toMatchObject({ character_name: NAME });
  expect(lines.slice(1).map((line) => [line.name, line.mes])).toEqual([
    [NAME, GREETING],
    ["Guest", QUESTION],
    [NAME, FIRST],
    ["Guest", "Thank you."],
    [NAME, "Mind the third step."],
  ]);
  expect(lines[3].swipes).toEqual([FIRST, SECOND]);
});

test("the card is exported, moved to the Trash, and imported back as it was edited", async ({ page }) => {
  await page.goto("/#/chats");
  await rail(page, "Characters").click();
  const row = page.locator(".card-row", { hasText: "Aria" });
  await row.hover();
  await row.getByRole("button", { name: "More" }).click();
  const file = await downloaded(page, () => item(page, "Export as card file").click());
  expect(file.suggestedFilename()).toBe("Aria.png");
  await expect(toast(page)).toHaveText("“Aria” exported.");
  await row.hover();
  await row.getByRole("button", { name: "More" }).click();
  await item(page, "Move to Trash").click();
  await expect(row).toHaveCount(0);

  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  const chooser = page.waitForEvent("filechooser");
  await item(page, "Import card").click();
  await (await chooser).setFiles({ name: "Aria.png", mimeType: "image/png", buffer: readFileSync(await file.path()) });
  await expect(toast(page)).toHaveText(/^“Aria” imported\./);
  await page.getByRole("link", { name: "Aria", exact: true }).click();
  await expect(page.locator(".side")).toContainText(`Plays ${NAME}`);
  await expect(shows(page, "Description")).toHaveText(DESCRIPTION);
});
