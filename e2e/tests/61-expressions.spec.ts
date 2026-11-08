import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile, pictureFile } from "../card";
import { startFakeSearch, type FakeSearch } from "../fake-search";

// Expressions (boards "Card page · expressions and 3D figure", "Add expressions"): a pack from a file put on a card,
// taken off with Undo, chosen for another card among those the app holds, and in a chat the picture of the reply's
// mood in the portrait's place, told by the search model's stand-in (fake-search.ts), whose vector of a mood's own
// description is that mood's. The pictures are told apart by their width: joy 40, neutral 50, the card's own 30.

let search: FakeSearch;
test.beforeAll(async () => {
  search = await startFakeSearch();
});
test.afterAll(() => search.close());

async function newCard(request: APIRequestContext, name: string): Promise<{ card_id: number; version_id: number }> {
  const made = await request.post("/api/cards", { data: cardFile({ name, first_mes: "The lamp is lit." }, [30, 45]) });
  expect(made.status(), await made.text()).toBe(201);
  return made.json();
}

const part = (page: Page) => page.locator(".part", { has: page.getByRole("heading", { name: "Expressions" }) });

/** Opens "Add expressions" by the card menu: a card without expressions shows no part for them. */
async function byMenu(page: Page): Promise<void> {
  await expect(part(page)).toHaveCount(0);
  await page.getByRole("button", { name: "Character menu", exact: true }).click();
  await page.getByRole("menuitem", { name: "Add expressions" }).click();
}

/** Opens "Add expressions" by the part's "+". */
const byPlus = (page: Page) => part(page).getByRole("button", { name: "Add expressions" }).click();

async function fromFiles(page: Page, opens: (page: Page) => Promise<void> = byMenu): Promise<void> {
  await opens(page);
  const adding = page.getByRole("dialog", { name: "Add expressions" });
  await expect(adding.getByRole("button", { name: "From files…" })).toBeEnabled();
  const chooser = page.waitForEvent("filechooser");
  await adding.getByRole("button", { name: "From files…" }).click();
  await (await chooser).setFiles([
    { name: "joy.png", mimeType: "image/png", buffer: pictureFile([40, 60], 0x40) },
    { name: "neutral.png", mimeType: "image/png", buffer: pictureFile([50, 75], 0x80) },
    { name: "notes.txt", mimeType: "text/plain", buffer: Buffer.from("not a mood") },
  ]);
  await expect(adding).toBeHidden();
}

test("a pack from a file goes on a card, comes off with Undo, and is chosen for another card", async ({ page, request }) => {
  const mira = await newCard(request, "Mira");
  const tom = await newCard(request, "Tom");
  await page.goto(`/#/library/${mira.card_id}`);
  await byMenu(page);
  const empty = page.getByRole("dialog", { name: "Add expressions" });
  await expect(empty).toContainText("No expressions yet: pictures of the character's moods");
  // Nothing to choose: no Add, and the files are the main button.
  await expect(empty.getByRole("button", { name: "Add", exact: true })).toBeHidden();
  await expect(empty.getByRole("button", { name: "From files…" })).toHaveClass(/btn-primary/);
  await page.keyboard.press("Escape");
  // The part asked for stays, empty, while the page is open.
  await expect(part(page)).toContainText("None yet · the chat shows the character’s picture");
  await fromFiles(page, byPlus);
  await expect(part(page).locator(".row")).toContainText("Mira · 2 expressions");
  await expect(part(page).locator(".strip img")).toHaveCount(2);

  await part(page).getByRole("button", { name: "Remove Mira from this character" }).click();
  await expect(page.locator("#toast")).toContainText("Expressions removed from this character.");
  await expect(part(page)).toContainText("None yet · the chat shows the character’s picture");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(part(page).locator(".row")).toContainText("Mira · 2 expressions");

  await page.goto(`/#/library/${tom.card_id}`);
  await expect(page.getByRole("button", { name: "Character menu", exact: true })).toBeVisible();
  await byMenu(page);
  const adding = page.getByRole("dialog", { name: "Add expressions" });
  const line = adding.getByRole("button", { name: /Mira/ });
  await expect(line).toContainText("2 expressions · used by 1 character");
  await expect(adding.getByRole("button", { name: "Add", exact: true })).toBeDisabled();
  await line.click();
  await expect(line).toHaveAttribute("aria-pressed", "true");
  await adding.getByRole("button", { name: "Add", exact: true }).click();
  await expect(part(page).locator(".row")).toContainText("Mira · 2 expressions");
});

test("in a chat the portrait shows the picture of the reply's mood", async ({ page, request }) => {
  expect((await request.post("/api/search/download")).status()).toBe(200);
  await expect.poll(async () => (await (await request.get("/api/search")).json()).state, { timeout: 15_000 }).toBe("ready");
  const card = await newCard(request, "Ada");
  await page.goto(`/#/library/${card.card_id}`);
  // The same pictures again: the pack the app holds.
  await fromFiles(page);
  await expect(part(page).locator(".row")).toContainText("Mira · 2 expressions");
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.version_id, character: "ada" }] } });
  expect(started.status(), await started.text()).toBe(201);
  const view = await started.json();
  const said = await request.patch(`/api/messages/${view.messages[0].id}`, { data: { content: "great happiness, delight, and cheer" } });
  expect(said.status(), await said.text()).toBe(200);

  await page.goto(`/#/chats/${view.chat.id}`);
  const panel = page.getByRole("complementary", { name: "Chat details" });
  await panel.getByRole("switch", { name: "Show the character's picture" }).check();
  const portrait = panel.locator("img.portrait");
  await expect.poll(() => portrait.evaluate((image: HTMLImageElement) => (image.complete ? image.naturalWidth : 0)), { timeout: 15_000 }).toBe(40);
});
