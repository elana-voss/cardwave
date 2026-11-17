// The desktop window: what a browser test cannot show, the app's own window
// starting inside the screen's work area, on first run, drawing its own title bar, saving a file, the page "Cardwave's
// CSS" in a window of its own, and the logs' folder told. Run with `npm run test:desktop`; needs tauri-driver and a
// msedgedriver that matches the installed WebView2.
//
// The tests run one after the other in one window, so that a test finds what the one before it left (first
// run left for the account's page "Advanced", the card imported, the page shown).
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { after, before, test } from "node:test";
import { cardFile, readCard } from "../card.ts";
import { Desktop, until } from "./driver.ts";
import { downloadsFolder, placed } from "./screen.ts";

let app: Desktop;

before(async () => {
  app = await Desktop.start();
});
after(() => app?.close());

test("the window opens inside the screen's work area, above the taskbar, and centred in it", () => {
  const { frame: [left, top, right, bottom], area: [areaLeft, areaTop, areaRight, areaBottom] } = placed("Cardwave");
  assert.ok(left >= areaLeft && top >= areaTop && right <= areaRight && bottom <= areaBottom, `window ${[left, top, right, bottom]}, work area ${[areaLeft, areaTop, areaRight, areaBottom]}`);
  assert.ok(Math.abs(left - areaLeft - (areaRight - right)) <= 16, `not centred: ${[left, right]} in ${[areaLeft, areaRight]}`);
});

test("the desktop window opens on first run while no model is set up, and “Enter the provider's address in Settings” leads into the app", async () => {
  // The app runs on its scratch folder: the database is there, with what the
  // window itself stores, and it is empty.
  assert.ok(existsSync(join(app.data, "cardwave.db")), "the database is not in the scratch folder");
  assert.ok(existsSync(join(app.scratch, "webview")), "the window's own storage is not in the scratch folder");
  // So no provider is stored, and the window, which starts without an address, shows first run, without the rail.
  await app.findText("h1", "Provider");
  assert.equal(new URL(await app.url()).hash, "#/setup");
  assert.equal(await app.run<boolean>("return document.querySelector('#rail').hidden"), true);
  await app.click(await app.findText("button", "Enter the provider's address in Settings"));
  await app.findText("button", "Add provider");
  assert.equal(new URL(await app.url()).hash, "#/settings/providers");
  assert.equal(await app.run<boolean>("return document.querySelector('#rail').hidden"), false);
});

test("the window draws its own title bar, whose Maximize fills the work area and gives the size back", async () => {
  assert.equal(await app.run<boolean>("return document.querySelector('#titlebar').hidden"), false);
  const names = await app.run<string[]>("return [...document.querySelectorAll('#titlebar .wc button')].map((one) => one.ariaLabel)");
  assert.deepEqual(names, ["Minimize", "Maximize", "Close"]);
  const width = () => app.run<number>("return window.outerWidth");
  const before = await width();
  await app.click(await app.find("#titlebar .window_maximize"));
  await until("the window maximized", async () => (await width()) > before);
  await app.click(await app.find("#titlebar .window_maximize"));
  await until("the window's size back", async () => (await width()) === before);
});

test("a card imported in the desktop window is exported from its menu, and the file is saved", async () => {
  // The account's page “Advanced” of the test before, with the rail.
  await app.click(await app.find('a[href="#/library"]'));
  await app.findText("span", "No characters yet. Make one, or import a character card (a PNG or JSON file from a card website or another chat app).");

  const card = join(app.scratch, "lamp.png");
  writeFileSync(card, cardFile({ name: "Desk Lamp", description: "A lamp.", first_mes: "Click.", tags: ["desk"] }));
  await app.type(await app.find('input[type="file"]', true), card);
  // One file alone: the notice at the window's foot says that it came.
  await app.findText("span", "“Desk Lamp” imported.");

  await app.hover(await app.find(".card-row"));
  await app.click(await app.find('.card-row button[aria-label="More"]'));
  await app.click(await app.findText("button[@role='menuitem']", "Export as card file"));

  // Saved under the card's name, without a question, and it is the card.
  const saved = join(app.downloads, "Desk Lamp.png");
  await until("the saved file", () => existsSync(saved));
  const written = await until("the whole file", () => readCard(readFileSync(saved)).sillytavern.ccv3);
  assert.equal(written.spec, "chara_card_v3");
  assert.deepEqual(
    { name: written.data.name, description: written.data.description, first_mes: written.data.first_mes, tags: written.data.tags },
    { name: "Desk Lamp", description: "A lamp.", first_mes: "Click.", tags: ["desk"] },
  );
  assert.deepEqual(readdirSync(app.downloads), ["Desk Lamp.png"]);
  // The notice names the folder the window saves into by itself. The file of
  // this test is not there: the driver sent it to the scratch folder.
  assert.equal(await app.text(await app.find("#toast")), `“Desk Lamp” exported to ${downloadsFolder(app)}.`);
});

