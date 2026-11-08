import type { Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// The chat, from a card imported by file: the provider set up on the page Providers, a reply streamed in,
// Regenerate's swipes, a message edited in place, a message deleted and put back, a reply continued, and the
// message written and bettered by the model (the menu of "+", `tools`).
//
// One server and one database for the file: the tests build on each other (no provider, then the provider,
// then chats that use it). `say` sends a message, and `pick` picks a line of a message's menu "…".
test.describe.configure({ mode: "serial" });

let provider: FakeProvider;
test.beforeAll(async () => {
  provider = await startFakeProvider();
});
test.afterAll(() => provider.close());

/** A key that begins as no provider's on the list does. */
const KEY = "key-chat-0123456789";

const MIRA = {
  name: "Mira",
  description: "Keeper of the lighthouse.",
  first_mes: "The lamp is lit.",
  alternate_greetings: ["Storm tonight."],
};

const messages = (page: Page) => page.locator(".message");
const texts = (page: Page) => page.locator(".message .text");
const newest = (page: Page) => messages(page).last();
const newestText = (page: Page) => newest(page).locator(".text");
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });

/** Picks a line of a message's menu, "…", which shows while the message is pointed at. */
async function pick(message: Locator, line: string): Promise<void> {
  await message.hover();
  await message.getByRole("button", { name: "Message options" }).click();
  await message.getByRole("menuitem", { name: line, exact: true }).click();
}

/** Starts a chat with Mira, from her page. */
async function newChat(page: Page): Promise<void> {
  await page.goto("/#/library");
  await page.locator("#view").getByRole("link", { name: "Mira", exact: true }).click();
  await button(page, "Start a chat with this message").click();
  await expect(texts(page)).toHaveText(["The lamp is lit."]);
}

/** Picks a line of the menu of the message field's "+". */
async function tools(page: Page, line: string): Promise<void> {
  await button(page, "Attach, or let the AI write").click();
  // A line's name begins with its label; a grey line under it may follow.
  await page.getByRole("menuitem", { name: new RegExp(`^${line}`) }).click();
}

async function say(page: Page, text: string): Promise<void> {
  await composer(page).fill(text);
  await composer(page).press("Enter");
}

test("a card is imported by file and a chat started with it", async ({ page }) => {
  // With nothing there yet, the list of chats is the fresh start: Create's lines, in New and Import.
  await page.goto("/#/chats");
  await expect(page.getByRole("group", { name: "New" }).getByRole("button")).toHaveText(["New chat", "Chat without a character", "New character", "New persona", "New lorebook"]);
  await expect(page.getByRole("group", { name: "Import" }).getByRole("button")).toHaveText(["Import card", "Import lorebook"]);
  // Nothing to sort or filter: no button for it.
  await expect(page.getByRole("button", { name: "Sort", exact: true })).toBeHidden();
  await expect(page.getByRole("link", { name: "Chats", exact: true })).toHaveAttribute("aria-current", "page");
  await page.locator("#rail").getByRole("link", { name: "Characters" }).click();
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Characters"]);
  await expect(page.getByRole("link", { name: "Chats", exact: true })).not.toHaveAttribute("aria-current");
  await expect(page.getByText("No characters yet.")).toBeVisible();

  // Two files at once: the card comes in, and the file that is none is refused with the reason, by its name.
  await page.setInputFiles("input[type=file]", [
    { name: "mira.png", mimeType: "image/png", buffer: cardFile(MIRA) },
    { name: "notes.png", mimeType: "image/png", buffer: Buffer.from("not a card") },
  ]);
  const lines = page.getByRole("status", { name: "Import" }).locator(".import-line");
  await expect(lines.filter({ hasText: "Mira" })).toContainText("Imported");
  await expect(lines.filter({ hasText: "notes.png" })).toContainText("Not a PNG file");
  await expect(page.locator(".card-row")).toHaveCount(1);

  // With a card and no chat, the list of chats says so, without a button of its own: Create has "New chat".
  await page.locator("#rail").getByRole("link", { name: "Chats", exact: true }).click();
  await expect(page.getByText("No chats yet.")).toBeVisible();
  await expect(page.getByRole("group", { name: "New" })).toHaveCount(0);
  await expect(button(page, "New chat")).toHaveCount(0);
  await page.locator("#rail").getByRole("link", { name: "Characters" }).click();

  await button(page, "Chat").click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(page.getByRole("heading", { name: "Mira" })).toBeVisible();
  await expect(newest(page).locator(".speaker")).toHaveText("Mira");
  await expect(texts(page)).toHaveText(["The lamp is lit."]);

  // The card's other greeting is a swipe of the first message.
  await expect(newest(page).locator(".count")).toHaveText("1 / 2");
  await button(page, "Next version").click();
  await expect(texts(page)).toHaveText(["Storm tonight."]);

  // The chat is in the list of chats and opens from there.
  const chat = page.url();
  await page.getByRole("link", { name: "Chats" }).click();
  await page.locator(".row").getByRole("link", { name: "Mira" }).click();
  await expect(page).toHaveURL(chat);
  await expect(texts(page)).toHaveText(["Storm tonight."]);
});

