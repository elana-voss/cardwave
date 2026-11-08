import type { Page } from "@playwright/test";
import { expect, linesOf, pickFrom, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Prompt presets: made and changed in their editor from the page "Advanced", put in use there with Undo,
// deleted after asking, and chosen for one chat in its side panel, where a reply's prompt then has the
// preset's system prompt and author's note.
//
// One database for the file, whose tests run one after the other: the first makes "Noir", which the others use.
// A card of one character, Moss, whose own system prompt is `CARD_PROMPT`; replies come from the fake provider.
test.describe.configure({ mode: "serial" });

const CARD_PROMPT = "Moss speaks in riddles.";

let provider: FakeProvider;
let version = 0;

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  const card = await request.post("/api/cards", { data: cardFile({ name: "Moss", first_mes: "Moss nods.", system_prompt: CARD_PROMPT }) });
  expect(card.status()).toBe(201);
  version = (await card.json()).version_id;
});
test.afterAll(() => provider.close());

const group = (page: Page) => page.locator(".prompt-presets");
const lines = (page: Page) => group(page).locator(".preset .item-label");
const line = (page: Page, name: string) => group(page).locator(".preset").filter({ has: page.locator(".item-label", { hasText: new RegExp(`^${name.replace(/[()]/g, "\\$&")}( · in use)?$`) }) });
const notice = (page: Page) => page.locator("#toast span");
const editor = (page: Page) => page.locator("form.editor");

async function advanced(page: Page): Promise<void> {
  await page.goto("/#/settings/advanced");
  await expect(lines(page).first()).toBeVisible();
}

test("a preset is made in its editor, put in use with Undo, changed and deleted", async ({ page }) => {
  await advanced(page);
  await expect(lines(page)).toHaveText(["Default · in use"]);

  await group(page).getByRole("button", { name: "New preset", exact: true }).click();
  await expect(page.locator(".crumbs b")).toHaveText("New prompt preset");
  await editor(page).getByLabel("Name").fill("Noir");
  await editor(page).getByLabel("System prompt").fill("Write as noir, {{char}}.");
  await editor(page).getByLabel("Note", { exact: true }).fill("[Rain on the glass.]");
  await editor(page).getByLabel("Messages back").fill("2");
  await editor(page).getByRole("button", { name: "Save", exact: true }).click();
  await expect(notice(page)).toHaveText("Preset “Noir” saved.");
  await expect(lines(page)).toHaveText(["Default · in use", "Noir"]);
  await expect(line(page, "Noir").locator(".item-text > .meta")).toHaveText("System prompt · note, 2 messages back");

  await line(page, "Noir").hover();
  await line(page, "Noir").getByRole("button", { name: "Use", exact: true }).click();
  await expect(lines(page)).toHaveText(["Default", "Noir · in use"]);
  await expect(notice(page)).toHaveText("Using “Noir”.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(lines(page)).toHaveText(["Default · in use", "Noir"]);
  await line(page, "Noir").hover();
  await line(page, "Noir").getByRole("button", { name: "Use", exact: true }).click();
  await expect(lines(page)).toHaveText(["Default", "Noir · in use"]);

  // A copy, changed in its editor, then deleted after asking.
  await line(page, "Noir").getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Duplicate" }).click();
  await expect(lines(page)).toHaveText(["Default", "Noir · in use", "Noir (copy)"]);
  await line(page, "Noir (copy)").getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Edit" }).click();
  await expect(editor(page).getByLabel("System prompt")).toHaveValue("Write as noir, {{char}}.");
  await editor(page).getByLabel("Note", { exact: true }).fill("");
  await editor(page).getByRole("button", { name: "Save", exact: true }).click();
  await expect(line(page, "Noir (copy)").locator(".item-text > .meta")).toHaveText("System prompt");
  await line(page, "Noir (copy)").getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Delete" }).click();
  await group(page).locator(".preset + .confirm").getByRole("button", { name: "Delete", exact: true }).click();
  await expect(lines(page)).toHaveText(["Default", "Noir · in use"]);

  // Default's copy, named by the server.
  await line(page, "Default").getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Duplicate" }).click();
  await expect(lines(page)).toHaveText(["Default", "Default (copy)", "Noir · in use"]);
  await line(page, "Default (copy)").getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Delete" }).click();
  await group(page).locator(".preset + .confirm").getByRole("button", { name: "Delete", exact: true }).click();
  await expect(lines(page)).toHaveText(["Default", "Noir · in use"]);
});

test("a chat goes by the preset in use, or by the one chosen in its side panel", async ({ page, request }) => {
  const made = await request.post("/api/chats", { data: { characters: [{ version_id: version, character: "moss" }] } });
  expect(made.status(), await made.text()).toBe(201);
  const chat = (await made.json()).chat.id;
  await page.goto(`/#/chats/${chat}`);
  const choice = page.getByRole("complementary", { name: "Chat details" }).getByLabel("Prompt preset", { exact: true });
  await expect(linesOf(choice)).toHaveText(["Noir (from Settings)", "Default (the character's own)", "Noir"]);
  await expect(choice).toHaveText("Noir (from Settings)");

  // The chat's own request: after the second exchange a title is asked for, too.
  const prompt = () =>
    provider.asked
      .map((asked) => asked.body.messages.map((message: { content: string }) => message.content).join("\n"))
      .filter((text) => !text.startsWith("You title a chat"))
      .at(-1)!;
  const say = async (text: string) => {
    const before = provider.asked.length;
    await page.getByLabel("Message", { exact: true }).fill(text);
    await page.getByLabel("Message", { exact: true }).press("Enter");
    await expect.poll(() => provider.asked.length).toBeGreaterThan(before);
    await expect(page.getByRole("button", { name: "Write again", exact: true })).toBeEnabled();
  };
  await say("Who are you?");
  expect(prompt()).toContain("Write as noir, Moss.");
  expect(prompt()).toContain("[Rain on the glass.]");
  expect(prompt()).not.toContain(CARD_PROMPT);

  await pickFrom(choice, "Default (the character's own)");
  await expect(choice).toHaveText("Default (the character's own)");
  await page.reload();
  await expect(choice).toHaveText("Default (the character's own)");
  await say("And now?");
  expect(prompt()).toContain(CARD_PROMPT);
  expect(prompt()).not.toContain("Rain on the glass");
});
