import type { Page } from "@playwright/test";
import { button, composer, expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// The smoke test, before every release and in every run: the app from an empty data folder through first run by
// the provider's address (the stand-in, `api`), a card made, one reply, the server restarted keeping them, then
// each way the provider can fail, what the user is told in the chat (the alert over the message field). Other
// specs pin each failure more closely (20, 21, 66, 84); this one passes through each once, by the stand-in's
// `fail` and `cuts`. "App closed mid-reply" is the server stopped while a reply streams (in the desktop app the
// server runs inside it), and the chat opened again. The tests run one after the other on the one chat.
//
// The servers on this computer the list of providers names may be running, so their models are answered as
// none (`LOCAL`, as in spec 20). The 404 runs last: it marks the model as gone, which later sends would meet.
test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let chat = "";

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** The servers on this computer the list of providers names, by their ports. */
const LOCAL = /^http:\/\/127\.0\.0\.1:(5001|1234|11434)\//;
/** A key that begins as no provider's does, so the provider is found by its address. */
const KEY = "key-smoke-0123456789-7c1e";

const heading = (page: Page) => page.locator(".setup h1");
const texts = (page: Page) => page.locator(".message .text");
const alert = (page: Page) => page.locator(".note").getByRole("alert");

/** Sends `words` in the open chat. */
async function send(page: Page, words: string): Promise<void> {
  await composer(page).fill(words);
  await composer(page).press("Enter");
}

/** Opens the chat from an empty page, as when the app is opened. */
async function openChat(page: Page): Promise<void> {
  await page.goto("about:blank");
  await page.goto(chat);
  await expect(composer(page)).toBeVisible();
}

test("from an empty data folder: first run by the provider's address, a card made, a reply, and all kept over a restart", async ({ page, restartServer }) => {
  await page.route("**/api/provider/models", (route) => (LOCAL.test(route.request().postDataJSON().base_url) ? route.fulfill({ status: 400, json: { code: "unreachable", error: "unreachable", details: { whose: "model_server" } } }) : route.fallback()));
  api.models(["tide-1"]);
  await page.goto("/");
  await expect(heading(page)).toHaveText("Provider");
  await page.getByLabel("API key", { exact: true }).fill(KEY);
  await button(page, "Enter address").click();
  await page.getByLabel("Address").fill(api.url);
  await button(page, "Continue").click();
  await expect(heading(page)).toHaveText("Models");
  // On the release build the picks wait for models.dev's list from its host (the stand-in is debug-only), up to its 20 s.
  await expect(page.locator(".setup .item:visible", { hasText: /^Chat/ }).locator(".item-text > .meta").first()).toHaveText("Tide 1 · works", { timeout: 25_000 });
  await button(page, "Continue").click();
  await expect(heading(page)).toHaveText("Cards");
  await button(page, "Skip").click();
  await expect(heading(page)).toHaveText("Downloads");
  await page.getByRole("switch", { name: "Download the search model" }).click();
  await button(page, "Open Cardwave").click();
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"]);

  // A card: a title and a first message, then a chat with it and one reply.
  await page.goto("/#/library/new");
  await page.getByRole("textbox", { name: "Title", exact: true }).pressSequentially("Wren of Tern Rock");
  await page.getByRole("textbox", { name: "Title", exact: true }).press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  const card = new URL(page.url()).hash;
  await page.locator(".reading section.tb", { has: page.getByRole("heading", { name: "First message", exact: true }) }).locator(".tb-body").click();
  await page.getByRole("textbox", { name: "First message", exact: true }).fill("The lamp is lit.");
  await button(page, "New chat").click();
  await expect(texts(page)).toHaveText(["The lamp is lit."]);
  chat = new URL(page.url()).hash.replace(/^/, "/");
  await send(page, "Hello");
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Hello", "Echo: Hello"]);

  // Closed and opened again on the same data: the chat and the card are there.
  await restartServer();
  await openChat(page);
  await expect(texts(page)).toHaveText(["The lamp is lit.", "Hello", "Echo: Hello"]);
  await page.goto(`/${card}`);
  await expect(page.locator(".crumbs")).toHaveText("Characters/Wren of Tern Rock");
});

/** Each failure of the provider, and what the chat then tells the user. */
const FAILURES: [string, (api: FakeProvider) => void, string][] = [
  ["400 with the provider's text", (api) => api.fail(400, "Unsupported parameter: top_k"), "The provider refused this: Unsupported parameter: top_k."],
  ["500", (api) => api.fail(500, "upstream exploded"), "The provider had a fault on its side: upstream exploded. Try again later."],
  ["the stream cut", (api) => api.cuts("The tide"), "The reply broke off."],
  ["401, the key refused", (api) => api.fail(401, "Invalid API key"), "The provider did not take the key: check it in Settings › Providers."],
];

for (const [name, failing, told] of FAILURES) {
  test(`a reply that fails by ${name} tells the user so`, async ({ page }) => {
    await openChat(page);
    failing(api);
    await send(page, `Again, ${name}`);
    await expect(alert(page)).toHaveText(told);
  });
}

test("the app closed mid-reply keeps the words come so far and says the reply broke off", async ({ page, restartServer }) => {
  await openChat(page);
  const held = api.hold(["Half a", " reply."]);
  await send(page, "Tell me slowly");
  await expect(texts(page).last()).toHaveText("Half a");
  await restartServer();
  held.release();
  await openChat(page);
  await expect(texts(page).last()).toHaveText("Half a");
  await expect(alert(page)).toHaveText("The reply broke off.");
});

test("a reply that fails by 404, the model gone, tells the user so", async ({ page }) => {
  await openChat(page);
  api.fail(404, "The model `tide-1` does not exist");
  await send(page, "Are you there?");
  await expect(alert(page)).toHaveText("The provider no longer offers this model: choose another in Settings › Models.");
});
