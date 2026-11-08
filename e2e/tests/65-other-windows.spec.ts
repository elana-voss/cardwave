import type { APIRequestContext } from "@playwright/test";
import { deafen, expect, test } from "../test";
import { startFakeProvider } from "../fake-provider";

// What another window changes shows at once: a change made by `request` is told to the page as one made in
// another window of the app is (test.ts), and the screen in view reads it anew. The stand-in model of the chat's
// test is started by it and closed at its end.

/** Makes a card from scratch, and answers its number and its version's. */
async function card(request: APIRequestContext, title: string): Promise<{ id: number; version: number }> {
  const data = { title, tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const { card_id, version_id } = await made.json();
  return { id: card_id, version: version_id };
}

test("the library, a card's page and the Trash show what another window changed", async ({ page, request }) => {
  await card(request, "North Light");
  await page.goto("/#/library");
  await expect(page.getByText("North Light", { exact: true }).first()).toBeVisible();
  const { id } = await card(request, "South Reef");
  await expect(page.getByText("South Reef", { exact: true }).first()).toBeVisible();

  // The card's page shows its star given elsewhere.
  await page.goto(`/#/library/${id}`);
  const star = page.locator(".main-card").getByRole("button", { name: "Favourite" }).first();
  await expect(star).toHaveAttribute("aria-pressed", "false");
  expect((await request.patch(`/api/cards/${id}`, { data: { favorite: true } })).status()).toBe(200);
  await expect(star).toHaveAttribute("aria-pressed", "true");

  // The Trash shows the card put there, and empty once it is restored.
  await page.goto("/#/settings/trash");
  await expect(page.getByText("The Trash is empty.")).toBeVisible();
  expect((await request.patch(`/api/cards/${id}`, { data: { trashed: true } })).status()).toBe(200);
  await expect(page.locator(".trash .row").getByText("South Reef")).toBeVisible();
  expect((await request.patch(`/api/cards/${id}`, { data: { trashed: false } })).status()).toBe(200);
  await expect(page.getByText("The Trash is empty.")).toBeVisible();
});

test("the personas and the settings show what another window changed", async ({ page, request }) => {
  await page.goto("/#/library/personas");
  await expect(page.getByRole("heading", { name: "Personas" })).toBeVisible();
  expect((await request.post("/api/personas", { data: { name: "Wren Hale" } })).status()).toBe(201);
  await expect(page.getByText("Wren Hale", { exact: true })).toBeVisible();

  await page.goto("/#/settings/advanced");
  const told = page.getByLabel("What the AI is told");
  await expect(told).toBeEnabled();
  expect((await request.patch("/api/settings", { data: { plain_prompt: "Be brief." } })).status()).toBe(200);
  await expect(told).toHaveValue("Be brief.");
});

test("a chat shows a message deleted and put back in another window", async ({ page, request }) => {
  const { version } = await card(request, "Harbour");
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: version, character: "mira" }] } });
  expect(started.status(), await started.text()).toBe(201);
  const chat = (await started.json()).chat.id;
  const said = await request.post(`/api/chats/${chat}/messages`, { data: { content: "Why tonight?", role: "user" } });
  expect(said.status(), await said.text()).toBe(201);
  const message = (await said.json()).id;
  await page.goto(`/#/chats/${chat}`);
  const line = page.getByText("Why tonight?");
  await expect(line).toBeVisible();

  expect((await request.delete(`/api/messages/${message}`)).status()).toBe(200);
  await expect(line).toBeHidden();
  expect((await request.post(`/api/messages/${message}/restore`)).status()).toBe(200);
  await expect(line).toBeVisible();
});

/** Starts a chat with the card's Mira, and answers its number. */
async function start(request: APIRequestContext, version: number): Promise<number> {
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: version, character: "mira" }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

test("the chats, the rail and a card's box show a chat started, renamed, starred and put in the Trash elsewhere", async ({ page, request }) => {
  const { id: cardId, version } = await card(request, "Beacon");
  await page.goto("/#/chats");
  await expect(page.getByRole("heading", { name: "Chats" }).first()).toBeVisible();
  const rail = page.locator(".rail-chats").getByText("Mira · Storm Watch");
  const chat = await start(request, version);
  // The file's other tests have chats of their own: the row is this chat's by its link.
  const row = page.locator(".card-row").filter({ has: page.locator(`a[href="#/chats/${chat}"]`) });
  await expect(row).toBeVisible();
  expect((await request.put(`/api/chats/${chat}/title`, { data: { title: "Storm Watch" } })).status()).toBe(200);
  await expect(row).toContainText("Storm Watch");
  await expect(rail).toBeVisible();
  const star = row.getByRole("button", { name: "Favourite" });
  await expect(star).toHaveAttribute("aria-pressed", "false");
  expect((await request.patch(`/api/chats/${chat}`, { data: { favorite: true } })).status()).toBe(200);
  await expect(star).toHaveAttribute("aria-pressed", "true");
  expect((await request.patch(`/api/chats/${chat}`, { data: { trashed: true } })).status()).toBe(200);
  await expect(row).toBeHidden();
  await expect(rail).toBeHidden();

  // The card's box of chats: the chat back from the Trash, and put there again.
  await page.goto(`/#/library/${cardId}`);
  const boxed = page.locator(".main-card").getByRole("link", { name: "Storm Watch" });
  await expect(page.locator(".main-card").getByText("Beacon").first()).toBeVisible();
  await expect(boxed).toBeHidden();
  expect((await request.patch(`/api/chats/${chat}`, { data: { trashed: false } })).status()).toBe(200);
  await expect(boxed).toBeVisible();
  expect((await request.patch(`/api/chats/${chat}`, { data: { trashed: true } })).status()).toBe(200);
  await expect(boxed).toBeHidden();
});

