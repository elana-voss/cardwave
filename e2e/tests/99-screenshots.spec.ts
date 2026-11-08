import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { APIRequestContext, Locator, Page, Request } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { still, stopClock } from "../pictures";
import { ASHWOOD, CARDS, PERSONA, TURNS } from "../screenshot-cards";
import { setProvider } from "../stored";

// The readme's and the landing site's screenshots, written to docs/screenshots/ (chat, library, card, lorebook,
// companion, and chat-dark for the landing alone), not compared: run only when asked, `SCREENSHOTS=1 npx playwright
// test screenshots` in e2e (playwright.config.ts leaves it out otherwise). The database is this spec's own: the
// twelve cards of ../screenshot-cards.ts, each given its portrait from e2e/portraits/ and described by the fake
// provider's answers so the library shows their pitches and tags, a persona with her picture, a lorebook, and a chat
// whose replies the fake provider writes. The chat shows the character's picture beside it (`chat-portrait`), the
// library is Gallery with the pointer on one tile. The companion's figure (WebGL) stands on the chat's picture, as
// it stands over the app on a desktop. 1440 by 900 px. After a run each picture is looked at, scaled to 720 px,
// before it is committed.

const OUT = fileURLToPath(new URL("../../docs/screenshots/", import.meta.url));
const PORTRAITS = fileURLToPath(new URL("../portraits/", import.meta.url));
const portrait = (name: string) => readFileSync(join(PORTRAITS, `${name}.jpg`));

test.describe.configure({ mode: "serial" });

let provider: FakeProvider;
let nyra = 0;
let chat = 0;
let lorebook = 0;

async function make(request: APIRequestContext): Promise<void> {
  provider = await startFakeProvider();
  const posted = async (path: string, data: unknown) => {
    const made = await request.post(path, { data });
    expect(made.status(), await made.text()).toBe(201);
    return made.json();
  };
  const ids: number[] = [];
  for (const card of CARDS) {
    const { name, creator, tags, description, personality, scenario, first_mes, mes_example, creator_notes } = card;
    const data = { name, creator, tags, description, personality, scenario, first_mes, mes_example, creator_notes, character_version: "1.0" };
    const id = (await posted("/api/cards", cardFile(data))).card_id;
    const pictured = await request.post(`/api/cards/${id}/pictures`, { data: portrait(card.portrait), headers: { "content-type": "image/jpeg" } });
    expect(pictured.ok(), await pictured.text()).toBe(true);
    ids.push(id);
  }
  nyra = ids[0];

  // Each card described in turn: its characters, then its title, logline and summary, then its check.
  const said = (content: unknown) => [JSON.stringify(content)];
  for (const { name, logline, summary, gender, terms } of CARDS) {
    const [frame, engine, archetype] = terms;
    provider.next(said({ ...CLASSIFIED, characters: [{ name, gender, age: "adult" }], frame, frame_display: frame, engine, archetype: [archetype] }));
    provider.next(said({ title: name, logline, summary }));
  }
  for (let at = 0; at < CARDS.length; at++) provider.next(said({ verdict: "classified", reject_reason: "", needs: [] }));
  const set = await setProvider(request, { base_url: provider.url, model: "story-model", api_key: "sk-local", sampling: {} });
  expect(set.status(), await set.text()).toBe(200);
  expect((await request.post("/api/describe", { data: {} })).status()).toBe(200);
  await expect
    .poll(async () => (await (await request.get("/api/cards")).json()).filter((card: { excerpt: string }) => CARDS.some((one) => one.logline === card.excerpt)).length, { timeout: 60_000 })
    .toBe(CARDS.length);
  for (const at of [0, 3, 11]) expect((await request.patch(`/api/cards/${ids[at]}`, { data: { favorite: true } })).status()).toBe(200);

  const rowan = await posted("/api/personas", { name: PERSONA.name, description: PERSONA.description });
  expect((await request.patch(`/api/personas/${rowan.id}`, { data: { is_default: true } })).status()).toBe(200);
  const face = await request.put(`/api/personas/${rowan.id}/picture`, { data: portrait(PERSONA.portrait), headers: { "content-type": "image/jpeg" } });
  expect(face.ok(), await face.text()).toBe(true);
  lorebook = (await posted("/api/lorebooks?name=The%20Ashwood.json", Buffer.from(JSON.stringify(ASHWOOD)))).lorebook.id;

  const started = async (id: number) => {
    const { card, characters } = await (await request.get(`/api/cards/${id}`)).json();
    return (await posted("/api/chats", { characters: [{ version_id: card.version_id, character: characters[0].id }] })).chat.id;
  };
  await started(ids[1]);
  chat = await started(nyra);
  expect((await request.post(`/api/chats/${chat}/lorebooks`, { data: { lorebook_id: lorebook } })).status()).toBe(200);
  for (let at = 0; at < TURNS.length; at += 2) {
    await posted(`/api/chats/${chat}/messages`, { content: TURNS[at] });
    provider.next([TURNS[at + 1]]);
    const made = await request.post(`/api/chats/${chat}/generate`, { data: {} });
    expect(made.status(), await made.text()).toBe(202);
    const { id } = await made.json();
    await expect
      .poll(async () => (await (await request.get(`/api/chats/${chat}`)).json()).messages.find((message: { id: number }) => message.id === id)?.complete)
      .toBe(true);
  }
}

