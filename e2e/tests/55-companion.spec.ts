import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, stopClock } from "../pictures";

// The companion window's page (companion.html) in a browser, where it works without the desktop app: a
// double-click on the figure opens the compact chat with the companion's card, whose reply has the animator (the
// stand-in `api`, `moves`) asked what the figure does, as is a throw once the figure stands again (told what the hand did), its standing idle (the page's clock run on) and a reply in its chat sent from elsewhere; the
// companion's interface (`/api/companion/act` and `/state`), each step's state read back; its right-click menu, "Hide until tomorrow" kept in the
// settings; the figure's size set in Settings, which the figure takes at once; that only the app's window, not a browser's page, tells it the screen in view; and that the app's window in a browser has neither "Make companion" nor the settings' line, which
// the desktop app's own test (e2e/desktop/companion.test.ts) drives in the real window. The picture (1440 px, light) is of the compact chat with the menu open; the figure is drawn by WebGL, which no
// picture holds still, so it is hidden for it.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** A card of Gwen, made the companion: its number. */
async function companion(request: APIRequestContext): Promise<number> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const data = { title: "Gwen", tags: [], creator: "", name: "Gwen", greetings: ["Hello."], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const id = (await made.json()).card_id;
  const set = await request.patch("/api/settings", { data: { companion: { card_id: id, starts: true, hidden_until: null } } });
  expect(set.status(), await set.text()).toBe(200);
  return id;
}

/** The companion window's page, once its figure is there. */
async function open(page: Page): Promise<void> {
  await page.goto("/companion.html");
  await expect(page.locator("canvas.companion-figure")).toBeVisible();
}

