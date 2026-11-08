import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { startFakeSearch, type FakeSearch } from "../fake-search";

// Run-through "getting started": a new user's first steps through the whole app, by clicks and typing alone,
// each story going on from the one before (`serial`). First run with the pretend model's key, its downloads
// from fake-search.ts; another provider (the stand-in `api`) added in Settings and its model made the chat
// model; a card this file builds (`CARD`) imported from the fresh start and opened;
// a chat started from its page and answered by the chat model now in use, the stand-in (`REPLY`).
// They are run-throughs of built behaviour: each holds the others' details to their own specs (20, 57, 03, 28).
// Run with RUN_THROUGHS=1 only (playwright.config.ts; tools/check.sh's `run-throughs`).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let search: FakeSearch;

test.beforeAll(async () => {
  [api, search] = await Promise.all([startFakeProvider(), startFakeSearch()]);
  api.models(["tide-1"]);
});
test.afterAll(() => Promise.all([api.close(), search.close()]));

/** A key the pretend model is taken for. */
const PRETEND = "sk-cardwave-fake-0123456789";
/** A key that begins as no provider's does, so the stand-in is added by its address. */
const KEY = "key-run-through-0123456789-7c1d";
const GREETING = "Oh, hello there! I didn't hear you come in. Welcome to the Grand Archives. Are you looking for something specific, or just browsing the stacks?";
const CARD = cardFile({
  name: "Aria",
  nickname: "Aria the Librarian",
  description: "Aria tends the archives.",
  first_mes: GREETING,
});
const REPLY = "The east wing holds the star charts.";

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const heading = (page: Page) => page.locator(".setup h1");
/** What a line of Settings or of first run says under its name. */
const says = (page: Page, name: string) => page.locator(".item:visible", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) }).locator(".item-text > .meta");

test("first run: the pretend key, its models, no folder of cards, the downloads, and into the app", async ({ page }) => {
  await page.goto("/");
  await expect(heading(page)).toHaveText("Provider");
  await page.getByLabel("API key", { exact: true }).fill(PRETEND);
  await expect(page.getByRole("status")).toContainText("Recognised: Pretend model");
  await button(page, "Continue").click();
  await expect(heading(page)).toHaveText("Models");
  await expect(says(page, "Chat")).toHaveText("Pretend Chat · works");
  await page.getByRole("button", { name: "Continue", exact: true }).click();
  await expect(heading(page)).toHaveText("Cards");
  await button(page, "Skip").click();
  await expect(heading(page)).toHaveText("Downloads");
  // Step 4 asks first, the search model on: its button downloads it.
  await page.getByRole("button", { name: /^Download \(.+\)$/ }).click();
  await expect(button(page, "Open Cardwave")).toBeEnabled();
  await button(page, "Open Cardwave").click();
  await expect(page).toHaveURL(/#\/chats$/);
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"]);
});

test("a provider is added in Settings and its model made the chat model", async ({ page }) => {
  await page.goto("/");
  await page.locator("#rail").getByRole("link", { name: "Settings" }).click();
  await expect(says(page, "Chat")).toHaveText("pretend-chat · Pretend model");
  await page.getByRole("link", { name: /^Providers/ }).click();
  await button(page, "Add provider").click();
  const adding = page.getByRole("dialog", { name: "Add provider" });
  await adding.getByLabel("API key", { exact: true }).fill(KEY);
  await adding.getByRole("button", { name: "Enter address", exact: true }).click();
  await adding.getByLabel("Address").fill(api.url);
  await adding.getByRole("button", { name: "Continue", exact: true }).click();
  await expect(adding).toBeHidden();
  await expect(page.locator(".group.provider")).toHaveCount(2);
  await page.getByRole("navigation", { name: "Where you are" }).getByRole("link", { name: "Settings", exact: true }).click();
  await button(page, "Change the chat model").click();
  const picker = page.getByRole("dialog", { name: "Chat model" });
  await picker.getByRole("option", { name: "tide-1" }).click();
  await picker.getByRole("button", { name: "Use this model", exact: true }).click();
  await expect(picker).toBeHidden();
  await expect(says(page, "Chat")).toHaveText("tide-1 · A program on this computer · test passed");
});

test("a test card is imported from the fresh start and opened", async ({ page }) => {
  await page.goto("/");
  await page.locator("#rail").getByRole("link", { name: "Chats", exact: true }).click();
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("group", { name: "Import" }).getByRole("button", { name: "Import card", exact: true }).click();
  await (await chooser).setFiles({ name: "Aria.png", mimeType: "image/png", buffer: CARD });
  await expect(page.locator("#toast span")).toHaveText(/^“Aria” imported\./);
  await page.locator("#rail").getByRole("link", { name: "Characters" }).click();
  await page.getByRole("link", { name: "Aria", exact: true }).click();
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await expect(page.getByRole("heading", { name: "Aria", level: 1 })).toBeVisible();
});

test("a chat is started from the card's page and answered", async ({ page }) => {
  await page.goto("/");
  await page.locator("#rail").getByRole("link", { name: "Characters" }).click();
  await page.getByRole("link", { name: "Aria", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Aria", level: 1 })).toBeVisible();
  await button(page, "Start a chat with this message").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  const texts = page.locator(".message .text");
  await expect(texts).toHaveText([GREETING]);
  api.next([REPLY]);
  const composer = page.getByLabel("Message", { exact: true });
  await composer.fill("Where are the star charts?");
  await composer.press("Enter");
  await expect(texts).toHaveText([GREETING, "Where are the star charts?", REPLY]);
});
