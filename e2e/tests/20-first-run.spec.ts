import { writeFileSync } from "node:fs";
import { join } from "node:path";
import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { startFakeSearch, type FakeSearch } from "../fake-search";

// First run in its four steps: the key, the models the server picked from it (tested), the folder of cards (the
// one offered, the server's stand-in for the user's Documents, `e2e/server.mjs`, given one card) and the downloads of the voice and the
// search model (step 4 asks first; the voice switched on there beside the search model), gone through to "Open Cardwave"; the provider is a stand-in (`api`), the downloads come from
// fake-search.ts (`search`); no test asks a provider. The first test downloads both, so the second's "Skip"
// leads into the app at once.
//
// `open` starts the app anew from an empty page, as a `page.goto` to the address it is at does nothing. A
// stand-in is on no list of providers and its key (`KEY`) begins as no provider's does, so `toModels` gets to
// step 2 by "Enter address" (`byAddress`). The servers on this computer that the list names may be running,
// so `open` answers the asking for their models itself: none is there (`LOCAL`). A key that begins with "sk-"
// is OpenAI's, DeepSeek's or Alibaba's by the app's own list, and has the user choose between them: a test's keys begin
// otherwise (seen: "Continue" could not be pressed). The lines' buttons are named "Change the chat model" and
// "Change the helper model", so the key's field is asked for with `getByLabel("API key", { exact: true })`.
// `picker` is the model picker by its title, "Chat model" or "Helper model".

let api: FakeProvider;
let search: FakeSearch;

test.beforeAll(async () => {
  api = await startFakeProvider();
  search = await startFakeSearch();
});
test.afterAll(async () => {
  await Promise.all([api.close(), search.close()]);
});

/** A key long enough for its end to be told, which begins as no provider's keys do. */
const KEY = "key-first-run-0123456789-4f2a";
/** The servers on this computer the list of providers names, by their ports. */
const LOCAL = /^http:\/\/127\.0\.0\.1:(5001|1234|11434)\//;
const QUESTION = "Reply with the single word OK.";

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const heading = (page: Page) => page.locator(".setup h1");
const where = (page: Page) => page.locator(".setup-where");
const about = (page: Page) => page.locator(".setup-head p");
const address = (page: Page) => page.getByLabel("Address");
const key = (page: Page) => page.getByLabel("API key", { exact: true });
/** A line of the step shown, by its name. */
const line = (page: Page, name: string) => page.locator(".setup .item:visible", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });
/** What a line of step 2 says under its name. */
const says = (page: Page, name: string) => line(page, name).locator(".item-text > .meta");
/** What a download's line says at its right. */
const state = (page: Page, name: string) => line(page, name).locator(".download-state");
/** What failed, in red under the chat model's line. */
const wrong = (page: Page) => line(page, "Chat").getByRole("alert");
const change = (page: Page) => button(page, "Change the chat model");
const retry = (page: Page) => button(page, "Try again");
const confirm = (page: Page) => button(page, "Continue");
const openApp = (page: Page) => button(page, "Open Cardwave");
const picker = (page: Page, title: string) => page.getByRole("dialog", { name: title });
/** Picks `id` in the picker called `title`. */
async function pick(page: Page, title: string, id: string): Promise<void> {
  await picker(page, title).getByLabel("Model", { exact: true }).fill(id);
  // Enter, as the list under the field may lie over the button.
  await picker(page, title).getByLabel("Model", { exact: true }).press("Enter");
  await expect(page.locator("dialog")).toHaveCount(0);
}
/** The address's host, as the key's line says where it is. */
const host = (of: FakeProvider) => new URL(of.url).host;

/** The first step has what it shows: the list of providers has come, and with it the step is as it stays. */
const ready = (page: Page) => expect(page.locator(".key-step :is(.no-key, .by-hand):visible")).toHaveCount(1);

/** Opens first run as of a user who has no stored provider. */
async function open(page: Page): Promise<void> {
  await page.route("**/api/provider", (route) => (route.request().method() === "GET" ? route.fulfill({ json: null }) : route.fallback()));
  await page.route("**/api/provider/models", (route) => {
    const { base_url } = route.request().postDataJSON();
    if (!LOCAL.test(base_url)) return route.fallback();
    return route.fulfill({ status: 400, json: { code: "unreachable", error: "the model's server cannot be reached", details: { whose: "model_server" } } });
  });
  // From an empty page, so that the app starts anew also where the test had it open.
  await page.goto("about:blank");
  await page.goto("/#/setup");
  await expect(heading(page)).toBeVisible();
  await ready(page);
}

