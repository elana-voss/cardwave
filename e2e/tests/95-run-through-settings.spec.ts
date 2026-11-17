import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { startFakeSearch, type FakeSearch } from "../fake-search";
import { setProvider } from "../stored";
import { button, expect, test } from "../test";

// Run-through "settings and account": a user's path through them by clicks and typing alone, each story going on
// from the one before (`serial`). The start, made through `request`: the stand-in `api` the chat model, the cards
// Moss and Fern. Settings › Advanced: a prompt preset made in its editor and put in use, which the next reply's
// prompt follows; Voices: the voice downloaded (fake-search.ts's file) and one chosen, shown in Settings; Trash: two
// cards moved there from the library, one restored, the other deleted forever; Account › Server: an account added
// and switched to from the rail, and back; Profile: the password switched on, asked at the next start, and off.
// Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (05, 45, 46, 47, 48).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let search: FakeSearch;
let moss = 0;

const notice = (page: Page) => page.locator("#toast span");
const dialog = (page: Page) => page.getByRole("dialog");
const item = (page: Page, name: string) => page.locator(".item", { has: page.getByText(name, { exact: true }) });
const account = (page: Page) => page.locator("#rail").getByRole("button", { name: /^Account/ });
const presets = (page: Page) => page.locator(".prompt-presets .preset .item-label");
const trashRows = (page: Page) => page.locator(".trash .row .ttl");

/** Moves the library's card `name` to the Trash from its row's menu. */
async function toTrash(page: Page, name: string): Promise<void> {
  const row = page.locator(".card-row", { hasText: name });
  await row.getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Move to Trash", exact: true }).click();
  await expect(notice(page)).toContainText(`“${name}” moved to Trash.`);
  await expect(row).toHaveCount(0);
}

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  search = await startFakeSearch();
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
  for (const name of ["Moss", "Fern"]) {
    const made = await request.post("/api/cards", { data: cardFile({ name, first_mes: `${name} nods.` }) });
    expect(made.status(), await made.text()).toBeLessThan(300);
    if (name === "Moss") moss = (await made.json()).card_id;
  }
});
test.afterAll(() => Promise.all([api.close(), search.close()]));

test("a prompt preset made in Advanced and put in use is what the next reply's prompt follows", async ({ page }) => {
  await page.goto("/#/settings");
  await page.getByRole("link", { name: /^Advanced/ }).click();
  await expect(page).toHaveURL(/#\/settings\/advanced$/);
  await expect(presets(page)).toHaveText(["Default · in use"]);
  await page.locator(".prompt-presets").getByRole("button", { name: "New preset", exact: true }).click();
  const editor = page.locator("form.editor");
  await editor.getByLabel("Name").fill("Noir");
  await editor.getByLabel("System prompt").fill("Write as noir, {{char}}.");
  await editor.getByRole("button", { name: "Save", exact: true }).click();
  await expect(notice(page)).toHaveText("Preset “Noir” saved.");
  const noir = page.locator(".prompt-presets .preset", { hasText: "Noir" });
  await noir.hover();
  await noir.getByRole("button", { name: "Use", exact: true }).click();
  await expect(presets(page)).toHaveText(["Default", "Noir · in use"]);

  await page.goto(`/#/library/${moss}`);
  await button(page, "Start a chat with this message").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await page.getByLabel("Message", { exact: true }).fill("Is it raining?");
  await page.getByLabel("Message", { exact: true }).press("Enter");
  await expect(page.locator("article.message")).toHaveCount(3);
  await expect(button(page, "Write again")).toBeEnabled();
  expect(api.lastPrompt()).toContain("Write as noir, Moss.");
});

test("the voice is downloaded on Voices and the one chosen shows in Settings", async ({ page, request }) => {
  await page.goto("/#/settings");
  await page.getByRole("button", { name: "Set up voice" }).click();
  // With a provider whose models might read aloud, the model is picked first; this computer's is.
  const picker = page.getByRole("dialog", { name: "Voice model" });
  await expect(picker.getByRole("option", { name: "Pocket TTS · on this computer" })).toHaveAttribute("aria-selected", "true");
  await picker.getByRole("button", { name: "Use this model" }).click();
  await expect(page).toHaveURL(/#\/settings\/voices$/);
  await page.getByRole("button", { name: "Download", exact: true }).click();
  await expect(page.getByRole("button", { name: "Try Marius" })).toBeEnabled();
  await page.getByRole("radio", { name: "Default voice: Marius" }).check();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).voice).toBe("marius");
  await page.getByRole("navigation", { name: "Where you are" }).getByRole("link", { name: "Settings" }).click();
  await expect(item(page, "Voice").locator(".meta")).toHaveText("Marius · English");
});

