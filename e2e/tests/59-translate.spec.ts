import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File } from "../card";

// A card translated: Settings › Language sets the language the AI writes in, which "Translate the character" (the
// card menu's "Translate the character…") offers first; the pretend model translates each text, shown beside the original
// with a banner, undone or kept as a whole; a kept language is in the language bar, the choice remembered per
// card; a text in it offers "Translate from English"; leaving the page stops a translation on its way. The pretend
// model answers every text with its one reply.
// One database for the file, one card per test.
test.describe.configure({ mode: "serial" });

const PERSONALITY = "She is dry and watchful, and she keeps her own counsel at every feast of the court.";
const REPLY = /^This is Cardwave's pretend model\./;

/** A card in English with a description, a personality, a greeting, creator notes and a lorebook of its own. */
async function make(request: APIRequestContext, title: string): Promise<number> {
  const file = ccv4File(`
spec = "ccv4:1.0.0"

[meta-info]
title = ${JSON.stringify(title)}
creator = "Erin"

[name.guin]
text = "Guinivere"

[description.guin]
text = "Guinivere is the queen's sworn sword, and she has guarded the castle for many long years."

[personality.guin]
text = ${JSON.stringify(PERSONALITY)}

[greeting.one]
text = "You are late again, {{user}}. The queen has been waiting for you since the morning."

[creator-note.guin]
text = "This card works best with long replies and a slow story."

[lore.sword]
keywords = ["sword"]
text = "The sword was forged in the north for the first queen."

[lorebook.castle]
entries = ["lore.sword"]

[character.guin]
name-card = "Guinivere"
name-char = "name.guin"
greetings = ["greeting.one"]
creator-note = "creator-note.guin"
lorebooks = ["lorebook.castle"]
prompt = ["name.guin", "description.guin", "personality.guin", "LOREBOOK", "CHAT-HISTORY"]
`);
  const response = await request.post("/api/cards", { data: file });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).card_id;
}

const text = (page: Page, name: string) => page.locator(".reading section.tb", { has: page.getByRole("heading", { name, exact: true }) });
const languages = (page: Page) => page.getByRole("group", { name: "Language" });

/** Opens "Translate the character" from the card menu and starts it into the language it offers first. */
async function translate(page: Page): Promise<void> {
  await page.locator(".hero-acts").getByRole("button", { name: "Character menu" }).click();
  await page.getByRole("menuitem", { name: "Translate the character…" }).click();
  const dialog = page.getByRole("dialog", { name: "Translate the character" });
  await expect(dialog.getByRole("button", { name: "Language" })).toHaveText("German");
  await expect(dialog.getByRole("switch", { name: "Its lorebook too" })).toBeChecked();
  await dialog.getByRole("button", { name: "Translate", exact: true }).click();
}

test.beforeAll(async ({ request }) => {
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status()).toBe(200);
});

test("Settings › Language sets the language the AI writes in", async ({ page, request }) => {
  await page.goto("/#/settings");
  const field = page.getByRole("button", { name: "Language the AI writes in" });
  await expect(field).toBeEnabled();
  await field.click();
  await page.getByRole("menuitemradio", { name: "German" }).click();
  await expect(field).toHaveText("German");
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).language).toBe("de");
});

