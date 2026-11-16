import type { APIRequestContext, Page } from "@playwright/test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";
import { expect, test } from "../test";

// Run-through "companion and app": a user's path through what frames the app, by clicks and keys alone, each story
// going on from the one before (`serial`). The start, made through `request`: the stand-in `api` (../fake-provider.ts),
// the card North Light with Mira, made the companion by the settings (a browser's window offers no "Make companion",
// 55-companion). The companion window as far as a browser serves it: its page, the compact chat by a double-click, a
// reply, "Open in Cardwave"; About Cardwave from Settings with a licence's text, the logs' line and What's new; the
// rail folded and unfolded, a new tab, Search Cardwave by Ctrl+K opening the character, the tab closed.
// Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (55, 56, 69, 73, 78).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;

const titles = (page: Page) => page.locator("#titlebar .wtab .tt");

test.beforeAll(async ({ request }: { request: APIRequestContext }) => {
  api = await startFakeProvider();
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const set = await request.patch("/api/settings", { data: { companion: { card_id: (await made.json()).card_id, starts: true, hidden_until: null } } });
  expect(set.status(), await set.text()).toBe(200);
});
test.afterAll(() => api.close());

test("the companion's window chats with Mira and opens the chat in Cardwave", async ({ page }) => {
  await page.goto("/companion.html");
  const figure = page.locator("canvas.companion-figure");
  await expect(figure).toBeVisible();
  await figure.dblclick();
  const chat = page.getByRole("dialog", { name: "Chat with your companion" });
  await expect(chat.locator(".compact-name")).toHaveText("Mira");
  await chat.getByPlaceholder("Message Mira").fill("Is the lamp lit?");
  await chat.getByPlaceholder("Message Mira").press("Enter");
  await expect(chat.locator(".bubble")).toHaveText(["You came in the storm.", "Is the lamp lit?", "Echo: Is the lamp lit?"]);
  const [tab] = await Promise.all([page.waitForEvent("popup"), chat.getByRole("button", { name: "Open in Cardwave" }).click()]);
  await expect(tab).toHaveURL(/#\/chats\/\d+$/);
  await expect(tab.locator("article.message").last()).toContainText("Echo: Is the lamp lit?");
  await tab.close();
  await chat.getByRole("button", { name: "Close" }).click();
  await expect(chat).toBeHidden();
});

test("About Cardwave shows the version, a licence's text, where the logs are and what's new", async ({ page, request }) => {
  const { version } = await (await request.get("/api/status")).json();
  await page.goto("/#/settings");
  await page.getByRole("link", { name: /About Cardwave/ }).click();
  await expect(page).toHaveURL(/#\/settings\/about$/);
  await expect(page.locator(".about-head")).toContainText(`Version ${version}`);
  await page.getByRole("button", { name: "Licence of bge-m3" }).click();
  const panel = page.getByRole("dialog", { name: "bge-m3" });
  await expect(panel.locator("pre")).toContainText("Copyright");
  await panel.getByRole("button", { name: "Close" }).click();
  await expect(panel).toHaveCount(0);
  await expect(page.locator(".item").filter({ has: page.getByText("Logs", { exact: true }) })).toContainText("a file a day, kept 7 days");
  const news = page.locator(".settings-group", { has: page.getByRole("heading", { name: "What's new" }) });
  await expect(news).toContainText(/\d+\.\d+\.\d+/);
});

test("the rail folds and unfolds, a new tab finds Mira by Ctrl+K, and closing it leaves the first", async ({ page }) => {
  await page.goto("/#/settings");
  const rail = page.locator("#rail");
  await rail.getByRole("button", { name: "Collapse sidebar" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-rail", "narrow");
  await rail.getByRole("button", { name: "Expand sidebar" }).click();
  await expect(page.locator("body")).toHaveAttribute("data-rail", "wide");

  await page.locator("#titlebar").getByRole("button", { name: "New tab" }).click();
  await expect(titles(page)).toHaveText(["Settings", "Chats"]);
  await page.keyboard.press("Control+k");
  const search = page.getByRole("dialog", { name: "Search Cardwave" });
  await search.getByRole("searchbox", { name: "Search Cardwave" }).fill("mira");
  await expect(search.locator(".hit", { has: page.locator("b", { hasText: /^North Light$/ }) })).toHaveClass(/is-hover/);
  await page.keyboard.press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await expect(search).toBeHidden();
  await expect(titles(page)).toHaveText(["Settings", "North Light"]);
  await page.locator("#titlebar .wtab", { has: page.locator(".tt", { hasText: /^North Light$/ }) }).getByRole("button", { name: "Close tab" }).click();
  await expect(titles(page)).toHaveText(["Settings"]);
  await expect(page).toHaveURL(/#\/settings$/);
});