test("a chat started in the desktop window is exported from its menu, and the file is saved", async () => {
  // The card of the test before, in the library that is still shown.
  await app.hover(await app.find(".card-row"));
  await app.click(await app.findText("li[contains(@class, 'card-row')]//button", "Chat"));
  await app.findText("p", "Click.");
  await app.click(await app.find('button[aria-label="Chat options"]'));
  await app.click(await app.findText("button[@role='menuitem']", "Export"));

  // Saved under the chat's name and its start, without a question: text, a line for the file's head and one for the greeting.
  const named = /^Desk Lamp - \d{4}-\d\d-\d\d@\d\dh\d\dm\d\ds\.jsonl$/;
  const saved = await until("the saved file", () => readdirSync(app.downloads).find((name) => named.test(name)));
  const lines = await until("the whole file", () => {
    const written = readFileSync(join(app.downloads, saved), "utf8").split("\n");
    return written.length === 2 && written.map((line) => JSON.parse(line));
  });
  assert.deepEqual(lines[0], { chat_metadata: {}, user_name: "Guest", character_name: "Desk Lamp" });
  assert.deepEqual([lines[1].name, lines[1].is_user, lines[1].mes, lines[1].swipes], ["Desk Lamp", false, "Click.", ["Click."]]);
  assert.deepEqual(readdirSync(app.downloads).sort(), ["Desk Lamp.png", saved].sort());
  assert.equal(await app.text(await app.find("#toast")), `Chat exported to ${downloadsFolder(app)}.`);
});

test("the dialog's link opens Cardwave's CSS in a window of its own, with its own title bar, and the dialog stays", async () => {
  const [main] = await app.windows();
  await app.go(`${new URL(await app.url()).origin}/#/settings/advanced`);
  await app.click(await app.find('button[aria-label="Edit your own CSS"]'));
  await app.click(await app.findText("button", "Cardwave's CSS"));
  // WebView2's list of downloads, which the exports before opened, is a window too.
  const page = await until("the page Cardwave's CSS in a window", async () => {
    for (const handle of (await app.windows()).filter((handle) => handle !== main)) {
      await app.switchTo(handle);
      if ((await app.url()).endsWith("#/settings/advanced/css")) return handle;
    }
    return null;
  });
  await app.findText("span", "--accent");
  // WebKitWebDriver may answer the click "no such window" when the window it closed goes before the answer.
  await app.click(await app.find("#titlebar .window_close")).catch((error: unknown) => {
    if (!String(error).includes("no such window")) throw error;
  });
  await until("the page's window closed", async () => !(await app.windows()).includes(page));
  await app.switchTo(main!);
  await app.find("dialog[open] textarea");
});

test("only the app's own page is told the folder, not another one the window shows", async () => {
  const told = () => app.run<string | null>("return window.cardwaveDesktop?.downloads ?? null");
  const own = new URL(await app.url());
  assert.equal(await told(), downloadsFolder(app));
  // And the logs' folder, which "About Cardwave" opens, in the app's data folder, with the day's debug log.
  const logs = await app.run<string>("return window.cardwaveDesktop.logs");
  assert.match(logs, /[\\/]data[\\/]logs$/);
  assert.ok(readdirSync(logs).some((name) => /^debug-\d{4}-\d\d-\d\d\.log$/.test(name)), logs);
  // The same server under its other name is another site to the window.
  own.hostname = "localhost";
  await app.go(own.href);
  await app.pageIsThere();
  assert.equal(new URL(await app.url()).hostname, "localhost");
  assert.equal(await told(), null);
});