test("a double-click opens the compact chat with the companion, and its reply has the animator asked what the figure does", async ({ page, request }) => {
  await companion(request);
  api.moves([{ do: "play", clip: "wave" }]);
  await open(page);
  await page.locator("canvas.companion-figure").dblclick();
  const chat = page.getByRole("dialog", { name: "Chat with your companion" });
  await expect(chat.locator(".compact-name")).toHaveText("Gwen");
  await expect(chat.locator(".bubble")).toHaveText(["Hello."]);
  await chat.getByPlaceholder("Message Gwen").fill("Hi there");
  await chat.getByPlaceholder("Message Gwen").press("Enter");
  await expect(chat.locator(".bubble")).toHaveText(["Hello.", "Hi there", "Echo: Hi there"]);
  await expect.poll(() => api.animated.length).toBe(1);
  expect(api.animated[0]!.body.messages[1].content).toContain("Gwen: Echo: Hi there");

  // "Open in Cardwave": the chat in the app, here a tab of its own.
  const [tab] = await Promise.all([page.waitForEvent("popup"), chat.getByRole("button", { name: "Open in Cardwave" }).click()]);
  await expect(tab).toHaveURL(/#\/chats\/\d+$/);
  await tab.close();
  await chat.getByRole("button", { name: "Close" }).click();
  await expect(chat).toBeHidden();
});

test("the companion does what it is told through its interface, and its state says so after each step", async ({ page, request, context }) => {
  await companion(request);
  await open(page);
  const state = async () => (await (await request.get("/api/companion/state")).json()).figure;
  await expect.poll(async () => (await state())?.clip ?? null).not.toBeNull();
  const act = async (steps: unknown[]) => {
    const acted = await request.post("/api/companion/act", { data: { steps } });
    expect(acted.status(), await acted.text()).toBe(200);
    return (await acted.json()).figure;
  };

  const x = (await state()).x - 100;
  expect((await act([{ do: "walk", x }, { do: "say", text: "Over here!" }])).steps[0]).toEqual({ do: "walk", x });
  await expect(page.locator(".companion-say")).toHaveText("Over here!");
  // The window says what its figure does at most each half second.
  await expect.poll(state).toMatchObject({ x, saying: "Over here!" });
  expect((await act([{ do: "react", feeling: "happy" }])).feeling).toBe("happy");
  expect((await act([{ do: "look", x: 10, y: 20 }])).looking).toEqual({ x: 10, y: 20 });
  await act([{ do: "play", clip: "dance", ms: 3000 }]);
  await expect.poll(async () => (await state()).clip).toBe("dance");

  // Cardwave's window says which screen it shows; a browser's page does not (the app's window stood in for).
  const route = async () => (await (await request.get("/api/companion/state")).json()).app?.route;
  const app = await context.newPage();
  await app.addInitScript(() => void (window.cardwaveDesktop = { downloads: "", logs: "", window: "main" }));
  await app.goto("/#/library");
  await expect.poll(route).toBe("#/library");
  const browser = await context.newPage();
  await browser.goto("/#/chats");
  await expect(browser.getByRole("heading", { name: "Chats", exact: true }).first()).toBeVisible();
  await browser.waitForLoadState("networkidle");
  expect(await route()).toBe("#/library");
});

test("the AI steers the figure while it stands idle, and after a reply in the companion's chat in Cardwave's window", async ({ page, request }) => {
  const card = await companion(request);
  api.moves([{ do: "say", text: "Hm, old maps." }]);
  const before = api.animated.length;
  await page.clock.install();
  await open(page);
  // Idle a minute: asked what it does, told it is alone, and it does it.
  // (The figure first lands on the floor; idle counts from then, so the minute is run on until it was asked.)
  await expect(async () => {
    await page.clock.fastForward(61_000);
    await expect.poll(() => api.animated.length, { timeout: 1000 }).toBe(before + 1);
  }).toPass({ timeout: 10_000 });
  expect(api.animated[before]!.body.messages[1].content).toContain("it stands about alone");
  await expect(page.locator(".companion-say")).toHaveText("Hm, old maps.");

  // A reply in its chat, sent from elsewhere (Cardwave's window): asked again, told what was said.
  api.moves([{ do: "play", clip: "nod" }]);
  const shown = await (await request.get(`/api/cards/${card}`)).json();
  const characters = [{ version_id: shown.card.version_id, character: shown.characters[0].id }];
  const { id } = (await (await request.post("/api/chats", { data: { characters } })).json()).chat;
  expect((await request.post(`/api/chats/${id}/messages`, { data: { content: "Look at this map" } })).status()).toBe(201);
  expect((await request.post(`/api/chats/${id}/generate`, { data: {} })).status()).toBe(202);
  await expect.poll(() => api.animated.length).toBe(before + 2);
  expect(api.animated[before + 1]!.body.messages[1].content).toContain("Gwen: Echo: Look at this map");
});

test("once the figure stands again after a throw, the animator is told what the hand did", async ({ page, request }) => {
  await companion(request);
  api.moves([{ do: "play", clip: "no" }]);
  await open(page);
  const figure = page.locator("canvas.companion-figure");
  // Its chat is there once the compact chat has been opened.
  await figure.dblclick();
  const chat = page.getByRole("dialog", { name: "Chat with your companion" });
  await expect(chat.locator(".bubble")).toHaveText(["Hello."]);
  await chat.getByRole("button", { name: "Close" }).click();
  const before = api.animated.length;
  const box = (await figure.boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x - 200, box.y - 300, { steps: 6 });
  await page.mouse.up();
  await expect.poll(() => api.animated.length, { timeout: 10_000 }).toBe(before + 1);
  expect(api.animated[before]!.body.messages[1].content).toContain("The user has just handled the figure: picked it up, threw it");
});

test.describe("at 1440 px, light", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
  test("the figure's menu, and hidden until tomorrow", async ({ page, request }) => {
    const id = await companion(request);
    await stopClock(page);
    await open(page);
    const figure = page.locator("canvas.companion-figure");
    await figure.dblclick();
    await expect(page.getByRole("dialog", { name: "Chat with your companion" }).locator(".bubble")).toHaveText(["Hello."]);
    await figure.click({ button: "right" });
    const menu = page.getByRole("menu");
    await expect(menu.getByRole("menuitem")).toHaveText(["Open chat", "Open Cardwave", "Sit still", "Change character", "Hide until tomorrow", "Close companion"]);
    await figure.evaluate((canvas) => (canvas.style.visibility = "hidden"));
    await picture(page, "companion");
    await figure.evaluate((canvas) => (canvas.style.visibility = ""));

    // Hidden, the window shows nothing until tomorrow, also when it starts anew: it tells the program once that the
    // cursor is on nothing, the cursor's moves ask nothing more of it, and a reply in its chat asks nothing of the
    // animator, as nobody would see the figure move.
    await page.addInitScript(() => {
      const asked: string[] = [];
      Object.assign(window, { asked, __TAURI_INTERNALS__: { invoke: (command: string) => Promise.resolve(void asked.push(command)) } });
    });
    await menu.getByRole("menuitem", { name: "Hide until tomorrow" }).click();
    await expect(figure).toHaveCount(0);
    const tomorrow = await page.evaluate(() => {
      const now = new Date();
      const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
    });
    expect((await (await request.get("/api/settings")).json()).companion.hidden_until).toBe(tomorrow);
    const asked = () => page.evaluate(() => (window as unknown as { asked?: string[] }).asked);
    await expect.poll(asked).toEqual(["window_title", "companion_over"]);
    await page.evaluate(() => [1, 2, 3].forEach((x) => (window as unknown as { companionCursor?: (x: number, y: number) => void }).companionCursor?.(x, x)));
    const animated = api.animated.length;
    const [chat] = await (await request.get(`/api/cards/${id}/chats`)).json();
    await request.post(`/api/chats/${chat.id}/messages`, { data: { content: "Still there?" } });
    expect((await request.post(`/api/chats/${chat.id}/generate`, { data: {} })).status()).toBe(202);
    await expect.poll(async () => (await (await request.get(`/api/chats/${chat.id}`)).json()).messages.at(-1).complete).toBe(true);
    await page.waitForTimeout(300);
    expect(api.animated.length).toBe(animated);
    expect(await asked()).toEqual(["window_title", "companion_over"]);
    await page.reload();
    await expect.poll(asked).toEqual(["window_title", "companion_over"]);
    await expect(page.locator("canvas.companion-figure")).toHaveCount(0);
  });
});