test("a card is translated beside its texts, undone, then kept as a language of its own", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const card = await make(request, "Protector: translated");
  await page.goto(`/#/library/${card}`);
  await expect(text(page, "Personality")).toContainText(PERSONALITY);
  await expect(languages(page)).toHaveCount(0);

  // Each text shows the original and the translation side by side; Undo all leaves the card as it was.
  await translate(page);
  const banner = page.locator(".reading .banner");
  // The model is asked text by text: with four spec files at a time this can take longer than an expectation's 5 s (seen).
  await expect(banner).toContainText("Translated into German: 4 texts and 1 lorebook entry. Keep the translation, or undo it.", { timeout: 15_000 });
  const sides = text(page, "Personality").locator(".tr > div");
  await expect(sides.locator(".lang")).toHaveText(["English", "German"]);
  await expect(sides.nth(0)).toContainText(PERSONALITY);
  await expect(sides.nth(1).locator("ins")).toHaveText(REPLY);
  await page.getByRole("button", { name: "Undo all" }).click();
  await expect(banner).toHaveCount(0);
  await expect(text(page, "Personality").locator(".tb-body")).toHaveText(PERSONALITY);

  // Keep all: the card is in German too, which shows; English is a press away, and the page remembers it.
  await translate(page);
  await page.getByRole("button", { name: "Keep all changes" }).click();
  await expect(languages(page).locator('[aria-pressed="true"]')).toHaveText("German");
  await expect(text(page, "Personality").locator(".tb-body")).toHaveText(REPLY);
  const edit = await (await request.get(`/api/cards/${card}/edit?language=de`)).json();
  expect(edit.characters[0].creator_notes).toMatch(REPLY);
  await languages(page).getByRole("button", { name: "English" }).click();
  await expect(text(page, "Personality").locator(".tb-body")).toHaveText(PERSONALITY);
  await page.reload();
  await expect(languages(page).locator('[aria-pressed="true"]')).toHaveText("English");
  await expect(text(page, "Personality").locator(".tb-body")).toHaveText(PERSONALITY);

  // A text in German offers "Translate from English", which sends the English words.
  await languages(page).getByRole("button", { name: "German" }).click();
  await expect(text(page, "Personality").locator(".tb-body")).toHaveText(REPLY);
  await text(page, "Personality").hover();
  await page.getByRole("button", { name: "AI tools for Personality" }).click();
  const asked = page.waitForRequest("**/api/rewrite");
  await page.getByRole("menuitem", { name: "Translate from English" }).click();
  expect((await asked).postDataJSON()).toMatchObject({ tool: "translate", given: "German", text: PERSONALITY });
  await expect(text(page, "Personality").locator(".tb-foot .meta")).toHaveText(/^Translated into German · /);
});

test("a translation on its way asks the model no more once the card's page is left", async ({ page, request }) => {
  const card = await make(request, "Protector: left");
  let asked = 0;
  let answer = () => {};
  const held = new Promise<void>((done) => (answer = done));
  await page.route("**/api/rewrite", async (route) => {
    asked += 1;
    await held;
    await route.fallback().catch(() => {});
  });
  await page.goto(`/#/library/${card}`);
  await expect(text(page, "Personality")).toContainText(PERSONALITY);
  await translate(page);
  await expect(page.locator(".reading .banner")).toContainText("Translating into German: 0 of 4 texts");
  // Leaving stops the text being translated, and so the rest.
  const stopped = page.waitForEvent("requestfailed", (one) => one.url().includes("/api/rewrite"));
  await page.goto("/#/library");
  await stopped;
  answer();
  expect(asked).toBe(1);
});

test("a text's own AI tool on its way asks the model no more once the card's page is left", async ({ page, request }) => {
  const card = await make(request, "Protector: tool left");
  let answer = () => {};
  const held = new Promise<void>((done) => (answer = done));
  await page.route("**/api/rewrite", async (route) => {
    await held;
    await route.fallback().catch(() => {});
  });
  await page.goto(`/#/library/${card}`);
  await expect(text(page, "Personality")).toContainText(PERSONALITY);
  await text(page, "Personality").hover();
  await page.getByRole("button", { name: "AI tools for Personality", exact: true }).click();
  const stopped = page.waitForEvent("requestfailed", { predicate: (one) => one.url().includes("/api/rewrite"), timeout: 5000 });
  await page.getByRole("menuitem", { name: "Improve the writing" }).click();
  await expect(text(page, "Personality").locator(".working")).toBeVisible();
  await page.goto("/#/library");
  await stopped;
  answer();
});