test("a chat's title taken back by Escape shows the name another window gave it meanwhile", async ({ page, request }) => {
  const { version } = await card(request, "Harbour");
  const chat = await start(request, version);
  expect((await request.put(`/api/chats/${chat}/title`, { data: { title: "Storm Watch" } })).status()).toBe(200);
  await page.goto(`/#/chats/${chat}`);
  const line = page.locator(".chat-bar h1 .chat-title");
  await expect(line).toHaveText("Storm Watch");
  await line.click();
  const field = page.locator(".chat-bar h1").getByLabel("Chat title");
  await expect(field).toBeFocused();
  expect((await request.put(`/api/chats/${chat}/title`, { data: { title: "Harbour Watch" } })).status()).toBe(200);
  await expect(page.locator(".rail-chats").getByText("Mira · Harbour Watch")).toBeVisible();
  await field.press("Escape");
  await expect(field).toHaveCount(0);
  await expect(line).toHaveText("Harbour Watch");
});

test("a chat shows a message, a reply and a persona of another window", async ({ page, request }) => {
  const api = await startFakeProvider();
  try {
    await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
    const { version } = await card(request, "Quay");
    const chat = await start(request, version);
    await page.goto(`/#/chats/${chat}`);
    await expect(page.getByText("You came in the storm.")).toBeVisible();

    const said = await request.post(`/api/chats/${chat}/messages`, { data: { content: "Is the lamp lit?", role: "user" } });
    expect(said.status(), await said.text()).toBe(201);
    await expect(page.getByText("Is the lamp lit?")).toBeVisible();
    // A reply asked for elsewhere, as when the characters reply by themselves in another window.
    api.next(["It burns all night."]);
    expect((await request.post(`/api/chats/${chat}/generate`, { data: {} })).status()).toBe(202);
    await expect(page.locator("article.message").last()).toContainText("It burns all night.");

    // The side panel offers a persona made elsewhere.
    expect((await request.post("/api/personas", { data: { name: "Ossian Vale" } })).status()).toBe(201);
    await page.getByRole("complementary", { name: "Chat details" }).getByLabel("Persona", { exact: true }).click();
    await expect(page.getByRole("menuitemradio", { name: "Ossian Vale" })).toBeVisible();
  } finally {
    api.close();
  }
});

test("the settings read the languages again after they could not be read", async ({ page, request }) => {
  let failed = false;
  await page.route("**/api/languages", (route) => (failed ? route.fallback() : ((failed = true), route.fulfill({ status: 500, body: "down" }))));
  await page.goto("/#/settings");
  const language = page.getByRole("button", { name: "Language the AI writes in" });
  await expect(language).toBeDisabled();
  expect((await request.patch("/api/settings", { data: { export_history: true } })).status()).toBe(200);
  await expect(language).toBeEnabled();
});

test("the settings' line to Providers names a provider added in another window", async ({ page, request }) => {
  await page.goto("/#/settings");
  const line = page.locator('a[href="#/settings/providers"] .meta');
  await expect(line).toHaveText("Addresses and keys of the services that run the models");
  expect((await request.post("/api/provider-list", { data: { base_url: "http://127.0.0.1:8080/v1" } })).status()).toBe(201);
  await expect(line).toContainText("Set up: ");
});

test("Sampling's failed store stays told when an earlier store answers after it", async ({ page }) => {
  await page.goto("/#/settings/advanced");
  const temperature = page.getByLabel("Temperature");
  await expect(temperature).toBeEnabled();
  let calls = 0;
  let first: () => void = () => {};
  const answered = new Promise<void>((done) => (first = done));
  await page.route("**/api/sampling", async (route) => {
    if (route.request().method() !== "PUT") return route.fallback();
    if (++calls === 1) {
      await answered;
      return route.fallback();
    }
    return route.fulfill({ status: 500, body: "down" });
  });
  await temperature.fill("0.7");
  await temperature.fill("0.8");
  const told = page.locator(".sampling-part [role=alert]");
  await expect(told).toBeVisible();
  const kept = page.waitForResponse((answer) => answer.url().endsWith("/api/sampling") && answer.status() === 200);
  first();
  await kept;
  await expect(told).toBeVisible();
});

test("the app takes a language chosen while its connection was down once it connects again", async ({ page, request }) => {
  const hear = await deafen(page);
  await page.goto("/#/settings");
  const heading = (name: string) => page.getByRole("heading", { name, exact: true });
  await expect(heading("Settings")).toBeVisible();
  expect((await request.patch("/api/settings", { data: { app_language: "de" } })).status()).toBe(200);
  await page.waitForTimeout(500); // unheard: the connection is down
  await expect(heading("Settings")).toBeVisible();
  await hear();
  await expect(heading("Einstellungen")).toBeVisible();
  expect((await request.patch("/api/settings", { data: { app_language: null } })).status()).toBe(200);
});