/** Enters the provider's address in step 1 and goes on to step 2. */
async function byAddress(page: Page, url: string): Promise<void> {
  if (!(await address(page).isVisible())) await button(page, "Enter address").click();
  await address(page).fill(url);
  await button(page, "Continue").click();
  await expect(heading(page)).toHaveText("Models");
}

/** Step 1 with a key typed and the stand-in's address entered, and on to step 2. */
async function toModels(page: Page, at: FakeProvider = api, typed = KEY): Promise<void> {
  await key(page).fill(typed);
  await byAddress(page, at.url);
}

test("first run takes the key, opens step 2 with the one model listed tested, and downloads the voice and the search model before the app opens", async ({ page, request }) => {
  api.models(["tide-1"]);
  const stored = await (await request.get("/api/provider")).json();
  const [listed, asked] = [api.listed.length, api.asked.length];
  const lists = () => api.listed.slice(listed).filter((one) => one.path === "/v1/models");
  await open(page);

  // Step 1 is the key's field, without the rail: nothing can go on yet, and nothing is said of a key.
  await expect(page.locator(".setup-brand")).toHaveText("Cardwave");
  expect(await page.locator(".setup-brand img").evaluate((picture: HTMLImageElement) => picture.complete && picture.naturalWidth > 0)).toBe(true);
  await expect(where(page)).toHaveText("Setup · step 1 of 4");
  await expect(heading(page)).toHaveText("Provider");
  await expect(about(page)).toHaveText("Paste the API key from your AI provider's website. Cardwave finds the provider.");
  await expect(page.locator("#rail")).toBeHidden();
  await expect(page.locator(".setup .fld:visible > label")).toHaveText(["API key"]);
  await expect(button(page, "Continue")).toBeDisabled();
  await expect(page.locator(".setup-step:visible")).toHaveCount(0);
  // Without a key, a program on this computer: This computer's own models first, with no folder yet.
  await button(page, "Use a program on this computer (such as LM Studio or Ollama)").click();
  await expect(says(page, "This computer")).toHaveText("AI model files (.gguf) you have downloaded, run by Cardwave");
  await expect(line(page, "This computer").getByRole("button", { name: "Choose folder" })).toBeVisible();
  await expect(page.getByText(/^No other AI program answers on this computer /)).toBeVisible();
  // A key that begins as no provider's does: the provider is found by its name, or its address entered.
  await key(page).fill(KEY);
  await expect(page.getByText("Cardwave can't tell which provider this key is for. Find the provider by name, or enter its address.")).toBeVisible();
  await expect(button(page, "Find by name")).toHaveAttribute("aria-pressed", "true");
  await expect(button(page, "Continue")).toBeDisabled();
  await button(page, "Enter address").click();
  await expect(page.locator(".setup .fld:visible > label")).toHaveText(["API key", "Address", "Name"]);
  await expect(page.getByLabel("Address", { exact: true })).toBeFocused();

  await toModels(page);
  // Step 2: a line for the key, with whose it is and how it ends, and a line of each kind; the downloads are step 4's.
  await expect(where(page)).toHaveText("Setup · step 2 of 4");
  await expect(about(page)).toHaveText("Your models are ready. Change any of them now or later in Settings.");
  await expect(page.locator(".setup form")).toBeHidden();
  await expect(page.locator(".setup .item-label:visible")).toHaveText(["Provider", "Chat", "Helper model", "Images", "Language the AI writes in"]);
  await expect(says(page, "Provider")).toHaveText(`${host(api)} · ····4f2a`);
  // The list left no choice, so its model is the chat model, unasked, and it answered the small question; by its
  // readable name, which models.dev does not give for it.
  await expect(says(page, "Chat")).toHaveText("Tide 1 · works");
  // The list has no cheap model beside it, so the chat model does the app's own work too.
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");
  await expect(page.getByRole("switch")).toHaveCount(0);
  await expect(confirm(page)).toBeEnabled();
  // In a window 1440 x 720 the step fits without scrolling (the owner: Option B).
  await page.setViewportSize({ width: 1440, height: 720 });
  expect(await confirm(page).evaluate((node) => [...function* () { for (let at: Element | null = node; at; at = at.parentElement) yield at; }()].every((at) => at.scrollHeight <= at.clientHeight || getComputedStyle(at).overflowY === "visible"))).toBe(true);
  expect(await page.evaluate(() => document.scrollingElement!.scrollHeight <= innerHeight)).toBe(true);
  const end = await confirm(page).boundingBox();
  expect(end!.y + end!.height).toBeLessThanOrEqual(720);
  await page.setViewportSize({ width: 1280, height: 720 });
  await expect(change(page)).toBeVisible();
  await expect(retry(page)).toBeHidden();
  await expect(wrong(page)).toHaveCount(0);
  // The list of models once, with the key (beside it the asking whether the address makes pictures).
  expect(lists()).toEqual([{ path: "/v1/models", key: `Bearer ${KEY}` }]);
  expect(api.asked.slice(asked)).toEqual([{ key: `Bearer ${KEY}`, body: { model: "tide-1", messages: [{ role: "user", content: QUESTION }], stream: true } }]);

  // "Back" returns to step 1 as it was; the same address and key are not picked from again.
  await button(page, "Back").click();
  await expect(heading(page)).toHaveText("Provider");
  await expect(key(page)).toHaveValue(KEY);
  await button(page, "Continue").click();
  await expect(says(page, "Chat")).toHaveText("Tide 1 · works");
  // Nothing is stored before the main button is pressed.
  expect(await (await request.get("/api/provider")).json()).toEqual(stored);

  // "Continue" leads to the folder of cards, which is only held until setup ends: nothing is imported yet.
  search.hold();
  await confirm(page).click();
  await expect(heading(page)).toHaveText("Cards");
  await expect(where(page)).toHaveText("Setup · step 3 of 4");
  await expect(about(page)).toHaveText("If you have character card files (PNG or JSON from other apps), Cardwave can bring them in from a folder.");
  // The Documents folder is offered, cut in the middle (whole as its tooltip), taken by "Import from this folder"
  // without the picker; "Change" opens the picker there.
  await expect(says(page, "Cards folder")).toHaveText(/Documents$/);
  const cards = (await says(page, "Cards folder").getAttribute("title")) ?? "";
  writeFileSync(join(cards, "wren.png"), cardFile({ name: "Wren Hollow", first_mes: "The kettle sings." }));
  await expect(button(page, "Skip")).toBeVisible();
  await button(page, "Change the cards folder").click();
  await expect(page.getByRole("dialog", { name: "Folder" }).getByLabel("Folder on this computer")).toHaveValue(cards);
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Folder" })).toBeHidden();
  await expect(says(page, "Cards folder")).toHaveAttribute("title", cards);
  expect((await (await request.get("/api/settings")).json()).card_folder.folder).toBeNull();
  // "Import from this folder" leads to the downloads, which ask first: the search model is chosen at first, the
  // voice is an option, each line without "Change" (the voice is changed in Settings).
  await button(page, "Import from this folder").click();
  await expect(heading(page)).toHaveText("Downloads");
  await expect(where(page)).toHaveText("Setup · step 4 of 4");
  await expect(about(page)).toHaveText("Optional downloads, stored on this computer. Switch off what you don't want.");
  await expect(page.locator(".setup .item-label:visible")).toHaveText(["Search", "Voice"]);
  await expect(says(page, "Search")).toHaveText("Finds characters by what they are about · 320 KB download · recommended");
  await expect(says(page, "Voice")).toHaveText(/ · 320 KB download$/);
  await expect(page.locator(".setup .item:visible").getByRole("button")).toHaveCount(0);
  await expect(page.getByRole("switch", { name: "Download the search model" })).toBeChecked();
  await expect(page.getByRole("switch", { name: "Download the voice" })).not.toBeChecked();
  await expect(button(page, "Download (320 KB)")).toBeEnabled();
  // Both off, the one button opens the app.
  await page.getByRole("switch", { name: "Download the search model" }).click();
  await expect(openApp(page)).toBeVisible();
  // "Back" returns to the folder of cards, and the switches stay as they were.
  await button(page, "Back").click();
  await expect(heading(page)).toHaveText("Cards");
  await button(page, "Import from this folder").click();
  await expect(openApp(page)).toBeVisible();
  await page.getByRole("switch", { name: "Download the search model" }).click();
  await page.getByRole("switch", { name: "Download the voice" }).click();
  // The button's size follows what is on; it starts the downloads, one after the other, and the app may open at any time.
  await button(page, "Download (640 KB)").click();
  await expect(page.getByRole("switch")).toHaveCount(0);
  await expect(button(page, "Back")).toHaveCount(0);
  await expect(about(page)).toHaveText("You can open Cardwave now: the downloads go on, and a notice tells you when they are done.");
  await expect(page.getByText("Your cards come in from the folder once Cardwave opens.")).toBeVisible();
  await expect(state(page, "Search")).toHaveText(/^\d+%$/);
  await expect(state(page, "Voice")).toHaveText("Waiting");
  await expect(openApp(page)).toBeEnabled();
  // A start before they are through and before "Open Cardwave" comes back to them.
  await page.unroute("**/api/provider");
  await page.goto("about:blank");
  await page.goto("/");
  await expect(heading(page)).toHaveText("Downloads");
  await expect(page.locator("#rail")).toBeHidden();
  search.release();
  await expect(state(page, "Voice")).toHaveText("Done");
  await expect(state(page, "Search")).toHaveText("Done");
  await openApp(page).click();
  // It leads into the app, and says so there; the folder's card is imported, which the import panel shows.
  await expect(page).toHaveURL(/#\/chats$/);
  await expect(page.locator("#toast span")).toHaveText("Cardwave is ready.");
  await expect(page.getByRole("status", { name: "Import" }).getByRole("heading")).toHaveText("1 card imported");
  expect((await (await request.get("/api/settings")).json()).card_folder.folder).toBe(cards);
  expect((await (await request.get("/api/cards?q=Wren")).json()).length).toBe(1);
  await expect(page.locator("#rail")).toBeVisible();
  // No more was asked for it: the list once, the question once.
  expect([lists().length, api.asked.length - asked]).toEqual([1, 1]);

  // With a provider and the downloads through, a start without an address shows the chats.
  await page.goto("about:blank");
  await page.goto("/");
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"]);
  await expect(page.locator(".setup")).toHaveCount(0);
  // The tab in view holds the start view, at its address.
  expect(new URL(page.url()).hash).toBe("#/chats");
});

test("a chat model that didn't answer says so in the lead and its line, holds the main button, and goes on after “Try again”", async ({ page }) => {
  api.models(["tide-1"]);
  api.fail(402, "No credit on this key.");
  await open(page);
  await toModels(page);
  await expect(about(page)).toHaveText("The chat model didn't answer. Pick another, or try again.");
  await expect(says(page, "Chat")).toHaveText("Tide 1 · didn't answer");
  // Why, in the app's words for a provider that wants payment.
  await expect(wrong(page)).toContainText("The provider wants payment for this");
  await expect(confirm(page)).toBeDisabled();
  await retry(page).click();
  await expect(says(page, "Chat")).toHaveText("Tide 1 · works");
  await expect(about(page)).toHaveText("Your models are ready. Change any of them now or later in Settings.");
  await expect(confirm(page)).toBeEnabled();
});

/** Holds the server's answer of the picks until the function returned is called. */
async function holdPicks(page: Page): Promise<() => void> {
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route("**/api/provider/picks", async (route) => {
    const response = await route.fetch();
    await held;
    await route.fulfill({ response });
  });
  return release;
}

test("the picks asked before “Back” still count after “Continue” with the same key", async ({ page }) => {
  api.models(["tide-1"]);
  const release = await holdPicks(page);
  await open(page);
  await toModels(page);
  await button(page, "Back").click();
  await button(page, "Continue").click();
  await expect(heading(page)).toHaveText("Models");
  release();
  await expect(says(page, "Chat")).toHaveText("Tide 1 · works");
});

test("a chat model chosen while the picks are on their way stays, and is not also the helper", async ({ page }) => {
  api.models(["reef/big-2", "reef/big-2-mini", "kelp/small-1"]);
  api.next([JSON.stringify({ chat: "reef/big-2", background: "kelp/small-1", images: null })]);
  const release = await holdPicks(page);
  await open(page);
  await toModels(page);
  await button(page, "Choose the chat model").click();
  await pick(page, "Chat model", "kelp/small-1");
  release();
  await expect(says(page, "Chat")).toHaveText("Small 1 · works");
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");
});

test("a helper taken as the chat model while the picks are on their way stays so", async ({ page }) => {
  api.models(["reef/big-2", "reef/big-2-mini", "kelp/small-1"]);
  api.next([JSON.stringify({ chat: "reef/big-2", background: "reef/big-2-mini", images: null })]);
  const release = await holdPicks(page);
  await open(page);
  await toModels(page);
  await button(page, "Choose the chat model").click();
  await pick(page, "Chat model", "kelp/small-1");
  await button(page, "Change the helper model").click();
  // The chat model is ticked and marked in the list, where Enter takes the line: the button takes it.
  await picker(page, "Helper model").getByLabel("Model", { exact: true }).fill("kelp/small-1");
  await picker(page, "Helper model").getByRole("button", { name: "Use this model" }).click();
  release();
  await expect(says(page, "Chat")).toHaveText("Small 1 · works");
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");
});

test("a helper chosen while the picks are on their way that the picks make the chat model is none", async ({ page }) => {
  api.models(["reef/big-2", "reef/big-2-mini", "kelp/small-1"]);
  api.next([JSON.stringify({ chat: "reef/big-2", background: "kelp/small-1", images: null })]);
  const release = await holdPicks(page);
  await open(page);
  await toModels(page);
  await button(page, "Change the helper model").click();
  await pick(page, "Helper model", "reef/big-2");
  release();
  await expect(says(page, "Chat")).toHaveText("Big 2 · works");
  await expect(says(page, "Helper model")).toHaveText("Same as the chat model");
});

test("first run's picks are the chat model's answer among the candidates, each tested, and “Continue” stores the ones chosen", async ({ page }) => {
  api.models(["reef/big-2", "reef/big-2-mini", "kelp/small-1"]);
  // The rules' one chat model picks the background model among the two cheap ones.
  api.next([JSON.stringify({ chat: "reef/big-2", background: "kelp/small-1", images: null })]);
  const asked = api.asked.length;
  await open(page);
  await toModels(page);
  await expect(says(page, "Chat")).toHaveText("Big 2 · works");
  await expect(says(page, "Helper model")).toHaveText("Small 1 · works");
  const models = api.asked.slice(asked).map((question) => question.body.model);
  expect(models[0]).toBe("reef/big-2");
  expect(models.slice(1).sort()).toEqual(["kelp/small-1", "reef/big-2"]);
  await expect(confirm(page)).toBeEnabled();

  // One chosen in the picker stays, whatever chat model is taken after it.
  await button(page, "Change the helper model").click();
  // The picker opens empty, the model in use ticked in its list.
  await expect(picker(page, "Helper model").getByLabel("Model", { exact: true })).toHaveValue("");
  // A line names the model readably, with its ID under it.
  await expect(picker(page, "Helper model").getByRole("option", { name: "Small 1 kelp/small-1" })).toHaveAttribute("aria-selected", "true");
  await pick(page, "Helper model", "reef/big-2-mini");
  await expect(says(page, "Helper model")).toHaveText("Big 2 Mini · works");
  await change(page).click();
  await pick(page, "Chat model", "kelp/small-1");
  await expect(says(page, "Chat")).toHaveText("Small 1 · works");
  await expect(says(page, "Helper model")).toHaveText("Big 2 Mini · works");

  // With the folder of cards shown, "Skip" goes on without it; with nothing to download (the first test downloaded
  // both), into the app at once.
  await confirm(page).click();
  await expect(heading(page)).toHaveText("Cards");
  await button(page, "Skip").click();
  await expect(page).toHaveURL(/#\/chats$/);
  // The settings show what was stored.
  await page.unroute("**/api/provider");
  await page.goto("/#/settings");
  const stated = (name: string) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) }).locator(".item-text > .meta");
  // Each with its provider, here the stand-in by its host.
  await expect(stated("Chat")).toHaveText("kelp/small-1 · A program on this computer");
  await page.goto("/#/settings/advanced");
  await expect(stated("Helper model")).toHaveText(`reef/big-2-mini · A program on this computer · writes summaries, tags and memories`);
});

test("step 1's language is its field alone, at the top right of the form above the key", async ({ page }) => {
  await open(page);
  const field = page.getByRole("button", { name: "Language of the app" });
  await expect(field).toContainText("English");
  await expect(page.getByText("Language of the app", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Taken from this computer at first")).toHaveCount(0);
  const [language, key] = await Promise.all([field.boundingBox(), page.getByLabel("API key", { exact: true }).boundingBox()]);
  expect(language!.y + language!.height).toBeLessThan(key!.y);
  expect(Math.abs(language!.x + language!.width - (key!.x + key!.width))).toBeLessThan(2);
});
