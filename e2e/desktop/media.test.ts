// What the app's window does with sound and files, where WebKitGTK differs from a browser: the microphone is
// switched on and granted to the app's own page (desktop/src/microphone.rs), a message is read aloud, and a card
// file dropped on the library imports. Linux only, under Xvfb (`tools/wsl.sh desktop-test`); Windows' WebView2 was
// tried by hand. The voice is the browser tests' stand-in (`CARDWAVE_VOICE_MODEL`, read by a debug build), its
// model the search stand-in's download, which then speaks a tone.
//
// Traps: the run has no microphone (Xvfb, and tools/linux.sh sends it to no sound server), so `getUserMedia` fails,
// but with `NotFoundError` or `OverconstrainedError` (no device) where the window lets the page ask and
// `NotAllowedError` (or no `mediaDevices` at all) where it does not; WebDriver's script waits for no
// promise, so an answer is kept on `window` and polled. The drop is the page's DOM event, as a drop from a file
// manager arrives once GTK has passed it to the page (Tauri's own handler is off); the drag from another program
// is left to a real Linux computer. Whether the sound is heard is too: the page's pieces started are counted.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { after, before, test } from "node:test";
import { cardFile } from "../card.ts";
import { startFakeSearch, type FakeSearch } from "../fake-search.ts";
import { ports, searchModel } from "../server.mjs";
import { Desktop, ELEMENT, WINDOWS, until } from "./driver.ts";

const skip = WINDOWS && "WebKitGTK's; Windows' WebView2 was tried by hand";
let app: Desktop;
let search: FakeSearch;

before(async () => {
  if (skip) return;
  search = await startFakeSearch();
  const model = searchModel();
  const sum = createHash("sha256").update(model).digest("hex");
  process.env.CARDWAVE_VOICE_MODEL = `http://127.0.0.1:${ports(0).search}/model.gguf ${model.length} ${sum}`;
  app = await Desktop.start();
  await app.appPage();
});
after(async () => {
  await app?.close();
  await search?.close();
});

/** Runs `script`, a promise's body, in the page and waits for its answer. */
async function answer<T>(script: string, ...args: unknown[]): Promise<T> {
  await app.run(`window.answered = undefined; Promise.resolve().then(async () => { ${script} }).then((value) => (window.answered = { value }), (error) => (window.answered = { error: String(error) }))`, ...args);
  const got = await until("the page's answer", () => app.run<{ value?: T; error?: string } | null>("return window.answered ?? null"), 30_000);
  if (got.error) throw new Error(got.error);
  return got.value as T;
}

test("the microphone may be asked for in the app's page", { skip }, async () => {
  const asked = await answer<string>("if (!navigator.mediaDevices) return 'no mediaDevices'; try { (await navigator.mediaDevices.getUserMedia({ audio: true })).getTracks().forEach((track) => track.stop()); return 'granted'; } catch (error) { return error.name; }");
  assert.ok(["granted", "NotFoundError", "OverconstrainedError"].includes(asked), `getUserMedia: ${asked}`);
});

test("the window offers the figures WebGPU or WebGL 2", { skip }, async (t) => {
  const offered = await answer<string>("if (navigator.gpu && (await navigator.gpu.requestAdapter())) return 'WebGPU'; return document.createElement('canvas').getContext('webgl2') ? 'WebGL 2' : 'none';");
  t.diagnostic(`figures: ${offered}`);
  assert.notEqual(offered, "none");
});

test("a message is read aloud", { skip }, async () => {
  const origin = new URL(await app.url()).origin;
  await answer("await fetch('/api/voice/download', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' })");
  await until("the voice ready", async () => (await answer<string>("return (await (await fetch('/api/voice')).json()).state")) === "ready", 60_000);
  const chat = await answer<number>(`
    const card = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["${"The storm is coming in from the sea tonight. ".repeat(8)}"], description: "", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
    const post = async (path, data) => (await fetch(path, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(data) })).json();
    const made = await (await fetch("/api/cards/" + (await post("/api/cards/new", card)).card_id)).json();
    return (await post("/api/chats", { characters: [{ version_id: made.card.version_id, character: made.characters[0].id }] })).chat.id;`);
  await app.go(`${origin}/#/chats/${chat}`);
  await app.click(await app.find('article.message button[aria-label="Message options"]'));
  // Each piece of sound the page starts is counted.
  await app.run("window.pieces = 0; const start = AudioBufferSourceNode.prototype.start; AudioBufferSourceNode.prototype.start = function (...args) { window.pieces++; return start.apply(this, args); }");
  await app.click(await app.findText("button", "Read aloud"));
  await until("the pieces played", async () => {
    const said = await app.run<string>("return document.querySelector('#toast')?.textContent ?? ''");
    if (said) throw new Error(`the reading ended: ${said}`);
    return (await app.run<number>("return window.pieces")) >= 2;
  });
  await app.click(await app.find('article.message button[aria-label="Message options"]'));
  await app.click(await app.findText("button", "Stop reading"));
});

test("a card file dropped on the library imports", { skip }, async () => {
  await app.go(`${new URL(await app.url()).origin}/#/library`);
  const field = await app.find('input[type="file"]', true);
  const card = cardFile({ name: "Wren of Tern Rock", description: "A keeper.", first_mes: "The lamp is lit." }).toString("base64");
  await app.run(
    `const place = arguments[0].parentElement;
    const files = new DataTransfer();
    files.items.add(new File([Uint8Array.from(atob(arguments[1]), (char) => char.charCodeAt(0))], "wren.png", { type: "image/png" }));
    place.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: files }));
    place.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: files }));`,
    { [ELEMENT]: field },
    card,
  );
  await app.findText("span", "“Wren of Tern Rock” imported.");
});
