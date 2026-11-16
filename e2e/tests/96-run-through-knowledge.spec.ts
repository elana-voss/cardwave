import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { NOTHING, startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";
import { expect, test } from "../test";

// Run-through "knowledge": a user's path through it by clicks and typing alone, each story going on from the one
// before (`serial`). The start, made through `request`: the stand-in `api` the chat model, the card Mira, a chat
// with her of 18 messages. The next reply completes the block of 20 the memory read takes, whose memory (`remembers`
// of ../fake-provider.ts) shows in the side panel and in Knowledge › Memories, where its text is changed; a document
// attached to a message is in that reply's prompt and listed in Knowledge › Documents.
// Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (41, 43).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let chat = 0;

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const memory = (page: Page) => page.locator(".memory-row");

/** Sends `text` and waits for the reply to it. */
async function say(page: Page, text: string): Promise<void> {
  const before = await page.locator("article.message").count();
  await composer(page).fill(text);
  await composer(page).press("Enter");
  await expect(page.locator("article.message")).toHaveCount(before + 2);
  await expect(button(page, "Write again")).toBeEnabled();
}

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
  const mira = await request.post("/api/cards", { data: cardFile({ name: "Mira", first_mes: "The lamp is lit." }) });
  expect(mira.status(), await mira.text()).toBeLessThan(300);
  const { version_id } = await mira.json();
  chat = (await (await request.post("/api/chats", { data: { characters: [{ version_id, character: "mira" }] } })).json()).chat.id;
  for (let n = 2; n <= 18; n++) expect((await request.post(`/api/chats/${chat}/messages`, { data: { content: `Message ${n}.` } })).status()).toBeLessThan(300);
});
test.afterAll(() => api.close());

test("a memory the chat made shows in its panel and is changed in Knowledge › Memories", async ({ page }) => {
  await page.goto(`/#/chats/${chat}`);
  await expect(page.locator("article.message")).toHaveCount(18);
  api.remembers("PRESENT: Mira, User\nFACTS:\nuser | sister | The user's sister is called Ana. | personal | Mira | current\nEVENTS:");
  await say(page, "My sister Ana comes tonight.");
  const used = page.locator(".chat-panel .panel-part", { has: page.getByText("Used in last reply", { exact: true }) });
  await expect(used.locator(".item", { hasText: "Saved to memory" })).toContainText("The user's sister is called Ana.");
  api.remembers(NOTHING);

  await page.locator("#rail").getByRole("link", { name: "Memories" }).click();
  await expect(memory(page).locator(".medium")).toHaveText("The user's sister is called Ana.");
  await memory(page).getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Edit", exact: true }).click();
  const dialog = page.getByRole("dialog", { name: "Edit memory" });
  await dialog.getByLabel("Text").fill("Ana, the user's sister, arrives tonight.");
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(memory(page).locator(".medium")).toHaveText("Ana, the user's sister, arrives tonight.");
});

test("a document attached to a message is in that reply's prompt and listed in Knowledge › Documents", async ({ page }) => {
  await page.goto(`/#/chats/${chat}`);
  const chooser = page.waitForEvent("filechooser");
  await button(page, "Attach, or let the AI write").click();
  await page.getByRole("menuitem", { name: "Attach picture or document", exact: true }).click();
  await (await chooser).setFiles({ name: "Coast notes.txt", mimeType: "text/plain", buffer: Buffer.from("The tide turns at nine.") });
  await expect(page.locator(".waiting-attachments .attached-file")).toContainText("Coast notes.txt");
  await say(page, "When does the tide turn?");
  expect(api.lastPrompt()).toContain("The tide turns at nine.");

  await page.locator("#rail").getByRole("link", { name: "Documents" }).click();
  await expect(page.locator(".document-row .medium")).toHaveText(["Coast notes"]);
});
