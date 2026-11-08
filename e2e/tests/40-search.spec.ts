import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeSearch, type FakeSearch } from "../fake-search";

// Search by description: the search model set up from the settings' line "Search" and its dialog (Download,
// Cancel, Remove), and the library's search finding a card by its meaning. The model is the stand-in of
// fake-search.ts, which never downloads bge-m3; its vectors put "ocean" near a lighthouse. Before it is set up the
// words alone find.

let search: FakeSearch;

test.beforeAll(async () => {
  search = await startFakeSearch();
});
test.afterAll(() => search.close());

async function newCard(request: APIRequestContext, title: string, description: string): Promise<void> {
  const data = { title, tags: [], creator: "", name: title, greetings: ["Hello."], description, personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
}

const line = (page: Page) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: /^Search$/ }) });
const dialog = (page: Page) => page.getByRole("dialog", { name: "Search" });
const state = (page: Page) => dialog(page).locator(".item-text + .meta");

test("without the search model the library's search finds a card by the words of its title, name and tags", async ({ page, request }) => {
  const data = { title: "Ember Forge", tags: ["smithing"], creator: "", name: "Brann", greetings: ["Hello."], description: "Iron and coal.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  await page.goto("/#/settings");
  await expect(line(page).locator(".meta")).toHaveText("Not set up");
  await page.goto("/#/library");
  const titles = page.locator(".card-row .row-title");
  await expect(titles).toHaveText(["Ember Forge"]);
  for (const words of ["ember", "Brann", "smith", "forge brann"]) {
    await page.getByLabel("Search characters").fill(words);
    await expect(titles).toHaveText(["Ember Forge"]);
  }
  await page.getByLabel("Search characters").fill("anvil");
  await expect(titles).toHaveCount(0);
  // It goes to the Trash, out of the next test, whose cards the search model is to find by meaning.
  expect((await request.patch(`/api/cards/${(await made.json()).card_id}`, { data: { trashed: true } })).status()).toBe(200);
});

test("the search model is downloaded from the settings when asked, and the library then finds a card by its meaning", async ({ page, request }) => {
  await newCard(request, "North Light", "She keeps the lighthouse through every storm.");
  await newCard(request, "Drift", "A starship pilot far from any planet.");
  await page.goto("/#/settings");
  await expect(line(page).locator(".meta")).toHaveText("Not set up");

  // Nothing is downloaded before "Download"; one held at its start can be cancelled.
  await page.getByRole("button", { name: "Set up search" }).click();
  await expect(dialog(page).locator(".item-label")).toHaveText("On this computer");
  await expect(state(page)).toHaveText("Not downloaded");
  search.hold();
  await dialog(page).getByRole("button", { name: "Download" }).click();
  await expect(state(page)).toHaveText(/^\d+%$/);
  await expect(line(page).locator(".meta")).toHaveText(/^bge-m3 · downloading \d+%$/);
  await dialog(page).getByRole("button", { name: "Cancel" }).click();
  search.release();
  await expect(state(page)).toHaveText("Not downloaded");

  await dialog(page).getByRole("button", { name: "Download" }).click();
  await expect(state(page)).toHaveText("Ready");
  await expect(dialog(page).getByRole("button", { name: "Delete" })).toBeFocused();
  await dialog(page).getByRole("button", { name: "Close" }).click();
  await expect(line(page).locator(".meta")).toHaveText("bge-m3 · This computer");

  // "ocean" is in neither card's words, and near the lighthouse in meaning.
  await page.goto("/#/library");
  await page.getByLabel("Search characters").fill("ocean");
  await expect(page.locator(".card-row .row-title")).toHaveText(["North Light"]);

  // Removed, the model finds nothing more by meaning.
  await page.goto("/#/settings");
  await page.getByRole("button", { name: "Change search" }).click();
  await dialog(page).getByRole("button", { name: "Delete" }).click();
  await expect(state(page)).toHaveText("Not downloaded");
});