test("the provider is added on the page Providers, its model made the chat model under Settings and the sampling kept on “Advanced”", async ({ page }) => {
  provider.models(["test-model"]);
  // A key that begins as no provider's on the list does, so the address is entered.
  await page.goto("/#/settings/providers");
  await button(page, "Add provider").click();
  const adding = page.getByRole("dialog", { name: "Add provider" });
  await adding.getByLabel("API key", { exact: true }).fill(KEY);
  if (!(await adding.getByLabel("Address").isVisible())) await adding.getByRole("button", { name: "Enter address", exact: true }).click();
  await adding.getByLabel("Address").fill(provider.url);
  await adding.getByRole("button", { name: "Continue", exact: true }).click();
  await expect(adding).toBeHidden();
  const box = page.locator(".group.provider");
  await expect(box.locator(".item").nth(1)).toContainText("Not used for anything yet1 model");
  // Its model is made the chat model under Settings › Models.
  await page.goto("/#/settings");
  await button(page, "Change the chat model").click();
  const picker = page.getByRole("dialog", { name: "Chat model" });
  await picker.getByRole("option", { name: "test-model" }).click();
  await picker.getByRole("button", { name: "Use this model", exact: true }).click();
  await expect(picker).toBeHidden();
  await page.goto("/#/settings/providers");
  await expect(box.locator(".item").nth(1)).toContainText("Chattest-model");

  // The sampling is kept as typed; a value out of its range is red, with its range, and is not kept.
  await page.goto("/#/settings/advanced");
  await page.getByLabel("Temperature").fill("0.7");
  await expect.poll(async () => (await page.request.get("/api/sampling")).json()).toMatchObject({ temperature: 0.7, top_p: null });
  await page.getByLabel("Temperature").fill("5");
  await expect(page.getByText("From 0 to 2")).toBeVisible();
  await page.reload();
  await expect(page.getByLabel("Temperature")).toHaveValue("0.7");
  await expect(page.getByLabel("Top P")).toHaveValue("");
});

test("a reply streams in piece by piece", async ({ page }) => {
  await newChat(page);
  // A message of nothing but blanks is not sent.
  await say(page, "  ");
  const reply = provider.hold(["The tide", " is out."]);
  await say(page, "How is the sea?");

  // In the middle of the reply: its first piece is shown and it can be stopped.
  await expect(texts(page)).toHaveText(["The lamp is lit.", "How is the sea?", "The tide"]);
  await expect(button(page, "Stop")).toBeVisible();
  await expect(button(page, "Write again")).toHaveCount(0);
  // Nothing else is sent meanwhile; what was typed waits.
  await say(page, "Wait");

  reply.release();
  await expect(newestText(page)).toHaveText("The tide is out.");
  await expect(button(page, "Send")).toBeVisible();
  await expect(button(page, "Write again")).toBeEnabled();
  await expect(composer(page)).toHaveValue("Wait");
  await expect(page.getByRole("alert")).toBeHidden();
  // Send's tooltip says how much of the context the reply's prompt took.
  await expect(button(page, "Send")).toHaveAttribute("title", /^[\d,]+ of [\d,]+ tokens$/);

  // The provider was asked with what the settings hold.
  const asked = provider.asked.at(-1)!;
  expect(asked.key).toBe(`Bearer ${KEY}`);
  expect(asked.body).toMatchObject({ model: "test-model", temperature: 0.7, stream: true });
  expect(asked.body).not.toHaveProperty("top_p");
  expect(asked.body.messages.at(-1)).toMatchObject({ role: "user", content: "How is the sea?" });

  await page.reload();
  await expect(texts(page)).toHaveText(["The lamp is lit.", "How is the sea?", "The tide is out."]);
});

test("Write again writes another swipe and the arrows switch between them", async ({ page }) => {
  await newChat(page);
  provider.next(["First."]);
  await say(page, "Hi");
  await expect(newestText(page)).toHaveText("First.");
  await expect(newest(page).locator(".count")).toHaveCount(0);

  provider.next(["Second."]);
  await button(page, "Write again").click();
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Hi", "Second."]);
  await expect(newest(page).locator(".count")).toHaveText("2 / 2");
  await expect(newest(page).getByRole("button", { name: "Next version" })).toBeDisabled();

  await newest(page).getByRole("button", { name: "Previous version" }).click();
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Hi", "First."]);
  await expect(newest(page).locator(".count")).toHaveText("1 / 2");
  await newest(page).getByRole("button", { name: "Next version" }).click();
  await expect(newestText(page)).toHaveText("Second.");
});

