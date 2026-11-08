import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeSearch, type FakeSearch } from "../fake-search";
import { picture, stopClock } from "../pictures";

// Voice: the settings' line "Voice" leads to Settings › Voices, where the voice model is downloaded (Download,
// Cancel), a voice tried and chosen, a voice made from a file chosen, renamed and deleted, the speed set, a
// character given a voice and a language downloaded and removed; a message is read aloud from its menu, a
// sentence at a time, which says "Stop reading" while it plays. Every download is the stand-in's file of
// fake-search.ts and a tone of a tenth of a second a word speaks (`CARDWAVE_VOICE_MODEL` in server.mjs), never
// Pocket TTS; the page plays it in Chromium without a sound card, and decodes the WAV file the test makes.

let search: FakeSearch;

test.beforeAll(async () => {
  search = await startFakeSearch();
});
test.afterAll(() => search.close());

const line = (page: Page) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: /^Voice$/ }) });
/** What the page's grey box of the voice model says of its state. */
// The voice model's state, at the right of its box beside its button.
const state = (page: Page) => page.locator(".voices .group .ai-c > .meta");
// Before a download its box says no state and holds "Download" at the line's right.
const notDownloaded = async (page: Page) => {
  await expect(state(page)).toHaveText("");
  await expect(page.locator(".voices .group").getByRole("button", { name: "Download", exact: true })).toBeVisible();
};
/** A line of the page by its name. */
const named = (page: Page, name: string) => page.locator(".voices .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });

/** A card of Mira, its number, its version's and its character's. */
async function card(request: APIRequestContext, greeting = "Hello."): Promise<{ card_id: number; version_id: number; character: number }> {
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: [greeting], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  return { card_id: card.card.id, version_id: card.card.version_id, character: card.characters[0].id };
}

/** A chat whose greeting is long enough to be read for seconds, its number and its card's. */
async function chat(request: APIRequestContext): Promise<{ chat: number; card: number }> {
  const made = await card(request, `*She looks up from the lamp.* ${"The storm is coming in from the sea tonight. ".repeat(8)}`);
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: made.version_id, character: made.character }] } });
  expect(started.status(), await started.text()).toBe(201);
  return { chat: (await started.json()).chat.id, card: made.card_id };
}

/** The voice model downloaded, as the page's Download does. */
async function ready(request: APIRequestContext): Promise<void> {
  await request.post("/api/voice/download", { data: {} });
  await expect.poll(async () => (await (await request.get("/api/voice")).json()).state).toBe("ready");
}

/** A WAV file of four seconds of a tone, 16-bit, one channel at 24,000 a second. */
function recording(): Buffer {
  const count = 4 * 24_000;
  const file = Buffer.alloc(44 + count * 2);
  file.write("RIFF", 0);
  file.writeUInt32LE(36 + count * 2, 4);
  file.write("WAVEfmt ", 8);
  file.writeUInt32LE(16, 16);
  file.writeUInt16LE(1, 20);
  file.writeUInt16LE(1, 22);
  file.writeUInt32LE(24_000, 24);
  file.writeUInt32LE(48_000, 28);
  file.writeUInt16LE(2, 32);
  file.writeUInt16LE(16, 34);
  file.write("data", 36);
  file.writeUInt32LE(count * 2, 40);
  for (let at = 0; at < count; at++) file.writeInt16LE(Math.round(Math.sin((at * 300 * 2 * Math.PI) / 24_000) * 9000), 44 + at * 2);
  return file;
}

test("without a voice or dictation's model downloaded, a chat shows no voice control: no microphone, no Read aloud", async ({ page, request }) => {
  expect((await (await request.get("/api/voice")).json()).state).not.toBe("ready");
  const { chat: id } = await chat(request);
  await page.goto(`/#/chats/${id}`);
  await expect(page.locator("#composer")).toBeVisible();
  await expect(page.getByRole("button", { name: "Dictate" })).toBeHidden();
  const message = page.locator("article.message").first();
  await message.getByRole("button", { name: "Message options" }).click();
  await expect(page.getByRole("menuitem", { name: "Copy" })).toBeVisible();
  await expect(page.getByRole("menuitem", { name: /Read aloud|Stop reading/ })).toHaveCount(0);
  await page.keyboard.press("Escape");
});

