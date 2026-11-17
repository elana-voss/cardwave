import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { button, expect, say, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";

// Run-through "lorebooks and personas": a user's path through them, by clicks and typing alone, each story going on
// from the one before (`serial`). The start, made through `request`: the stand-in `api` the chat model and the card
// Mira imported with her own lorebook (one entry, "lamp"). A lorebook made in the library with an entry, whose words
// are then changed; an entry added to Mira's own lorebook; a chat with Mira given the library's lorebook, whose reply's
// prompt has all three entries' words; a persona made under Create and chosen in the chat, its description in the
// next prompt. Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (07, 08, 35).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let mira = 0;

const panel = (page: Page) => page.getByRole("complementary", { name: "Chat details" });
const entryField = (page: Page, name: string) => page.locator(".entry-form").getByLabel(name, { exact: true });
const content = (page: Page) => page.getByRole("region", { name: "Content" }).locator(".tb-body");

/** Names the new entry open in the editor, gives it one keyword and its words. */
async function writeEntry(page: Page, name: string, keyword: string, words: string): Promise<void> {
  const named = page.locator(".entry-form .edit-head h2").getByRole("textbox", { name: "Entry name" });
  await named.fill(name);
  await named.press("Enter");
  await expect(page.locator("#toast span")).toHaveText("Entry added.");
  await entryField(page, "Keywords").fill(keyword);
  await entryField(page, "Keywords").press("Enter");
  await setContent(page, words);
}

/** Writes the open entry's Content where it stands. */
async function setContent(page: Page, words: string): Promise<void> {
  await content(page).click();
  await page.getByRole("textbox", { name: "Content" }).fill(words);
  await page.getByRole("textbox", { name: "Content" }).press("Escape");
  await expect(content(page)).toHaveText(words);
}

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
  const book = { name: "Lighthouse", entries: [{ keys: ["lamp"], content: "The lamp burns oil.", enabled: true, insertion_order: 0, id: 0 }] };
  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", description: "Mira keeps the lighthouse.", first_mes: "Welcome.", character_book: book }) });
  expect(made.status(), await made.text()).toBeLessThan(300);
  mira = (await made.json()).card_id;
});
test.afterAll(() => api.close());

test("a lorebook is made in the library, an entry written and its words changed", async ({ page }) => {
  await page.goto("/#/library/lorebooks");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New lorebook" }).click();
  const dialog = page.getByRole("dialog", { name: "New lorebook" });
  await dialog.getByLabel("Name").fill("Harbour Lore");
  await dialog.getByLabel("Description").fill("The harbour's ways.");
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(page).toHaveURL(/#\/library\/lorebooks\/\d+\/new$/);
  await writeEntry(page, "Gulls", "gulls", "Gulls steal chips.");
  // Changed: a new version of its words.
  await setContent(page, "Gulls steal chips at high tide.");
  await page.locator(".crumbs").getByRole("link", { name: "Lorebooks" }).click();
  await expect(page.locator(".card-row", { hasText: "Harbour Lore" })).toContainText("1 entry");
  // The changed words are what a reply finds (the chat's story below).
});

test("an entry is added to the card's own lorebook", async ({ page }) => {
  await page.goto(`/#/library/${mira}/lorebook`);
  const entries = page.getByRole("complementary", { name: "Entries" });
  await expect(entries).toContainText("lamp");
  await entries.getByRole("button", { name: "New entry" }).click();
  await writeEntry(page, "Tide", "tide", "The tide turns at nine.");
  await expect(page.locator(".entry-line")).toHaveCount(2);
});

test("a chat given the library's lorebook finds every entry's words in its reply's prompt", async ({ page }) => {
  await page.goto(`/#/library/${mira}`);
  await button(page, "Start a chat with this message").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  const part = panel(page).locator(".panel-part", { has: page.getByText("Lorebooks", { exact: true }) });
  await part.getByRole("button", { name: "Add a lorebook to this chat" }).click();
  await page.getByRole("menuitem", { name: "Harbour Lore", exact: true }).click();
  await expect(panel(page).getByRole("switch", { name: "Harbour Lore", exact: true })).toBeChecked();
  await say(page, "Do the gulls come when the tide is high and the lamp is lit?");
  expect(api.lastPrompt()).toContain("Gulls steal chips at high tide.");
  expect(api.lastPrompt()).toContain("The tide turns at nine.");
  expect(api.lastPrompt()).toContain("The lamp burns oil.");
});

test("a persona is made under Create and used in the chat", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New persona" }).click();
  const form = page.locator(".rows-plain .persona-form");
  await form.getByLabel("Name").fill("Ada Quill");
  await form.getByLabel("Description").fill("Ada is a cartographer of the coast.");
  await form.getByRole("button", { name: "Save" }).click();
  await expect(page.locator(".card-row", { hasText: "Ada Quill" })).toBeVisible();

  await page.locator("#rail").getByRole("link", { name: "Chats", exact: true }).click();
  await page.locator("main").getByRole("link", { name: /Mira/ }).first().click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  const persona = panel(page).getByLabel("Persona", { exact: true });
  await persona.click();
  await page.getByRole("menuitemradio", { name: /^Ada Quill/ }).click();
  await expect(persona).toHaveText("Ada Quill");
  await say(page, "Who am I?");
  expect(api.lastPrompt()).toContain("Ada is a cartographer of the coast.");
  await expect(page.locator(".message.user .avatar.own").last()).toHaveText("A");
});
