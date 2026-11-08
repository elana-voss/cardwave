import { mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeSearch, type FakeSearch } from "../fake-search";
import { HEARD } from "../server.mjs";

// Dictation (the line "Dictation" of Settings › Models, and the microphone of the message field): the model is
// downloaded from the line's dialog, the microphone then shows beside the field, records while pressed and puts
// the words heard at the cursor at the speaker's pause. The model's download is fake-search.ts's, never Whisper's, the server's
// stand-in hears `HEARD`, and the microphone Chromium's fake one, playing `SAID` once: a warbling tone, then silence.

/** Half a second of silence, 1.2 s of a tone that rises and falls as syllables, then silence, at 48 kHz. */
const SAID = join(tmpdir(), "cardwave-e2e", "dictation.wav");
{
  const rate = 48_000;
  const samples = Array.from({ length: rate * 4 }, (_, at) => {
    const t = at / rate;
    return t < 0.5 || t > 1.7 ? 0 : 0.3 * Math.abs(Math.sin(4 * Math.PI * t)) * (Math.sin(2 * Math.PI * 220 * t) + 0.5 * Math.sin(2 * Math.PI * 660 * t));
  });
  const file = Buffer.alloc(44 + samples.length * 2);
  file.write("RIFF", 0);
  file.writeUInt32LE(36 + samples.length * 2, 4);
  file.write("WAVEfmt ", 8);
  file.writeUInt32LE(16, 16);
  file.writeUInt16LE(1, 20);
  file.writeUInt16LE(1, 22);
  file.writeUInt32LE(rate, 24);
  file.writeUInt32LE(rate * 2, 28);
  file.writeUInt16LE(2, 32);
  file.writeUInt16LE(16, 34);
  file.write("data", 36);
  file.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((sample, at) => file.writeInt16LE(Math.round(sample * 32767), 44 + at * 2));
  mkdirSync(join(tmpdir(), "cardwave-e2e"), { recursive: true });
  writeFileSync(SAID, file);
}

test.use({
  launchOptions: { args: ["--use-fake-device-for-media-stream", "--use-fake-ui-for-media-stream", `--use-file-for-fake-audio-capture=${SAID}%noloop`] },
  permissions: ["microphone"],
});

let search: FakeSearch;

test.beforeAll(async () => {
  search = await startFakeSearch();
});
test.afterAll(() => search.close());

const line = (page: Page) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: /^Dictation$/ }) });
const dialog = (page: Page) => page.getByRole("dialog", { name: "Dictation" });

test("dictation's model is downloaded from the settings, and the microphone then writes what was said into the field", async ({ page, request }) => {
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const card = await request.post("/api/cards/new", { data });
  expect(card.status(), await card.text()).toBe(201);
  const chat = await request.post("/api/chats", { data: { characters: [{ version_id: (await card.json()).version_id, character: "mira" }] } });
  expect(chat.status(), await chat.text()).toBe(201);
  const chatId = (await chat.json()).chat.id;

  // Without the model there is no microphone.
  await page.goto(`/#/chats/${chatId}`);
  await expect(page.locator("#composer")).toBeVisible();
  await expect(page.getByRole("button", { name: "Dictate" })).toBeHidden();

  await page.goto("/#/settings");
  await expect(line(page).locator(".meta")).toHaveText("Not set up");
  await page.getByRole("button", { name: "Set up dictation" }).click();
  await expect(dialog(page).locator(".item-text + .meta")).toHaveText("Not downloaded");
  await dialog(page).getByRole("button", { name: "Download" }).click();
  await expect(dialog(page).locator(".item-text + .meta")).toHaveText("Ready");
  await dialog(page).getByRole("button", { name: "Close" }).click();
  await expect(line(page).locator(".meta")).toHaveText("Whisper large-v3-turbo · This computer");

  await page.goto(`/#/chats/${chatId}`);
  await page.locator("#composer").fill("Mira, listen:");
  await page.getByRole("button", { name: "Dictate" }).click();
  // The words come at the pause, while it still records; the silence after is not sent.
  await expect(page.locator("#composer")).toHaveValue(`Mira, listen: ${HEARD}`);
  await page.getByRole("button", { name: "Stop dictating" }).click();
  await expect(page.getByRole("button", { name: "Dictate" })).toBeEnabled();
  await expect(page.locator("#composer")).toHaveValue(`Mira, listen: ${HEARD}`);
});
