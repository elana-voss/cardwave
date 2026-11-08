import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, stopClock } from "../pictures";

// Split view (board "Split view"): from 1200 px the chat's header has "Show card editor", which opens the
// card's texts beside the chat in the side panel's place, written as on the card page, a change used from the next
// reply; the rail folds to its icons meanwhile; "Open card page" leads to the card; the divider is dragged, each
// side at least 420 px, and the split and its width are remembered; a chat of several chooses whose card, and a
// chat in a mode shows that mode's texts. The picture (1440 px, light) is of the split as it opens.

let provider: FakeProvider;
test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
});
test.afterAll(() => provider.close());
test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
test.beforeEach(({ page }) => stopClock(page));

/** A card of one character, `name`: its version and its card's number. */
async function newCard(request: APIRequestContext, name: string, description: string): Promise<{ card_id: number; version_id: number }> {
  const made = await request.post("/api/cards", { data: cardFile({ name, description, personality: "Patient.", first_mes: `${name} lights the lamp.` }, [30, 45]) });
  expect(made.status(), await made.text()).toBe(201);
  return made.json();
}

/** A chat with the characters of `versions`, each called by its `character`: its number. */
async function newChat(request: APIRequestContext, ...characters: { version_id: number; character: string }[]): Promise<number> {
  const started = await request.post("/api/chats", { data: { characters } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

const editor = (page: Page) => page.getByRole("region", { name: "Character page" });
const splitButton = (page: Page) => page.locator(".bar-tools").getByRole("button", { name: /character page/ });
/** A text of the card in the split view, by its name. */
const part = (page: Page, name: string) => editor(page).locator("section.tb", { has: page.getByRole("heading", { name, exact: true }) });
const rail = (page: Page) => page.evaluate(() => document.body.dataset.rail);

test("the split view writes the card beside the chat, used from the next reply, and folds the rail meanwhile", async ({ page, request }) => {
  const ada = await newCard(request, "Ada", "Ada keeps the lighthouse.");
  const chat = await newChat(request, { version_id: ada.version_id, character: "ada" });
  await page.goto(`/#/chats/${chat}`);
  await expect(page.getByRole("complementary", { name: "Chat details" })).toBeVisible();
  expect(await rail(page)).toBe("wide");
  await expect(splitButton(page)).toHaveAccessibleName("Show character page");
  await splitButton(page).click();

  await expect(part(page, "Description")).toContainText("Ada keeps the lighthouse.");
  await expect(editor(page).getByRole("heading", { level: 2 })).toHaveText(["First message", "Description", "Personality", "Scenario", "Example dialogue", "Instructions for the AI", "Instructions after the latest messages", "Creator notes", "How often they speak in a group chat"]);
  await expect(editor(page).locator(".split-title")).toHaveText("Ada");
  await expect(editor(page).getByRole("link", { name: "Open character page" })).toHaveAttribute("href", `#/library/${ada.card_id}`);
  await expect(page.getByRole("complementary", { name: "Chat details" })).toBeHidden();
  await expect(splitButton(page)).toHaveAccessibleName("Hide character page");
  await expect(splitButton(page)).toHaveAttribute("aria-pressed", "true");
  expect(await rail(page)).toBe("narrow");
  await picture(page, "split-view-1440-light");

  // A text written there is the card's, and the next reply's.
  await part(page, "Description").locator(".tb-body").click();
  const description = editor(page).getByRole("textbox", { name: "Description", exact: true });
  await description.fill("Ada keeps the north light.");
  await description.evaluate((node) => (node as HTMLElement).blur());
  await expect.poll(async () => (await (await request.get(`/api/cards/${ada.card_id}/edit`)).json()).characters[0].description[0].text).toBe("Ada keeps the north light.");
  const composer = page.getByLabel("Message", { exact: true });
  await composer.fill("Is the lamp lit?");
  await composer.press("Enter");
  await expect(page.locator(".message").last().locator(".text")).toHaveText("Echo: Is the lamp lit?");
  expect(JSON.stringify(provider.asked.at(-1)!.body.messages)).toContain("Ada keeps the north light.");

  // Kept for the next start; its × closes it, the panel and the wide rail come back.
  await page.reload();
  await expect(part(page, "Description")).toContainText("Ada keeps the north light.");
  await editor(page).getByRole("button", { name: "Hide character page" }).click();
  await expect(editor(page)).toBeHidden();
  await expect(page.getByRole("complementary", { name: "Chat details" })).toBeVisible();
  expect(await rail(page)).toBe("wide");
  await page.reload();
  await expect(page.getByRole("complementary", { name: "Chat details" })).toBeVisible();
  await expect(editor(page)).toBeHidden();

  // The side panel's button closes the split view to show the panel.
  await splitButton(page).click();
  await expect(editor(page)).toBeVisible();
  await page.getByRole("button", { name: "Show side panel" }).click();
  await expect(editor(page)).toBeHidden();
  await expect(page.getByRole("complementary", { name: "Chat details" })).toBeVisible();

  await splitButton(page).click();
  await editor(page).getByRole("link", { name: "Open character page" }).click();
  await expect(page).toHaveURL(new RegExp(`#/library/${ada.card_id}$`));
  await expect(page.locator(".hero h1")).toHaveText("Ada");
  expect(await rail(page)).toBe("wide");
});

test("the divider is dragged, each side at least 420 px, and the width kept; a window under 1200 px has no split view", async ({ page, request }) => {
  const bea = await newCard(request, "Bea", "Bea rows.");
  const chat = await newChat(request, { version_id: bea.version_id, character: "bea" });
  await page.goto(`/#/chats/${chat}`);
  if ((await splitButton(page).getAttribute("aria-pressed")) !== "true") await splitButton(page).click();
  await expect(part(page, "Description")).toBeVisible();
  const chatSide = page.locator(".chat-main");
  const dragTo = async (x: number) => {
    const divider = (await editor(page).locator(".split-divider").boundingBox())!;
    await page.mouse.move(divider.x + 4, divider.y + 300);
    await page.mouse.down();
    await page.mouse.move(x, divider.y + 300, { steps: 4 });
    await page.mouse.up();
  };
  await dragTo(1430);
  await expect.poll(async () => (await editor(page).boundingBox())!.width).toBe(420);
  await dragTo(0);
  await expect.poll(async () => (await chatSide.boundingBox())!.width).toBe(420);
  await dragTo(900);
  const width = (await editor(page).boundingBox())!.width;
  expect(width).toBeGreaterThan(420);
  await page.reload();
  await expect(part(page, "Description")).toBeVisible();
  expect((await editor(page).boundingBox())!.width).toBe(width);

  await page.setViewportSize({ width: 1100, height: 900 });
  await expect(editor(page)).toBeHidden();
  await expect(splitButton(page)).toBeHidden();
  expect(await rail(page)).toBe("wide");
  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(editor(page)).toBeVisible();
  expect(await rail(page)).toBe("narrow");
});

test("a chat of several chooses whose card, and a chat in a mode shows that mode's texts", async ({ page, request }) => {
  const cid = await newCard(request, "Cid", "Cid mends nets.");
  const dot = await newCard(request, "Dot", "Dot reads the tides.");
  const chat = await newChat(request, { version_id: cid.version_id, character: "cid" }, { version_id: dot.version_id, character: "dot" });
  await page.goto(`/#/chats/${chat}`);
  if ((await splitButton(page).getAttribute("aria-pressed")) !== "true") await splitButton(page).click();
  await expect(part(page, "Description")).toContainText("Cid mends nets.");
  // A save of the card left behind that fails is not told under the card now shown.
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route(`**/api/cards/${cid.card_id}/edit*`, async (route) => {
    if (route.request().method() !== "PUT") return route.fallback();
    await held;
    await route.fulfill({ status: 500, json: { code: "internal", error: "the disk is full", details: {} } });
  });
  await part(page, "Personality").locator(".tb-body").click();
  const personality = editor(page).getByRole("textbox", { name: "Personality", exact: true });
  await personality.fill("Gruff.");
  await personality.evaluate((node) => (node as HTMLElement).blur());
  await editor(page).getByRole("button", { name: "Character", exact: true }).click();
  await page.getByRole("menuitemradio", { name: "Dot" }).click();
  await expect(part(page, "Description")).toContainText("Dot reads the tides.");
  await expect(editor(page).locator(".split-title")).toHaveText("Dot");
  // The card left behind is read again after its failure, and then tells it.
  const reread = page.waitForResponse((response) => response.url().includes(`/api/cards/${cid.card_id}/edit`) && response.request().method() === "GET");
  release();
  await reread;
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
  await expect(editor(page).locator(".split-title")).toHaveText("Dot");
  await expect(editor(page).getByRole("alert")).toHaveCount(0);

  const eve = await newCard(request, "Eve", "Eve sails.");
  const edit = await (await request.get(`/api/cards/${eve.card_id}/edit`)).json();
  expect((await request.put(`/api/cards/${eve.card_id}/edit`, { data: { ...edit, modes: ["Roleplay", "Assistant"] } })).status()).toBe(200);
  const card = await (await request.get(`/api/cards/${eve.card_id}`)).json();
  const alone = await newChat(request, { version_id: card.card.version_id, character: "eve" });
  expect((await request.put(`/api/chats/${alone}/mode`, { data: { mode: "Assistant" } })).status()).toBe(200);
  await page.goto(`/#/chats/${alone}`);
  await expect(editor(page).getByRole("group", { name: "Mode" }).getByRole("button", { name: "Assistant" })).toHaveAttribute("aria-pressed", "true");
  await expect(editor(page).getByRole("button", { name: "Character", exact: true })).toBeHidden();
  // The chat set to another mode shows that mode's texts.
  await page.locator(".mode-pill").click();
  await page.getByRole("menuitemradio", { name: "Roleplay" }).click();
  await expect(editor(page).getByRole("group", { name: "Mode" }).getByRole("button", { name: "Roleplay" })).toHaveAttribute("aria-pressed", "true");
});
