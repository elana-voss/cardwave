import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { NOW, picture, SIZES, stopClock, THEMES } from "../pictures";

// Pictures of the account's screens, each compared with its stored picture, pixel by pixel, at 1440 px in the
// light theme (CLAUDE.md, "Pictures of the screens"): the settings beside the folded rail, the profile with
// the account's menu open, the page Advanced (the group of model presets, without one, over the prompt
// presets and Sampling; with presets it is 38-preset-pictures.spec.ts), the Trash with a row's question, and first run's
// first step with a key that is recognised. The database is this spec's own: a provider with a key, and in
// the Trash a card with its two chats, a chat of two cards, a persona that three chats have and a lorebook.
//
// The pictures are `settings`, `search` (the dialog of the search model, not downloaded; the voice's page is
// spec 48's), `profile`, `advanced`,
// `trash`, `password` (the dialog that switches one on), `start` (the start screen, which the spec has shown by
// answering `GET /api/lock` itself), `server` (Account › Server, whose address and accounts the spec answers
// for, `ACCOUNTS`), `sign-in` (the accounts another device picks from) and `key`. The Trash counts an item's days from
// the page's clock, which is stopped, so the spec answers when each came there (`trashed`: 27, 12, 30 and 30
// days left, in the board's order, which is the order they were put there in, the newest first). First run is
// shown as to a user without a provider (`firstRun`, which answers `GET /api/provider` itself), and with a
// list of providers of the spec's own, in which "OpenRouter" is the stand-in `api` (`known`): the line of the
// key names a provider by its name in the list, and the stand-in's port is another in every run.

/** A key as OpenRouter's begin, and one as no provider's does; each long enough for its end to be told. */
const KEY = "sk-or-v1-0000000000000000";

let api: FakeProvider;

/** The accounts Server and the sign-in screen show, as the spec answers for them: this computer's and one more. */
const ACCOUNTS = [
  { id: 1, name: "local", local: true, current: false, password: true },
  { id: 2, name: "Ada", local: false, current: false, password: true },
];

/** The Trash's items by their titles, with the days each has left. */
const LEFT: Record<string, number> = { "Pell Marsh": 27, Isolde: 12, "Night Porter": 30, Reedmere: 30 };

async function make(request: APIRequestContext): Promise<void> {
  api = await startFakeProvider();
  api.models(["anthropic/claude-haiku-4.5", "anthropic/claude-opus-4.5", "anthropic/claude-sonnet-4.5", "claude-instant", "google/gemini-2.5-pro", "mistral/mistral-large", "openai/gpt-5"]);
  // Stored at an address where nothing listens, which is on no list, with a key whose end is told.
  const provider = await request.put("/api/provider", { data: { base_url: "http://127.0.0.1:1/v1", model: "picture-model", api_key: "sk-picture-key-0000", sampling: { temperature: 1, max_response_length: 800 } } });
  expect(provider.status(), await provider.text()).toBe(200);

  const posted = async (path: string, data: unknown) => {
    const made = await request.post(path, { data });
    expect(made.status(), await made.text()).toBe(201);
    return made.json();
  };
  const card = async (name: string, first_mes: string) => {
    const { card_id } = await posted("/api/cards", cardFile({ name, first_mes }, [300, 450]));
    const { card: made, characters } = await (await request.get(`/api/cards/${card_id}`)).json();
    return { id: card_id as number, of: { version_id: made.version_id as number, character: characters[0].id as string } };
  };
  const trash = async (path: string) => expect((await request.patch(path, { data: { trashed: true } })).status()).toBe(200);
  const [pell, isolde, vale] = [await card("Pell Marsh", "Pell looks up from the nets."), await card("Isolde", '"Mind the reeds, traveller."'), await card("Captain Vale", '"Walk with me."')];
  const persona = await posted("/api/personas", { name: "Night Porter", description: "Keeps the door." });
  // Three chats have the persona, and stay; two are Pell's, and go to the Trash with the card.
  for (const of of [isolde.of, isolde.of, vale.of]) await posted("/api/chats", { characters: [of], persona_id: persona.id });
  for (let n = 0; n < 2; n++) await posted("/api/chats", { characters: [pell.of] });
  const { chat } = await posted("/api/chats", { characters: [isolde.of, vale.of] });
  const world = Buffer.from(JSON.stringify({ entries: { 0: { uid: 0, key: [], comment: "Fog", content: "Fog lies on the mere.", constant: true } } }));
  const { lorebook } = await posted("/api/lorebooks?name=Reedmere.json", world);
  // The newest comes first in the Trash: the lorebook is put there first, the card last.
  await trash(`/api/lorebooks/${lorebook.id}`);
  await trash(`/api/personas/${persona.id}`);
  await trash(`/api/chats/${chat.id}`);
  await trash(`/api/cards/${pell.id}`);
}