test("the figure picked in Settings is stored, and the companion shows it where its card has none, also when picked anew", async ({ page, request, context }) => {
  await companion(request);
  const figures: string[] = [];
  const other = await context.newPage();
  other.on("request", (asked) => {
    const name = /\/(woman|man|robot)[^/]*\.glb$/.exec(asked.url())?.[1];
    if (name) figures.push(name);
  });
  await open(other);
  await expect.poll(() => figures).toEqual(["woman"]);

  await page.addInitScript(() => void (window.cardwaveDesktop = { downloads: "", logs: "" }));
  await page.goto("/#/settings");
  const line = page.locator(".item", { has: page.locator(".item-label", { hasText: /^Companion figure$/ }) });
  await expect(line.getByRole("button", { name: "Woman" })).toHaveAttribute("aria-pressed", "true");
  await line.getByRole("button", { name: "Man", exact: true }).click();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).companion).toMatchObject({ figure: "man", starts: true });
  await expect.poll(() => figures).toEqual(["woman", "man"]);
  await line.getByRole("button", { name: "Robot" }).click();
  await expect.poll(() => figures).toEqual(["woman", "man", "robot"]);
  // Picked in another window, the line shows it.
  const { companion: stored } = await (await request.get("/api/settings")).json();
  expect((await request.patch("/api/settings", { data: { companion: { ...stored, figure: "woman" } } })).status()).toBe(200);
  await expect(line.getByRole("button", { name: "Woman" })).toHaveAttribute("aria-pressed", "true");
});

test("the size set in Settings is stored, and the companion's figure grows and shrinks with it at once", async ({ page, request, context }) => {
  await companion(request);
  const other = await context.newPage();
  await open(other);
  const canvas = other.locator("canvas.companion-figure");
  // The figure's height is its canvas's 0.62, as a share of the window's height.
  const share = async () => {
    const box = (await canvas.boundingBox())!;
    return Math.round((box.height * 0.62 * 100) / (await other.evaluate(() => innerHeight)));
  };
  await expect.poll(share).toBe(21);

  await page.addInitScript(() => void (window.cardwaveDesktop = { downloads: "", logs: "" }));
  await page.goto("/#/settings");
  const slider = page.getByRole("slider", { name: "Companion size" });
  await expect(slider).toHaveValue("21");
  await slider.fill("40");
  await expect(page.locator(".item", { has: slider })).toContainText("40%");
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).companion).toMatchObject({ size: 40, figure: "woman" });
  await expect.poll(share).toBe(40);
  await slider.fill("10");
  await expect.poll(share).toBe(10);
  // The compact chat still opens beside the figure at its new size.
  await canvas.dblclick();
  await expect(other.getByRole("dialog", { name: "Chat with your companion" })).toBeVisible();
});

test("a browser has neither the settings' line nor the card menu's \"Make companion\"", async ({ page, request }) => {
  const id = await companion(request);
  await page.goto("/#/settings");
  await expect(page.getByText("Chat layout")).toBeVisible();
  await expect(page.getByText("Companion", { exact: true })).toHaveCount(0);
  await page.goto(`/#/library/${id}`);
  await page.getByRole("button", { name: "Character menu" }).click();
  await expect(page.getByRole("menuitem", { name: "Export" })).toBeVisible();
  await expect(page.getByRole("menuitem", { name: "Make companion" })).toHaveCount(0);
});

test("under Retrowave the see-through window draws no neon frame round the screen", async ({ page }) => {
  await page.goto("/companion.html");
  await page.evaluate(() => localStorage.setItem("theme", "retrowave"));
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "retrowave");
  expect(await page.evaluate(() => getComputedStyle(document.body, "::after").content)).toBe("none");
});