test("a message is edited in place", async ({ page }) => {
  await newChat(page);
  await say(page, "Helo");
  await expect(newestText(page)).toHaveText("Echo: Helo");
  const mine = messages(page).nth(1);

  // Cancel leaves the message as it was.
  await mine.hover();
  await pick(mine, "Edit message");
  await mine.getByLabel("Edit message").fill("Something else");
  await mine.getByRole("button", { name: "Cancel" }).click();
  await expect(mine.locator(".text")).toHaveText("Helo");

  await mine.hover();
  await pick(mine, "Edit message");
  await expect(mine.getByLabel("Edit message")).toHaveValue("Helo");
  await mine.getByLabel("Edit message").fill("Hello");
  await mine.getByRole("button", { name: "Save" }).click();
  await expect(mine.locator(".text")).toHaveText("Hello");

  await page.reload();
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Hello", "Echo: Helo"]);
});

test("a message is deleted with what follows it and put back, and a reply is continued in its own message", async ({ page }) => {
  await newChat(page);
  // Mira's card has no art: her rounds are grey, with no picture in them that could show as broken.
  await expect(page.locator(".chat-link span.avatar")).toBeVisible();
  await expect(page.locator(".chat-link img.avatar, .msg-head img.avatar")).toHaveCount(0);
  provider.next(["The tide."]);
  await say(page, "Why tonight?");
  await expect(newestText(page)).toHaveText("The tide.");

  // The model goes on from the reply's end, steered by the field's words, and its words stream into the same reply.
  await expect(button(page, "Continue this reply")).toHaveAttribute("title", "Continue this reply · the words in the field steer it");
  await composer(page).fill("she speaks of midnight");
  const held = provider.hold([" It turns", " at midnight."]);
  await button(page, "Continue this reply").click();
  await expect(newestText(page)).toHaveText(/^The tide\.\s*It turns$/);
  await expect(button(page, "Stop")).toBeVisible();
  held.release();
  await expect(newestText(page)).toHaveText(/^The tide\.\s*It turns at midnight\.$/);
  await expect(newest(page).locator(".count")).toHaveCount(0);
  expect(provider.asked.at(-1)!.body.messages.at(-1).content).toContain("Continue your last message without repeating its original content. Follow this direction from Guest: she speaks of midnight]");
  // The words were no message: they leave the field, and no message of them is in the chat.
  await expect(composer(page)).toHaveValue("");

  // The user's message goes with the reply after it, and the notice's Undo brings both back.
  await pick(messages(page).nth(1), "Delete");
  await expect(texts(page)).toHaveText(["The lamp is lit."]);
  await expect(page.locator("#toast span")).toHaveText("Deleted the message and the 1 after it.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(texts(page)).toHaveCount(3);
  await page.reload();
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Why tonight?", /^The tide\.\s*It turns at midnight\.$/]);
});

test("the model writes the user's message or betters it, into the field, and is stopped", async ({ page }) => {
  await newChat(page);
  // Without words there is nothing to send, and nothing to better.
  await expect(button(page, "Send")).toBeDisabled();
  await button(page, "Attach, or let the AI write").click();
  await expect(page.getByRole("menuitem", { name: "Improve my message" })).toBeDisabled();
  await expect(page.getByRole("menuitem", { name: /^Write for me/ })).toContainText("The AI writes your message; what you typed guides it and is not sent.");
  await page.keyboard.press("Escape");

  provider.next(["I came for the lamp."]);
  await tools(page, "Write for me");
  await expect(composer(page)).toHaveValue("I came for the lamp.");
  await expect(button(page, "Send")).toBeEnabled();
  expect(JSON.stringify(provider.asked.at(-1)!.body.messages)).toContain("from the point of view of");

  provider.next(["I came to see the lamp."]);
  await tools(page, "Improve my message");
  await expect(composer(page)).toHaveValue("I came to see the lamp.");
  expect(provider.asked.at(-1)!.body.messages.at(-1).content).toContain("I came for the lamp.");
  await expect(page.locator("#toast span")).toHaveText("Message improved.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(composer(page)).toHaveValue("I came for the lamp.");

  // Stopped, the model is hung up on, and the field keeps its words; nothing was sent.
  const held = provider.hold(["Never", " mind."]);
  await tools(page, "Write for me");
  await expect(button(page, "Stop")).toBeVisible();
  await button(page, "Stop").click();
  await expect(button(page, "Send")).toBeVisible();
  await expect(composer(page)).toHaveValue("I came for the lamp.");
  await expect.poll(() => held.hungUp()).toBe(true);
  await expect(texts(page)).toHaveText(["The lamp is lit."]);
});
