import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// Search Cardwave (board "Tabs · search"): Ctrl+K or the magnifier opens the panel, which searches as typed and
// shows the hits by group; a click opens a hit in the tab in view, Ctrl+Enter and "Open in a new tab" in a new
// one; a lorebook's entry opens the lorebook on it, a setting its page scrolled to it; Escape closes, and it
// opens again with its words. The file's server has no search model, so the words alone find. The settings'
// labels are web/src/setting-labels.ts's, which the pages draw from; the voices' names are the server's.

/** Makes the card North Light with Mira, a chat with her, a lorebook with the entry Gulls and the persona Rell. */
async function make(request: APIRequestContext): Promise<{ lorebook: number; entry: string }> {
  const data = { title: "North Light", tags: ["sea", "storm"], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const card = await request.post("/api/cards/new", { data });
  expect(card.status(), await card.text()).toBe(201);
  const chat = await request.post("/api/chats", { data: { characters: [{ version_id: (await card.json()).version_id, character: "mira" }] } });
  expect(chat.status(), await chat.text()).toBe(201);
  const book = await request.post("/api/lorebooks/new", { data: { name: "Harbour Lore" } });
  const lorebook = (await book.json()).id;
  const entry = await request.post(`/api/lorebooks/${lorebook}/entries`, { data: { name: "Gulls", keywords: ["birds"], content: "They steal the chips of Mira's visitors." } });
  expect(entry.ok(), await entry.text()).toBe(true);
  const persona = await request.post("/api/personas", { data: { name: "Captain Rell", description: "Smuggles for Mira." } });
  expect(persona.status(), await persona.text()).toBe(201);
  return { lorebook, entry: (await entry.json()).reference };
}

const panel = (page: Page) => page.getByRole("dialog", { name: "Search Cardwave" });
const field = (page: Page) => panel(page).getByRole("searchbox", { name: "Search Cardwave" });
const hit = (page: Page, name: string) => panel(page).locator(".hit", { has: page.locator("b", { hasText: new RegExp(`^${name}$`) }) });
const tabTitles = (page: Page) => page.locator("#titlebar .wtab .tt");

let made: { lorebook: number; entry: string };
test.beforeAll(async ({ request }) => {
  made = await make(request);
});

test("Ctrl+K finds characters, chats, lorebooks' entries and personas by their words, and opens one in this tab or a new one", async ({ page }) => {
  await page.goto("/#/chats");
  await expect(page.getByRole("link", { name: /Mira/ }).first()).toBeVisible();
  await page.keyboard.press("Control+k");
  await expect(field(page)).toBeFocused();
  // Nothing typed, a line says what it searches.
  await expect(panel(page).getByText("Characters, chats, lorebooks, memories, documents and pages")).toBeVisible();
  await field(page).fill("mira");
  await expect(panel(page).getByRole("group")).toHaveText([/^Characters/, /^Lorebooks/, /^Chats/, /^Personas/]);
  await expect(hit(page, "North Light")).toContainText("as Mira · sea · storm");
  await expect(hit(page, "Harbour Lore")).toContainText("Gulls · They steal the chips of Mira's visitors.");
  await expect(hit(page, "North Light")).toHaveClass(/is-hover/);

  // The arrows and Enter: the entry opens in its lorebook, in the tab in view.
  await page.keyboard.press("ArrowDown");
  await expect(hit(page, "Harbour Lore")).toHaveClass(/is-hover/);
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(new RegExp(`#/library/lorebooks/${made.lorebook}/${made.entry.replace(".", "\\.")}$`));
  await expect(panel(page)).toBeHidden();
  await expect(tabTitles(page)).toHaveCount(1);

  // It opens again with its words; Ctrl+Enter opens the chat in a new tab, "Open in a new tab" the persona.
  await page.getByRole("button", { name: "Search Cardwave" }).click();
  await expect(field(page)).toHaveValue("mira");
  await hit(page, "Mira").hover();
  await page.keyboard.press("Control+Enter");
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(tabTitles(page)).toHaveCount(2);
  await page.keyboard.press("Control+k");
  await hit(page, "Captain Rell").hover();
  await hit(page, "Captain Rell").getByRole("button", { name: "Open in a new tab" }).click();
  await expect(page).toHaveURL(/#\/library\/personas$/);
  await expect(tabTitles(page)).toHaveCount(3);
  await expect(page.locator(".row.found")).toContainText("Captain Rell");

  // Nothing found; Escape closes.
  await page.keyboard.press("Control+k");
  await field(page).fill("pineapple");
  await expect(panel(page).getByText("Nothing found for “pineapple”.")).toBeVisible();
  await expect(panel(page).getByText("The words of messages are not searched; try the chat’s character.")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(panel(page)).toBeHidden();
});

test("the hit chosen stays chosen when the hits by meaning come, also among hits of one page", async ({ page, request }) => {
  const made = await request.post("/api/personas", { data: { name: "Captain Odo", description: "Keeps the tide tables." } });
  expect(made.status(), await made.text()).toBe(201);
  // The answer by meaning is held until the second persona is chosen.
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route(/\/api\/find\?.*meaning=true/, async (route) => {
    await held;
    await route.fallback();
  });
  await page.goto("/#/chats");
  await page.keyboard.press("Control+k");
  await field(page).fill("captain");
  await expect(hit(page, "Captain Odo")).toBeVisible();
  await page.keyboard.press("ArrowDown");
  const chosen = panel(page).locator(".hit.is-hover b");
  const second = await chosen.textContent();
  const answered = page.waitForResponse(/\/api\/find\?.*meaning=true/);
  release();
  await answered;
  await expect(chosen).toHaveText(second!);
});

test("a setting is found by its label and opens its page scrolled to it; a long group shows all on asking", async ({ page }) => {
  await page.goto("/#/chats");
  await page.getByRole("button", { name: "Search Cardwave" }).click();
  await field(page).fill("set");
  const pages = panel(page).getByRole("group", { name: "Pages" });
  await expect(pages.locator(".hit")).toHaveCount(3);
  await pages.getByRole("button", { name: /^Show all \d+$/ }).click();
  await expect.poll(() => pages.locator(".hit").count()).toBeGreaterThan(3);

  const [address, label] = ["#/settings/advanced", "Your own CSS"];
  await field(page).fill(label);
  await hit(page, label).click();
  await expect(page).toHaveURL(new RegExp(`${address}$`));
  await expect(page.locator(".item.found .item-label")).toHaveText(label);
  await expect(page.locator(".item.found")).toBeInViewport();
});

test("a voice is found by its name, as the server lists it", async ({ page }) => {
  await page.goto("/#/chats");
  await page.getByRole("button", { name: "Search Cardwave" }).click();
  await field(page).fill("alba");
  await hit(page, "Alba").click();
  await expect(page).toHaveURL(/#\/settings\/voices$/);
  await expect(page.locator(".found .item-label")).toHaveText("Alba");
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the search panel", async ({ page }) => {
        await page.goto("/#/settings/trash");
        await page.keyboard.press("Control+k");
        await field(page).fill("mira");
        await expect(hit(page, "Captain Rell")).toBeVisible();
        await picture(page, `search-${width}-${theme}`);
      });
    });
  }
}
