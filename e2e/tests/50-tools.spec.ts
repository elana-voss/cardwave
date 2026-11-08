import { mkdtempSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Tools: the settings' group Tools, whose Files waits for a folder chosen in its dialog, and a file the character
// writes in a chat, which waits over the message field until the user allows it, as a card Cardwave's own
// tools make in a chat without a character does. The folder is one of the test's
// own in the system's temporary folder; the stand-in `api` is the model, which calls the tool (`calls`).

let api: FakeProvider;
let folder: string;

test.beforeAll(async () => {
  api = await startFakeProvider();
  folder = mkdtempSync(join(tmpdir(), "cardwave-tools-"));
});
test.afterAll(async () => {
  await api.close();
  rmSync(folder, { recursive: true, force: true });
});

const line = (page: Page, name: string) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });

/** A chat with Mira, and its number. */
async function chat(request: APIRequestContext): Promise<number> {
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.card.version_id, character: card.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

test("files are switched on once a folder is chosen, and then ask before writing", async ({ page, request }) => {
  await page.goto("/#/settings");
  await expect(line(page, "Files").locator(".meta")).toHaveText("Choose a folder first");
  await expect(line(page, "Files").getByRole("switch")).toBeDisabled();
  await line(page, "Web").getByRole("switch").check();
  await expect(line(page, "Web").getByRole("switch")).toBeEnabled();

  await page.getByRole("button", { name: "Change folder" }).click();
  await page.getByRole("dialog", { name: "Folder" }).getByLabel("Folder on this computer").fill(folder);
  await page.getByRole("dialog", { name: "Folder" }).getByRole("button", { name: "Save" }).click();
  await expect(line(page, "Folder").locator(".meta")).toHaveText(folder);
  await expect(line(page, "Files").locator(".meta")).toHaveText(`${folder} only`);
  await expect(line(page, "Ask before writing")).toHaveCount(0);
  await line(page, "Files").getByRole("switch").check();
  await expect(line(page, "Ask before writing").getByRole("switch")).toBeChecked();

  const { tools } = await (await request.get("/api/settings")).json();
  expect(tools).toMatchObject({ web: true, files: true, ask_writes: true, folder });
});

test("a file the character writes waits until the user allows it", async ({ page, request }) => {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const set = await request.patch("/api/settings", { data: { tools: { files: true, ask_writes: true, folder } } });
  expect(set.status(), await set.text()).toBe(200);
  await page.goto(`/#/chats/${await chat(request)}`);

  api.calls("write_file", { path: "plan.txt", content: "Sail at dawn." });
  api.next(["It is written."]);
  await page.getByLabel("Message", { exact: true }).fill("Write down the plan.");
  await page.getByRole("button", { name: "Send" }).click();
  const asking = page.locator(".tool-ask");
  await expect(asking.locator(":scope > span")).toHaveText("Mira wants to write “plan.txt” in your folder:");
  await expect(asking.locator("pre")).toHaveText("Sail at dawn.");
  expect(existsSync(join(folder, "plan.txt"))).toBe(false);

  await asking.getByRole("button", { name: "Allow" }).click();
  await expect(page.locator("article.message").last()).toContainText("It is written.");
  await expect(asking).toHaveCount(0);
  expect(readFileSync(join(folder, "plan.txt"), "utf8")).toBe("Sail at dawn.");
});

test("Cardwave's own tools make a card in a chat without a character once the user allows it", async ({ page, request }) => {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const set = await request.patch("/api/settings", { data: { tools: { app: true } } });
  expect(set.status(), await set.text()).toBe(200);
  const started = await request.post("/api/chats", { data: { characters: [] } });
  await page.goto(`/#/chats/${(await started.json()).chat.id}`);

  const body = { title: "Harbour Watch", tags: [], creator: "", name: "Ines", greetings: ["Ahoy."], description: "A harbour pilot.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  api.calls("cardwave", { tool: "post_cards_new", arguments: { body } });
  api.next(["Ines is in your library."]);
  await page.getByLabel("Message", { exact: true }).fill("Make me a harbour pilot.");
  await page.getByRole("button", { name: "Send" }).click();
  const asking = page.locator(".tool-ask");
  await expect(asking.locator(":scope > span")).toHaveText(/ wants to change Cardwave:$/);
  await expect(asking.locator("pre")).toContainText("POST /api/cards/new");
  await expect(asking.getByRole("switch")).toHaveCount(0);

  await asking.getByRole("button", { name: "Allow" }).click();
  await expect(page.locator("article.message").last()).toContainText("Ines is in your library.");
  const cards = await (await request.get("/api/cards")).json();
  expect(cards.map((card: { title: string }) => card.title)).toContain("Harbour Watch");
});
