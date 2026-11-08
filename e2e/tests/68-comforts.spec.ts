import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { PICTURE, startFakeProvider, type FakeProvider } from "../fake-provider";

// The chat's and the library's comforts: the character's bubble with the typing sign at once on Send, the field
// and the messages there to type in and edit while the reply arrives, a message's links and pictures, Escape
// closing one thing at a time, what was typed and not saved coming back (the message field, a message being
// edited, a card's text), the library's search and scroll kept on coming back, and an exact copy of a card not
// imported again. `unsaved` waits until the server has what was typed (it is sent a moment after the typing).

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** A card made through the API, called `title`, and its id and version. */
async function card(request: APIRequestContext, title: string): Promise<{ id: number; version: number; character: string }> {
  const data = { title, tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const id = (await made.json()).card_id;
  const read = await (await request.get(`/api/cards/${id}`)).json();
  return { id, version: read.card.version_id, character: read.characters[0].id };
}

/** A chat with Mira, and its number. */
async function chat(request: APIRequestContext): Promise<number> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const { version, character } = await card(request, "North Light");
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: version, character }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

/** Waits until the server has the unsaved text typed into a field. */
const unsaved = (page: Page) => page.waitForResponse((answer) => answer.url().includes("/api/unsaved/") && answer.request().method() === "PUT");

const field = (page: Page) => page.getByLabel("Message", { exact: true });

test("the reply's bubble shows its typing sign at once, and the field and the messages take words while it arrives", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  // The reply's request is held until the bubble was seen.
  let let_go = () => {};
  const asked = new Promise<void>((done) => (let_go = done));
  await page.route("**/generate", async (route) => {
    await asked;
    await route.fallback();
  });
  const held = api.hold(["The tide", " turns tonight."]);
  await field(page).fill("Why tonight?");
  await page.getByRole("button", { name: "Send" }).click();
  const waiting = page.locator("article.message.asked");
  await expect(waiting.locator(".typing")).toBeVisible();
  await expect(waiting.locator(".speaker")).toHaveText("Mira");
  let_go();
  const reply = page.locator("article.message.assistant").last();
  await expect(reply.locator(".text")).toHaveText("The tide");
  await expect(waiting).toHaveCount(0);

  // While it arrives: words typed in the field, and the user's message changed.
  await expect(page.getByRole("button", { name: "Stop" })).toBeVisible();
  await field(page).fill("And tomorrow?");
  const mine = page.locator("article.message.user").last();
  await mine.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Edit message" }).click();
  await page.getByLabel("Edit message").fill("Why tonight, keeper?");
  await mine.getByRole("button", { name: "Save" }).click();
  await expect(mine.locator(".text")).toHaveText("Why tonight, keeper?");
  held.release();
  await expect(reply.locator(".text")).toHaveText("The tide turns tonight.");
  await expect(field(page)).toHaveValue("And tomorrow?");
});

test("a reply come whole before its request answers has no bubble waiting beside it", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  let answer = () => {};
  const answered = new Promise<void>((done) => (answer = done));
  await page.route("**/generate", async (route) => {
    const response = await route.fetch();
    await answered;
    await route.fulfill({ response });
  });
  api.next(["Before the tide."]);
  await field(page).fill("When?");
  await page.getByRole("button", { name: "Send" }).click();
  const reply = page.locator("article.message.assistant").last();
  await expect(reply.locator(".text")).toHaveText("Before the tide.");
  await expect(page.locator("article.message.asked")).toHaveCount(0);
  answer();
  await expect(page.getByRole("button", { name: "Send" })).toBeVisible();
});

test("a message's links open beside the app and its pictures show", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  api.next([`See [the map](https://example.com/map). ![A lamp](data:image/png;base64,${PICTURE})`]);
  await field(page).fill("Show me.");
  await page.getByRole("button", { name: "Send" }).click();
  const reply = page.locator("article.message.assistant").last();
  const link = reply.getByRole("link", { name: "the map" });
  await expect(link).toHaveAttribute("href", "https://example.com/map");
  await expect(link).toHaveAttribute("target", "_blank");
  await expect(reply.getByRole("img", { name: "A lamp" })).toBeVisible();
});

test("a picture from another website is held back until Show pictures from other websites is switched on, from the message or Settings", async ({ page, request }) => {
  const id = await chat(request);
  const asked: string[] = [];
  await page.route("https://pictures.example/**", (route) => {
    asked.push(route.request().url());
    return route.fulfill({ contentType: "image/png", body: Buffer.from(PICTURE, "base64") });
  });
  await page.goto("/#/settings");
  const web = page.getByRole("switch", { name: "Show pictures from other websites" });
  await expect(web).toBeEnabled();
  await expect(web).not.toBeChecked();
  await page.goto(`/#/chats/${id}`);
  api.next(["![A boat](https://pictures.example/boat.png)"]);
  await field(page).fill("Show me the boat.");
  await page.getByRole("button", { name: "Send" }).click();
  const reply = page.locator("article.message.assistant").last();
  const held = reply.locator(".web-picture");
  await expect(held).toContainText("A picture from another website is hidden");
  await expect(held).toContainText("You can change this in Settings › Appearance at any time.");
  await expect(reply.getByRole("img")).toHaveCount(0);
  expect(asked).toEqual([]);
  await held.getByRole("button", { name: "Show pictures from the web" }).click();
  // The page loads again, as its policy let no picture from the web load before.
  const boat = page.locator("article.message.assistant").last().getByRole("img", { name: "A boat" });
  await expect.poll(() => boat.evaluate((picture: HTMLImageElement) => picture.complete && picture.naturalWidth)).toBeGreaterThan(0);
  expect(asked).toEqual(["https://pictures.example/boat.png"]);
  // Kept by the server: Settings shows it on, and switched off there the chat holds the picture back again.
  await page.goto("/#/settings");
  await expect(web).toBeChecked();
  await web.click();
  await expect(web).toBeEnabled();
  await expect(web).not.toBeChecked();
  await page.goto(`/#/chats/${id}`);
  await expect(page.locator("article.message.assistant").last().locator(".web-picture")).toBeVisible();
});