/** What the describing's first call answers of a card, beside its characters and terms. */
const CLASSIFIED = {
  verdict: "classified",
  pairing: "for-any-user",
  multi_mode: false,
  per_greeting: [],
  rating: "sfw",
  content_flags: [],
  mechanism: "asks for help",
};

test.beforeAll(({ request }) => make(request));
test.afterAll(() => provider.close());
test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
test.beforeEach(async ({ page }) => {
  await stopClock(page);
  await page.addInitScript(() => {
    localStorage.setItem("chat-portrait", "on");
    localStorage.setItem("library-view", "gallery");
  });
});

/** Writes the window, once it lies still, to docs/screenshots/<name>.png, the pointer in the window's corner or on `on`. */
async function shoot(page: Page, name: string, on?: Locator): Promise<void> {
  await page.mouse.move(1438, 898);
  await still(page);
  if (on) {
    await on.hover();
    await page.waitForTimeout(400);
  }
  await page.screenshot({ path: join(OUT, `${name}.png`) });
}

/** The chat with Nyra, once both of its readings are in and every picture has come. */
async function openChat(page: Page): Promise<void> {
  let read = 0;
  const counted = (request: Request) => {
    if (request.method() === "GET" && new URL(request.url()).pathname === `/api/chats/${chat}`) read += 1;
  };
  page.on("requestfinished", counted);
  await page.goto(`/#/chats/${chat}`);
  await expect.poll(() => read).toBe(2);
  await expect(page.locator(".message")).toHaveCount(TURNS.length + 1);
  await expect.poll(() => page.locator("img").evaluateAll((all: HTMLImageElement[]) => all.filter((one) => one.getBoundingClientRect().width > 0).every((one) => one.complete && one.naturalWidth > 0))).toBe(true);
}

test("chat", async ({ page }) => {
  await openChat(page);
  await shoot(page, "chat");
});

test("chat-dark", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  await openChat(page);
  await shoot(page, "chat-dark");
});

test("library", async ({ page }) => {
  await page.goto("/#/library");
  await expect(page.locator(".tile")).toHaveCount(CARDS.length);
  await expect.poll(() => page.locator(".tile img").evaluateAll((all: HTMLImageElement[]) => all.every((one) => one.complete && one.naturalWidth > 0))).toBe(true);
  await shoot(page, "library", page.locator(".tile").nth(1));
});

test("card", async ({ page }) => {
  await page.goto(`/#/library/${nyra}`);
  await expect(page.locator(".part").last()).toBeVisible();
  await expect.poll(() => page.locator(".hero-picture img").evaluate((image: HTMLImageElement) => image.complete && image.naturalWidth > 0)).toBe(true);
  await shoot(page, "card");
});

test("lorebook", async ({ page }) => {
  await page.goto(`/#/library/lorebooks/${lorebook}`);
  await expect(page.locator(".entry-form .edit-head h2")).toHaveText("The Frost Court");
  await shoot(page, "lorebook");
});

test("companion", async ({ page, request }) => {
  // The window is see-through on a desktop: here the chat, its side panel closed, stands behind it.
  await page.addInitScript(() => localStorage.setItem("chat-panel", "closed"));
  await openChat(page);
  await page.mouse.move(1438, 898);
  await still(page);
  const behind = (await page.screenshot()).toString("base64");
  const set = await request.patch("/api/settings", { data: { companion: { card_id: nyra, starts: true, hidden_until: null, size: 40 } } });
  expect(set.status(), await set.text()).toBe(200);
  await page.goto("/companion.html");
  const figure = page.locator("canvas.companion-figure");
  await expect(figure).toBeVisible();
  await page.addStyleTag({ content: `html, body { background: url("data:image/png;base64,${behind}") top left / 1440px 900px no-repeat !important; }` });
  await figure.dblclick();
  await expect(page.getByRole("dialog", { name: "Chat with your companion" }).locator(".bubble").first()).toBeVisible();
  await page.mouse.move(1438, 898);
  // The figure moves by itself (WebGL), so the window is taken once its chat has settled, not once it lies still.
  await page.waitForTimeout(1500);
  await page.screenshot({ path: join(OUT, "companion.png") });
});