test("cards moved to the Trash are one restored and one deleted forever", async ({ page }) => {
  await page.goto("/#/library");
  await toTrash(page, "Moss");
  await toTrash(page, "Fern");
  await page.locator("#rail").getByRole("link", { name: "Trash" }).click();
  await expect(page).toHaveURL(/#\/settings\/trash$/);
  await expect(trashRows(page)).toHaveCount(2);
  await page.locator(".trash .row", { hasText: "Moss" }).getByRole("button", { name: "Restore" }).click();
  await expect(notice(page)).toHaveText("“Moss” restored.");
  const fern = page.locator(".trash .row", { hasText: "Fern" });
  await fern.getByRole("button", { name: "Delete forever" }).click();
  await fern.getByRole("button", { name: "Delete forever" }).click();
  await expect(page.getByText("The Trash is empty.")).toBeVisible();
  await page.goto("/#/library");
  await expect(page.locator(".card-row")).toHaveText([/Moss/]);
});

test("an account added in Server is switched to from Switch account, and back from the rail", async ({ page }) => {
  await page.goto("/#/account/server");
  await page.getByRole("switch", { name: "Reachable in the home network" }).click();
  await button(page, "Switch on").click();
  await expect(page.getByRole("switch", { name: "Reachable in the home network" })).toBeChecked();
  await button(page, "Add account").click();
  await dialog(page).getByLabel("Name").fill("Ada");
  await dialog(page).getByLabel("Password").fill("tide pool");
  await button(page, "Add").click();
  await expect(item(page, "Ada")).toBeVisible();

  await page.goto("/#/settings");
  await button(page, "Switch account").click();
  await page.getByRole("menuitemradio", { name: "Ada" }).click();
  await dialog(page).getByLabel("Password").fill("tide pool");
  await button(page, "Switch").click();
  // Ada's own data: no model yet, so first run.
  await expect(page.getByRole("heading", { name: "Provider" })).toBeVisible();
  await page.goto("/#/settings");
  await expect(account(page)).toHaveAccessibleName("Account: Ada");
  await account(page).click();
  await page.getByRole("menuitemradio", { name: "local" }).click();
  // The page starts anew at the app's address, without a screen named.
  await expect(page).toHaveURL(/:\d+\/$/);
  await page.goto("/#/library");
  await expect(account(page)).toHaveAccessibleName("Account: local");
  await expect(page.locator(".card-row")).toHaveText([/Moss/]);
});

test("the password switched on in Profile is asked at the next start, and switched off", async ({ page, restartServer }) => {
  await page.goto("/#/account/profile");
  await expect(item(page, "Password")).toContainText("Off · anyone at this computer can open Cardwave");
  await button(page, "Set password").click();
  await page.getByLabel("Password", { exact: true }).fill("harbour lights");
  await page.getByLabel("Repeat password").fill("harbour lights");
  await dialog(page).getByRole("button", { name: "Set password" }).click();
  await expect(notice(page)).toHaveText("Password set.");

  await restartServer();
  await page.goto("about:blank");
  await page.goto("/#/library");
  await expect(page.getByRole("heading", { name: "local" })).toBeVisible();
  await page.getByLabel("Password").fill("harbour lights");
  await button(page, "Open").click();
  await expect(page.locator(".card-row")).toHaveText([/Moss/]);

  await page.goto("/#/account/profile");
  await button(page, "Switch off the password").click();
  await page.getByLabel("Current password").fill("harbour lights");
  await button(page, "Switch off").click();
  await expect(notice(page)).toHaveText("Password switched off.");
});