test.beforeAll(({ request }) => make(request));
test.afterAll(() => api.close());

/** Has the Trash tell that each item came there as many days before the page's clock as leave it the days of `LEFT`. */
const trashed = (page: Page) =>
  page.route("**/api/trash", async (route) => {
    const told = await route.fetch();
    const trash = await told.json();
    for (const item of trash.items) item.trashed_at = NOW.getTime() - (trash.days - LEFT[item.title]) * 86_400_000;
    await route.fulfill({ response: told, json: trash });
  });

/** The list of providers first run is told: OpenRouter, which is the stand-in, and a program on this computer. */
const known = () => [
  { name: "KoboldCpp", base_url: "http://127.0.0.1:5001/v1", local: true, keys: [] },
  { name: "OpenRouter", base_url: api.url, local: false, keys: ["sk-or-v1-"] },
];

/** Opens first run as of a user who has no provider, with the spec's list of providers. */
async function firstRun(page: Page): Promise<void> {
  await page.route("**/api/provider", (route) => (route.request().method() === "GET" ? route.fulfill({ json: null }) : route.fallback()));
  // A provider kept in the list would open setup at step 2.
  await page.route("**/api/provider-list", async (route) => {
    const response = await route.fetch();
    return route.fulfill({ response, json: { ...(await response.json()), providers: [] } });
  });
  await page.route("**/api/providers", (route) => route.fulfill({ json: known() }));
  await page.goto("/#/setup");
  await expect(page.getByRole("heading", { name: "Provider" })).toBeVisible();
  await expect(page.getByText("No key?")).toBeVisible();
}