test("Escape closes one thing at a time: the menu, then the message being edited, then the reply chosen", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  const greeting = page.locator("article.message.assistant").first();
  await greeting.locator(".bubble").click();
  await expect(greeting).toHaveClass(/\bchosen\b/);
  await greeting.getByRole("button", { name: "Message options" }).click();
  await expect(page.getByRole("menuitem", { name: "Edit message" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("menuitem", { name: "Edit message" })).toBeHidden();
  await expect(greeting).toHaveClass(/\bchosen\b/);
  await greeting.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Edit message" }).click();
  await page.getByLabel("Edit message").press("Escape");
  await expect(page.getByLabel("Edit message")).toHaveCount(0);
  await expect(greeting).toHaveClass(/\bchosen\b/);
  await page.keyboard.press("Escape");
  await expect(greeting).not.toHaveClass(/\bchosen\b/);
});

test("what was typed and not saved comes back: the message field, a message being edited, a card's text", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  let sent = unsaved(page);
  await field(page).fill("Half a thought");
  await sent;
  const greeting = page.locator("article.message.assistant").first();
  await greeting.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Edit message" }).click();
  sent = unsaved(page);
  await page.getByLabel("Edit message").fill("You came in the gale.");
  await sent;
  await page.reload();
  await expect(field(page)).toHaveValue("Half a thought");
  await expect(page.getByLabel("Edit message")).toHaveCount(0);
  await greeting.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Edit message" }).click();
  await expect(page.getByLabel("Edit message")).toHaveValue("You came in the gale.");
  // Cancel lets it go.
  await greeting.getByRole("button", { name: "Cancel" }).click();
  await greeting.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Edit message" }).click();
  await expect(page.getByLabel("Edit message")).toHaveValue("You came in the storm.");

  const { id: cardId } = await card(request, "Tern Rock");
  await page.goto(`/#/library/${cardId}`);
  const description = page.getByRole("region", { name: "Description" }).locator(".tb-body");
  await description.click();
  sent = unsaved(page);
  await page.getByRole("textbox", { name: "Description", exact: true }).fill("A keeper of the light, unsaved.");
  await sent;
  await page.reload();
  await expect(description.locator(".md")).toHaveText("A lighthouse keeper.");
  await description.click();
  await expect(page.getByRole("textbox", { name: "Description", exact: true })).toHaveValue("A keeper of the light, unsaved.");

  // A save that fails leaves the words to come back.
  await page.route("**/api/cards/*/edit", (route) => route.fulfill({ status: 500, body: "The disk is full." }));
  const failed = page.waitForResponse((answer) => answer.url().includes("/edit") && answer.request().method() === "PUT");
  await page.getByRole("textbox", { name: "Description", exact: true }).press("Escape");
  await failed;
  await page.unroute("**/api/cards/*/edit");
  await page.reload();
  await description.click();
  await expect(page.getByRole("textbox", { name: "Description", exact: true })).toHaveValue("A keeper of the light, unsaved.");
});

test("the library keeps its search and how far it was scrolled on coming back", async ({ page, request }) => {
  let last = 0;
  for (let n = 1; n <= 30; n++) last = (await card(request, `Gull ${String(n).padStart(2, "0")}`)).id;
  await page.goto("/#/library");
  await page.getByLabel("Search characters").fill("Gull");
  await expect(page.locator(".card-row").first()).toHaveAttribute("aria-setsize", "30");
  const list = page.locator(".main.library");
  await list.evaluate((node) => node.scrollTo(0, 600));
  await page.goto(`/#/library/${last}`);
  await expect(page.getByRole("heading", { name: "Gull 30" })).toBeVisible();
  await page.goBack();
  await expect(page.getByLabel("Search characters")).toHaveValue("Gull");
  await expect(page.locator(".card-row").first()).toHaveAttribute("aria-setsize", "30");
  await expect.poll(() => list.evaluate((node) => node.scrollTop)).toBe(600);
});

test("an exact copy of a card is not imported again", async ({ page }) => {
  const file = { name: "petrel.png", mimeType: "image/png", buffer: cardFile({ name: `Petrel ${Date.now()}`, first_mes: "Petrels skim the swell." }) };
  await page.goto("/#/library");
  const pick = page.locator("input[type=file]");
  await pick.setInputFiles(file);
  await expect(page.locator(".card-row", { hasText: "Petrel" })).toHaveCount(1);
  await pick.setInputFiles(file);
  await expect(page.locator(".import-line", { hasText: "petrel.png" })).toContainText("Already in your library");
  await expect(page.locator(".card-row", { hasText: "Petrel" })).toHaveCount(1);
});
