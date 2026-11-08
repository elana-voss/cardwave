import type { APIRequestContext } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { NOW, picture, stopClock } from "../pictures";

// Code mode: the model writes a tool in a chat, which waits over the message field with its code until the user
// allows it, and calls it; Settings › Tools › "Tools the AI wrote" lists it, its panel shows its code and how
// often it ran, and it is switched off and deleted there, with Undo. The stand-in `api` is the model (`calls`).
// The picture of the page (`written-tools`, 1440 px, light) is of three tools the page is answered with by
// `page.route`, as a tool's day is the server's and would change the picture from day to day; the panel is open.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** A chat with Mira, with the web on and the chat's Code mode, and its number. */
async function chat(request: APIRequestContext): Promise<number> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  expect((await request.patch("/api/settings", { data: { tools: { web: true } } })).status()).toBe(200);
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.card.version_id, character: card.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  const id = (await started.json()).chat.id;
  expect((await request.put(`/api/chats/${id}/reply`, { data: { reply_length: 350, code_mode: true } })).status()).toBe(200);
  return id;
}

const CODE = "export default function word_count({ text }) {\n  return text.trim().split(/\\s+/).filter(Boolean).length;\n}";
const TOOL = { name: "word_count", description: "Counts the words of a text.", parameters: { type: "object", properties: { text: { type: "string" } } }, code: CODE };

test("a tool the model writes is allowed in the chat, called, and listed under Settings › Tools", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  api.calls("make_tool", TOOL);
  api.calls("word_count", { text: "the lamp is lit" });
  api.next(["It has four words."]);
  await page.getByLabel("Message", { exact: true }).fill("How many words are in “the lamp is lit”?");
  await page.getByRole("button", { name: "Send" }).click();
  const asking = page.locator(".tool-ask");
  await expect(asking.locator(":scope > span")).toHaveText("Mira wants to use a new tool: Word count");
  await expect(asking.locator("pre")).toHaveText(`// Counts the words of a text.\n${CODE}`);
  await expect(asking.getByRole("switch")).toHaveCount(0);
  await asking.getByRole("button", { name: "Allow" }).click();
  await expect(page.locator("article.message").last()).toContainText("It has four words.");
  expect(api.asked.at(-1)!.body.messages.at(-1).content).toBe("4");

  await page.goto("/#/settings");
  const link = page.getByRole("link", { name: /Tools the AI wrote/ });
  await expect(link).toContainText("1 tool · ask before a new one runs");
  await link.click();
  const row = page.locator(".written-row");
  await expect(row).toHaveCount(1);
  const { title } = (await (await request.get(`/api/chats/${id}`)).json()).chat;
  await expect(row.locator(".meta")).toHaveText(new RegExp(`^Counts the words of a text · made .+ in ${title}$`));

  await row.getByRole("button", { name: "Word count" }).click();
  const panel = page.getByRole("dialog", { name: "Word count" });
  await expect(panel.locator("pre")).toHaveText(CODE);
  await expect(panel).toContainText("used once");
  await panel.getByRole("button", { name: "Switch off" }).click();
  await expect(panel).toHaveCount(0);
  await expect(row.getByRole("switch")).not.toBeChecked();

  await row.hover();
  await row.getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Delete" }).click();
  await expect(row).toHaveCount(0);
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(row).toHaveCount(1);

  // Switched on and deleted in another window.
  const tool = (await (await request.get("/api/tools/written")).json())[0].id;
  expect((await request.patch(`/api/tools/written/${tool}`, { data: { on: true } })).status()).toBe(200);
  await expect(row.getByRole("switch")).toBeChecked();
  expect((await request.delete(`/api/tools/written/${tool}`)).status()).toBe(204);
  await expect(row).toHaveCount(0);
});

test.describe("at 1440 px, light", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
  test.beforeEach(({ page }) => stopClock(page));

  test("Tools the AI wrote: three tools, one open in the panel", async ({ page }) => {
    const at = NOW.getTime();
    const tools = [
      { id: 3, name: "word_count", description: "Counts the words of a text.", code: CODE, on: true, created_at: at, chat_id: 1, chat_title: "North Light", uses: 3 },
      { id: 2, name: "dice_roll", description: "Rolls dice written as 2d6+1.", code: "export default () => 1;", on: true, created_at: at, chat_id: 1, chat_title: "North Light", uses: 0 },
      { id: 1, name: "days_between", description: "Counts the days between two dates.", code: "export default () => 1;", on: false, created_at: at, chat_id: null, chat_title: null, uses: 1 },
    ];
    await page.route("**/api/tools/written", (route) => route.fulfill({ json: tools }));
    await page.goto("/#/settings/tools/written");
    await page.locator(".written-row").first().getByRole("button", { name: "Word count" }).click();
    await expect(page.getByRole("dialog", { name: "Word count" })).toContainText("used 3 times");
    await picture(page, "written-tools-1440-light");
  });
});
