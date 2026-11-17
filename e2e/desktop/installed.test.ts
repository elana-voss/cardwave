// The installed app, before a release: `tools/installer_test.sh` installs it, runs this file with
// `CARDWAVE_EXE` naming the installed program, and uninstalls it. In its window on a scratch folder of its own
// (never the user's data, which the program keeps elsewhere): first run by the provider's address typed in the
// UI (the browser tests' stand-in, `startFakeProvider`), a card imported, one reply, and the chat kept over a
// restart. As in 09-smoke, but through the installer's program, which is a release build: it reads none of the
// browser tests' stand-ins (`CARDWAVE_PROVIDER_PLACES`, `CARDWAVE_DOCUMENTS`), so first run's "Cards" is skipped
// and the search model's download switched off before it starts.
//
// The servers on this computer the list of providers names (as 09-smoke's `LOCAL`) cannot be answered as none
// here: the model is told by its line ("Tide 1"), the reply by the stand-in's echo. Linux's twin of the script is
// `tools/installer_test_linux.sh`, which has the app's logs kept in `CARDWAVE_KEEP_LOGS`.
import assert from "node:assert/strict";
import { cpSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, test } from "node:test";
import { cardFile } from "../card.ts";
import { startFakeProvider, type FakeProvider } from "../fake-provider.ts";
import { Desktop, until } from "./driver.ts";

const exe = process.env.CARDWAVE_EXE;
/** A key that begins as no provider's does, so the provider is found by its address. */
const KEY = "key-installed-0123456789-4b2d";

let app: Desktop;
let api: FakeProvider;

before(async () => {
  if (!exe) throw new Error("CARDWAVE_EXE names no program: run tools/installer_test.sh");
  api = await startFakeProvider();
  app = await Desktop.start({ exe });
});
after(async () => {
  // tools/installer_test_linux.sh reads in the app's log which feed entry it asks for.
  const keep = process.env.CARDWAVE_KEEP_LOGS;
  if (keep && app) cpSync(join(app.data, "logs"), keep, { recursive: true });
  await app?.close();
  await api?.close();
});

/** The texts of the open chat's messages, oldest first. */
const texts = () => app.run<string[]>("return [...document.querySelectorAll('.message .text')].map((one) => one.textContent.trim())");

/** Waits until the open chat shows exactly these messages. */
const shows = (wanted: string[]) => until(`the messages ${JSON.stringify(wanted)}`, async () => JSON.stringify(await texts()) === JSON.stringify(wanted), 30_000);

test("installed: first run by the provider's address, a card, one reply, and the chat kept over a restart", async () => {
  api.models(["tide-1"]);
  await app.findText("h1", "Provider");
  // tools/installer_test_linux.sh keeps the first screen of the empty data folder as its proof.
  if (process.env.CARDWAVE_SCREENSHOT) await app.screenshot(process.env.CARDWAVE_SCREENSHOT);
  await app.type(await app.find('input[name="api_key"]'), KEY);
  await app.click(await app.findText("button", "Enter address"));
  await app.type(await app.find('input[name="base_url"]'), api.url);
  await app.click(await app.findText("button", "Continue"));
  await app.findText("h1", "Models");
  const chatModel = "return [...document.querySelectorAll('.setup .item')].find((one) => one.offsetParent && /^Chat/.test(one.textContent))?.querySelector('.item-text > .meta')?.textContent.trim()";
  await until("the chat model Tide 1", async () => (await app.run<string>(chatModel)) === "Tide 1 · works");
  await app.click(await app.findText("button", "Continue"));
  await app.findText("h1", "Cards");
  await app.click(await app.findText("button", "Skip"));
  await app.findText("h1", "Downloads");
  await app.click(await app.find('input[role="switch"][aria-label="Download the search model"]'));
  await app.click(await app.findText("button", "Open Cardwave"));

  // A card imported, a chat with it, one reply.
  await app.click(await app.find('a[href="#/library"]'));
  const card = join(app.scratch, "wren.png");
  writeFileSync(card, cardFile({ name: "Wren of Tern Rock", description: "A keeper.", first_mes: "The lamp is lit." }));
  await app.type(await app.find('input[type="file"]', true), card);
  await app.findText("span", "“Wren of Tern Rock” imported.");
  await app.click(await app.find(".card-row a.row-link"));
  await app.click(await app.findText("button", "New chat"));
  await shows(["The lamp is lit."]);
  const chat = new URL(await app.url()).hash;
  await app.type(await app.find("#composer"), "Hello");
  await shows(["The lamp is lit.", "Hello", "Echo: Hello"]);

  // Closed and opened again on the same folder: the chat is there.
  app = await app.restart();
  await app.find("#rail");
  await app.run("location.hash = arguments[0]", chat);
  await shows(["The lamp is lit.", "Hello", "Echo: Hello"]);
  assert.equal(new URL(await app.url()).hash, chat);
});
