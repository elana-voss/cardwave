import type { Locator, Page } from "@playwright/test";
import { cardFile } from "../card";
import { chooseView, expect, modelLine, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";

// Run-through "chats": a user's path through a chat's functions, by clicks and typing alone, each story going on
// from the one before (`serial`). The start, made through `request`: the stand-in `api` the chat model (tide-1, beside
// tide-2), the cards Mira and Halden imported, and Gwen, who has the modes Roleplay and Assistant. A chat with Mira
// started from her page and answered; her messages edited, written again and deleted from the message menu; the
// layouts Bubbles and Plain; Halden added to the chat (a group); the chat model changed in Settings and used by the
// next reply; Gwen's chat picking Assistant and set back by hand. Run with RUN_THROUGHS=1 only (playwright.config.ts).
// Details are their own specs' (03, 06, 24, 54, 68).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let gwen = 0;

const GREETING = "The lamp is lit.";
const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const messages = (page: Page) => page.locator("article.message");
const texts = (page: Page) => page.locator("article.message .text");

/** Opens the message menu of `message` and picks `line`. */
async function pick(message: Locator, line: string): Promise<void> {
  await message.hover();
  await message.getByRole("button", { name: "Message options" }).click();
  await message.page().getByRole("menuitem", { name: line, exact: true }).click();
}

/** Sends `text` and waits for the reply to end. */
async function say(page: Page, text: string): Promise<void> {
  const before = await messages(page).count();
  await composer(page).fill(text);
  await composer(page).press("Enter");
  await expect(messages(page)).toHaveCount(before + 2);
  await expect(button(page, "Write again")).toBeEnabled();
}

/** Opens Mira's chat, the newest one with her, from the rail's Chats. */
async function openMira(page: Page): Promise<void> {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("link", { name: "Chats", exact: true }).click();
  await page.locator("main").getByRole("link", { name: /Mira/ }).first().click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(texts(page).first()).toHaveText(GREETING);
}

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  api.models(["tide-1", "tide-2"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
  for (const card of [cardFile({ name: "Mira", description: "Mira keeps the lighthouse.", first_mes: GREETING }), cardFile({ name: "Halden", description: "Halden keeps the reef light.", first_mes: "Reef's quiet." })]) {
    const made = await request.post("/api/cards", { data: card });
    expect(made.status(), await made.text()).toBeLessThan(300);
  }
  const data = { title: "Gwen", tags: [], creator: "", name: "Gwen", greetings: ["Hello."], description: "Gwen helps.", personality: "Brisk.", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  gwen = (await made.json()).card_id;
  const edit = await (await request.get(`/api/cards/${gwen}/edit`)).json();
  expect((await request.put(`/api/cards/${gwen}/edit`, { data: { ...edit, modes: ["Roleplay", "Assistant"] } })).status()).toBe(200);
});
test.afterAll(() => api.close());

test("a chat with one character is started from her page and answered", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("link", { name: "Characters" }).click();
  await page.getByRole("link", { name: "Mira", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Mira", level: 1 })).toBeVisible();
  await button(page, "Start a chat with this message").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(texts(page)).toHaveText([GREETING]);
  api.next(["The tide turns at nine."]);
  await say(page, "When does the tide turn?");
  await expect(texts(page)).toHaveText([GREETING, "When does the tide turn?", "The tide turns at nine."]);
  expect(api.lastPrompt()).toContain("Mira keeps the lighthouse.");
});

test("the message menu edits a message, writes a reply again and deletes", async ({ page }) => {
  await openMira(page);
  const mine = messages(page).nth(1);
  await pick(mine, "Edit message");
  await page.getByLabel("Edit message").fill("When does the tide turn tonight?");
  await mine.getByRole("button", { name: "Save" }).click();
  await expect(mine.locator(".text")).toHaveText("When does the tide turn tonight?");

  api.next(["At ten tonight."]);
  await button(page, "Write again").click();
  await expect(texts(page)).toHaveText([GREETING, "When does the tide turn tonight?", "At ten tonight."]);
  await expect(messages(page).last().locator(".count")).toHaveText("2 / 2");
  expect(api.lastPrompt()).toContain("When does the tide turn tonight?");

  await pick(messages(page).nth(1), "Delete");
  await expect(texts(page)).toHaveText([GREETING]);
  await expect(page.locator("#toast span")).toHaveText("Deleted the message and the 1 after it.");
  await page.reload();
  await expect(texts(page)).toHaveText([GREETING]);
});

test("the chat is shown as Bubbles and as Plain, and keeps the choice", async ({ page }) => {
  await openMira(page);
  await expect(page.locator("html")).toHaveAttribute("data-chat", "bubbles");
  await chooseView(page, "Plain");
  await expect(page.locator("html")).toHaveAttribute("data-chat", "plain");
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-chat", "plain");
  await expect(texts(page)).toHaveText([GREETING]);
  await chooseView(page, "Bubbles");
  await expect(page.locator("html")).toHaveAttribute("data-chat", "bubbles");
});

test("Add a character makes the chat a group, and both answer", async ({ page }) => {
  await openMira(page);
  await button(page, "Attach, or let the AI write").click();
  await page.getByRole("menuitem", { name: "Add a character" }).click();
  const picker = page.getByRole("dialog", { name: "Add a character" });
  await picker.getByLabel("Search characters").fill("Halden");
  await expect(picker.locator(".pick-list .row")).toHaveCount(1);
  await picker.getByRole("button", { name: "Add Halden", exact: true }).click();
  await expect(page.locator("dialog")).toHaveCount(0);
  const panel = page.getByRole("complementary", { name: "Chat details" });
  const cast = panel.locator(".panel-part", { has: page.getByText("Characters", { exact: true }) }).locator(".item .item-text");
  await expect(cast).toContainText(["Mira", "Halden"]);

  api.next(["Reef's quiet tonight."]);
  await say(page, "Halden, how is the reef?");
  await expect(messages(page).last().locator(".speaker")).toHaveText("Halden");
  expect(api.lastPrompt()).toContain("Halden keeps the reef light.");
});

test("the chat model is changed in Settings and writes the next reply", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("link", { name: "Settings", exact: true }).click();
  await button(page, "Change the chat model").click();
  const picker = page.getByRole("dialog", { name: "Chat model" });
  await modelLine(picker, "tide-2").click();
  await picker.getByRole("button", { name: "Use this model", exact: true }).click();
  await expect(picker).toBeHidden();
  await openMira(page);
  await say(page, "Who writes now?");
  expect(api.asked.at(-1)!.body.model).toBe("tide-2");
});

test("the assistant: a chat picks Assistant, has the assistant's panel, and is set back by hand", async ({ page }) => {
  await page.goto(`/#/library/${gwen}`);
  await expect(page.getByRole("heading", { name: "Gwen", level: 1 })).toBeVisible();
  await button(page, "Start a chat with this message").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  const pill = page.locator(".mode-pill");
  await expect(pill).toHaveText("Roleplay · automatic");
  api.picks("Assistant");
  await composer(page).fill("Help me plan my week.");
  await composer(page).press("Enter");
  await expect(pill).toHaveText("Assistant · automatic");
  await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeVisible();
  await expect(page.getByText("Help me plan my week.").last()).toBeVisible();
  await pill.click();
  await page.getByRole("menuitemradio", { name: "Roleplay" }).click();
  await expect(pill).toHaveText("Roleplay");
  await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeHidden();
  api.picks("");
});