const key = (page: Page) => page.getByLabel("API key", { exact: true });
const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;
    /** The pointer leaves for the window's corner, where it points at nothing. */
    const away = (page: Page) => page.mouse.move(width - 2, height - 2);

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the settings: the account's tabs and the groups, beside the folded rail", async ({ page, request }) => {
        // The small pictures another screen asked for are none of this one's business.
        expect((await request.delete("/api/cache")).ok()).toBe(true);
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto("/#/settings");
        await expect(page.getByText("4 items · emptied after 30 days")).toBeVisible();
        await expect(page.getByText("picture-model")).toBeVisible();
        await expect(page.getByText("Not set up")).toHaveCount(4);
        await picture(page, named("settings"));
      });

      test("the dialog of the search model, before it is downloaded", async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto("/#/settings");
        // The account has a provider: the line opens the picker, whose "This computer" opens the dialog.
        await page.getByRole("button", { name: "Set up search" }).click();
        await page.getByRole("dialog", { name: "Search model" }).getByRole("option", { name: /^bge-m3/ }).click();
        await page.getByRole("button", { name: "Use this model" }).click();
        await expect(page.getByRole("dialog", { name: "Search" }).getByText("Not downloaded")).toBeVisible();
        await expect(page.getByRole("button", { name: "Download" })).toBeFocused();
        await picture(page, named("search"));
      });

      test("the profile: the account's letter and name, the group Account, and the account's menu open", async ({ page }) => {
        await page.goto("/#/account/profile");
        await expect(page.locator(".profile-name")).toHaveText("local");
        // With one account what kind it is says nothing: the line under the name is left out.
        await expect(page.locator(".profile-head .meta")).toBeHidden();
        await page.locator(width > 600 ? "#rail" : "#topbar").getByRole("button", { name: "Account: local" }).click();
        await expect(page.getByRole("menuitem", { name: "Profile" })).toBeFocused();
        // The two Isolde chats say their day and time, made on the real clock: masked, so the picture holds.
        await picture(page, named("profile"), [page.locator(".nav-chat", { hasText: "Isolde" })]);
      });

      test("the page Advanced: the groups moved from Settings, Sampling, no preset and the prompt presets", async ({ page, request }) => {
        expect((await request.delete("/api/cache")).ok()).toBe(true);
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto("/#/settings/advanced");
        await expect(page.getByLabel("Temperature")).toHaveValue("1");
        await expect(page.getByLabel("What the AI is told")).toBeEnabled();
        await expect(page.getByLabel("Export format")).toBeEnabled();
        await expect(page.getByRole("switch", { name: "Describe imported characters" })).toBeEnabled();
        await expect(page.getByRole("button", { name: "Change the helper model" })).toBeEnabled();
        await expect(page.locator(".prompt-presets .preset")).not.toHaveCount(0);
        await picture(page, named("advanced"));
      });

      test("the Trash: its rows, and the question of the row whose Delete forever was pressed", async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await trashed(page);
        await page.goto("/#/settings/trash");
        await expect(page.locator(".trash .row .ttl")).toHaveText(["Pell Marsh", "Isolde", "Night Porter", "Reedmere"]);
        await expect(page.locator(".trash .row .left")).toHaveText(["27 days left", "12 days left", "30 days left", "30 days left"]);
        await page.locator(".trash .row", { hasText: "Night Porter" }).getByRole("button", { name: "Delete forever" }).click();
        await expect(button(page, "Cancel")).toBeFocused();
        await away(page);
        await picture(page, named("trash"));
      });

      test("the password's dialog, switching one on, with both fields typed", async ({ page }) => {
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto("/#/account/profile");
        await page.getByRole("button", { name: "Set password" }).click();
        await page.getByLabel("Password", { exact: true }).fill("harbour lights");
        await page.getByLabel("Repeat password").fill("harbour lights");
        await page.getByLabel("Repeat password").blur();
        await picture(page, named("password"));
      });

      test("the start screen, while the app waits for the password", async ({ page }) => {
        await page.route("**/api/lock", (route) => route.fulfill({ json: { locked: true, password: true, name: "local" } }));
        await page.goto("/");
        await expect(page.getByLabel("Password")).toBeFocused();
        await picture(page, named("start"));
      });

      test("Server: the home network reached, at its address, and the accounts", async ({ page }) => {
        await page.route("**/api/network", (route) => route.fulfill({ json: { on: true, address: "http://192.168.1.20:8478/" } }));
        await page.route("**/api/accounts", (route) => route.fulfill({ json: ACCOUNTS.map((one, at) => ({ ...one, current: at === 0 })) }));
        await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
        await page.goto("/#/account/server");
        await expect(page.getByText("http://192.168.1.20:8478/")).toBeVisible();
        await expect(page.getByRole("button", { name: "Switch account" })).toBeVisible();
        await picture(page, named("server"));
      });

      test("the sign-in screen of another device: the accounts to pick from", async ({ page }) => {
        await page.route("**/api/sign-in", (route) => route.fulfill({ json: { needed: true, remote: true, accounts: ACCOUNTS } }));
        await page.goto("/");
        await expect(page.getByRole("heading", { name: "Choose your account" })).toBeVisible();
        await picture(page, named("sign-in"));
      });

      test("first run, step 1: a key that is recognised", async ({ page }) => {
        await firstRun(page);
        await key(page).fill(KEY);
        await expect(page.getByText("Recognised: OpenRouter")).toBeVisible();
        // The key's field has the focus still; its ring is the picture's.
        await picture(page, named("key"));
      });

    });
  }
}