test("the voice is downloaded and chosen on the page Voices, and a message is read aloud from its menu a sentence at a time", async ({ page, request }) => {
  await page.goto("/#/settings");
  await expect(line(page).locator(".meta")).toHaveText("Not set up");

  // Nothing is downloaded before "Download"; "Cancel" stops a download.
  await page.getByRole("button", { name: "Set up voice" }).click();
  await expect(page).toHaveURL(/#\/settings\/voices$/);
  await notDownloaded(page);
  await expect(page.getByRole("button", { name: "Try Alba" })).toBeDisabled();
  search.hold();
  await page.getByRole("button", { name: "Download", exact: true }).click();
  await expect(state(page)).toHaveText(/^\d+%$/);
  await page.getByRole("button", { name: "Cancel", exact: true }).click();
  search.release();
  await notDownloaded(page);

  await page.getByRole("button", { name: "Download", exact: true }).click();
  await expect(state(page)).toHaveCount(0);
  // A sample is read in the voice of its line, a sentence at a time, and stopped by its button.
  const sample = page.waitForRequest("**/api/voice/speak");
  await page.getByRole("button", { name: "Try Marius" }).click();
  expect((await sample).postDataJSON()).toEqual({ text: "Hello, I'm Marius.", voice: "marius" });
  await page.getByRole("button", { name: "Stop Marius" }).click();
  await expect(page.getByRole("button", { name: "Try Marius" })).toBeVisible();
  await page.getByRole("radio", { name: "Default voice: Marius" }).check();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).voice).toBe("marius");
  await page.getByRole("navigation", { name: "Where you are" }).getByRole("link", { name: "Settings" }).click();
  await expect(line(page).locator(".meta")).toHaveText("Marius · English");

  // A message is read without its narration's asterisks, a sentence at a time, in its character's voice, until it is stopped.
  const { chat: id, card: mira } = await chat(request);
  await page.goto(`/#/chats/${id}`);
  const message = page.locator("article.message").first();
  await message.getByRole("button", { name: "Message options" }).click();
  const read = page.waitForRequest("**/api/voice/speak");
  await page.getByRole("menuitem", { name: "Read aloud" }).click();
  expect((await read).postDataJSON()).toEqual({ text: "She looks up from the lamp.", card: mira });
  await message.getByRole("button", { name: "Message options" }).click();
  await page.getByRole("menuitem", { name: "Stop reading" }).click();
  await message.getByRole("button", { name: "Message options" }).click();
  await expect(page.getByRole("menuitem", { name: "Read aloud" })).toBeVisible();
});

test.describe("the page Voices", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });

  test("a voice is made from a file, a character given a voice, the speed set and a language downloaded", async ({ page, request }) => {
    await ready(request);
    await card(request);
    // The first voice the account's, as without the test before.
    expect((await request.patch("/api/settings", { data: { voice: "alba" } })).status()).toBe(200);
    await stopClock(page);
    // The rail narrow, without the chats the test before may have made.
    await page.addInitScript(() => localStorage.setItem("rail", "narrow"));
    await page.goto("/#/settings/voices");

    // A voice made from a file chosen, which reads as the others.
    await page.getByRole("button", { name: "Make a voice from a recording" }).click();
    const making = page.getByRole("dialog", { name: "Make a voice from a recording" });
    await expect(making.getByRole("button", { name: "Make voice" })).toBeDisabled();
    await making.getByLabel("Name").fill("Evening");
    await making.locator("input[type=file]").setInputFiles({ name: "me.wav", mimeType: "audio/wav", buffer: recording() });
    await expect(making.locator(".recording-time")).toHaveText("0:04");
    await making.getByRole("button", { name: "Make voice" }).click();
    await expect(page.locator("dialog")).toHaveCount(0);
    await expect(named(page, "Evening").locator(".meta")).toHaveText("Made from your recording");

    // Mira reads in Marius's voice.
    await page.getByRole("button", { name: "Set a voice for a character" }).click();
    const setting = page.getByRole("dialog", { name: "Set a voice for a character" });
    await setting.locator("#voice-character").click();
    await page.getByRole("menuitemradio", { name: "Mira · North Light" }).first().click();
    await setting.locator("#voice-voice").click();
    await page.getByRole("menuitemradio", { name: "Marius" }).click();
    await setting.getByRole("button", { name: "Save" }).click();
    await expect(page.getByRole("button", { name: "Voice of Mira" })).toHaveText("Marius");

    // The speed, stored when let go.
    await page.getByRole("slider", { name: "Speed" }).fill("1.5");
    await expect(page.locator(".lv-val")).toHaveText("1.5×");
    await expect.poll(async () => (await (await request.get("/api/settings")).json()).voice_speed).toBe(150);
    await page.getByRole("slider", { name: "Speed" }).fill("1");

    // German, downloaded when picked.
    await expect(named(page, "German").locator(".meta")).toHaveText(/ download$/);
    await page.getByRole("button", { name: "Download German" }).click();
    await expect(named(page, "German").locator(".meta")).toHaveText(/^Downloaded · /);
    await expect.poll(async () => (await (await request.get("/api/settings")).json()).voice_speed).toBe(100);

    await page.mouse.move(0, 0);
    // From the page's top, where the button pressed last scrolled it away.
    await page.evaluate(() => document.querySelectorAll(".voices, .voices *").forEach((one) => (one.scrollTop = 0)));
    await picture(page, "voices-1440-light");

    await page.getByRole("button", { name: "Delete German" }).click();
    await expect(named(page, "German").locator(".meta")).toHaveText(/ download$/);
    await named(page, "Mira").hover();
    await page.getByRole("button", { name: "Back to the default voice" }).click();
    await expect(named(page, "Mira")).toHaveCount(0);

    // Renamed, then deleted.
    await page.getByRole("button", { name: "Voice menu: rename, delete" }).click();
    await page.getByRole("menuitem", { name: "Rename" }).click();
    await page.getByRole("dialog", { name: "Rename voice" }).getByLabel("Name").fill("Morning");
    await page.getByRole("button", { name: "Save" }).click();
    await expect(named(page, "Morning")).toHaveCount(1);
    await page.getByRole("button", { name: "Voice menu: rename, delete" }).click();
    await page.getByRole("menuitem", { name: "Delete" }).click();
    await page.getByRole("button", { name: "Delete", exact: true }).click();
    await expect(named(page, "Morning")).toHaveCount(0);
  });
});
