// The sweep of every screen (specs 98-sweep-<area>-<language>, each `sweepSpec` of an `AREAS` part, in English or
// German; `openers` opens each part a screen's buttons open): `seed` makes one of everything, `addresses` names every screen of
// web/src/main.ts by its address, `watch` notes each console error and failed request and `settle` waits for
// the page's requests, `look` measures the page as it is: wider than the window, a control outside it, small text
// under contrast 4.5 (WCAG's large text, 24 px or 18.66 px bold, is left out, as are disabled controls), and in
// German an English text of en*.ftl (`english`), but in words marked another `lang`. `sweep` passes a screen through the widths and both themes.
//
// Traps: contrast is computed from the computed styles: the colours through a canvas (so oklch and color-mix are
// read as drawn), the background the first opaque one up the tree, layers and opacity blended; text over a
// picture or gradient is left out. A request the page cancels as it moves on (ERR_ABORTED, WebKit's "Load request cancelled") is no failure. The
// event stream is never "pending". A menu closes when the window changes its size, so `sweep` opens it again. A test written here
// has this file as `info.file`: test.ts keys a spec file's server by the title path.
import { appendFileSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import type { APIRequestContext, Page, Request } from "@playwright/test";
import { expect, test } from "./test";
import { cardFile } from "./card";
import { NOTHING, startFakeProvider, type FakeProvider } from "./fake-provider";
import { setSettings } from "./stored";

export const WIDTHS = [1440, 960, 800, 390] as const;
export type Scheme = "light" | "dark";

/** The single-line texts of a language's .ftl files (`en`, `de`) by their keys, an attribute's as `key.attribute`. */
function ftl(code: string): Map<string, string> {
  const dir = resolve(import.meta.dirname, "../web/src/language");
  const all = new Map<string, string>();
  for (const file of readdirSync(dir).filter((name) => name.startsWith(`${code}.`) && name.endsWith(".ftl"))) {
    let key = "";
    for (const line of readFileSync(join(dir, file), "utf8").split(/\r?\n/)) {
      const term = /^([a-z][\w-]*)\s*=\s*(.*)$/i.exec(line);
      const attribute = /^\s+\.([\w-]+)\s*=\s*(.*)$/.exec(line);
      if (term) key = term[1];
      if (term) all.set(key, term[2].trim());
      else if (attribute && key) all.set(`${key}.${attribute[1]}`, attribute[2].trim());
    }
  }
  return all;
}

/** The texts of en*.ftl a German screen never shows: single-line, with words, and no German text is the same. */
export function english(): Set<string> {
  const de = ftl("de");
  const german = new Set(de.values());
  return new Set([...ftl("en")].filter(([key, text]) => /[a-z]{3}/i.test(text) && !/[{}]/.test(text) && de.get(key) !== text && !german.has(text)).map(([, text]) => text));
}

/** Notes each console error, page error and failed request in `problems`; `settle` waits until no request is open. */
export function watch(page: Page): { problems: string[]; settle: () => Promise<void> } {
  const problems: string[] = [];
  const open = new Set<Request>();
  const counted = (kind: string) => kind !== "eventsource";
  const at = (url: string) => url.replace(/^https?:\/\/[^/]+/, "");
  // WebKit (Linux's window) says it as an error that the viewport's `interactive-widget` (Chromium's, for a phone's
  // keyboard) is unknown to it; it is ignored there as meant (web/src/shell/keyboard.ts), so no failure.
  const harmless = (text: string) => text.includes('"interactive-widget" not recognized');
  page.on("console", (message) => void (message.type() === "error" && !harmless(message.text()) && problems.push(`console: ${message.text().slice(0, 160)}`)));
  page.on("pageerror", (error) => void problems.push(`page error: ${error.message.slice(0, 160)}`));
  page.on("request", (request) => void (counted(request.resourceType()) && open.add(request)));
  page.on("requestfinished", (request) => void open.delete(request));
  page.on("requestfailed", (request) => {
    open.delete(request);
    const why = request.failure()?.errorText ?? "";
    // Chromium's word for a request the page cancelled, and WebKit's.
    if (!why.includes("ERR_ABORTED") && !why.includes("Load request cancelled")) problems.push(`failed: ${request.method()} ${at(request.url())} ${why}`);
  });
  // A request's 4xx or 5xx is noted with what the server said, so its cause is read in the finding.
  page.on("response", (response) => {
    if (response.status() < 400) return;
    const line = `${response.status()}: ${response.request().method()} ${at(response.url())}`;
    void response.text().then((said) => problems.push(`${line} ${said.slice(0, 160)}`), () => problems.push(line));
  });
  const settle = async () => {
    if (open.size) await expect.poll(() => [...open].map((one) => `${one.method()} ${at(one.url())}`), { timeout: 10_000, intervals: [30] }).toEqual([]);
    // Transitions (a panel sliding as the width changes) run to their end; endless ones (a spinner) are left.
    await page.evaluate(() => Promise.race([
      Promise.all(document.getAnimations().filter((one) => one.effect?.getComputedTiming().iterations !== Infinity).map((one) => one.finished.catch(() => null))),
      new Promise((done) => setTimeout(done, 2000)),
    ]).then(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)))));
  };
  return { problems, settle };
}

/** What is wrong with the page as it is now, a line each; `english` only in German. */
export async function look(page: Page, english: string[] | null, part?: string): Promise<string[]> {
  return page.evaluate(([english, part]) => {
    const roots = part ? [...document.querySelectorAll(part)] : [document.body];
    const all = (selector: string) => roots.flatMap((root) => [...root.querySelectorAll(selector)]);
    const W = innerWidth;
    const H = innerHeight;
    const found: string[] = [];
    const shown = (one: Element) => {
      const r = one.getBoundingClientRect();
      return r.width > 1 && r.height > 1 && getComputedStyle(one).visibility !== "hidden";
    };
    const name = (one: Element) => {
      const cls = typeof one.className === "string" && one.className ? `.${one.className.trim().split(/\s+/).slice(0, 2).join(".")}` : "";
      const words = (one.getAttribute("aria-label") || one.textContent || "").trim().replace(/\s+/g, " ").slice(0, 30);
      return `${one.tagName.toLowerCase()}${cls}${words ? ` "${words}"` : ""}`;
    };
    /** Held by an ancestor that scrolls or clips that way and itself ends inside the window. */
    const held = (one: Element, side: "overflowX" | "overflowY") => {
      for (let up = one.parentElement; up && up !== document.body; up = up.parentElement) {
        if (getComputedStyle(up)[side] === "visible") continue;
        const r = up.getBoundingClientRect();
        return side === "overflowX" ? r.right <= W + 1 && r.left >= -1 : r.bottom <= H + 1;
      }
      return false;
    };
    if (document.documentElement.scrollWidth > W) found.push(`page ${document.documentElement.scrollWidth} px wide`);
    const CONTROLS = "button, a[href], input:not([type=hidden]), select, textarea, summary, [role=button], [role=tab], [role=switch], [role=menuitem]";
    for (const one of all(CONTROLS)) {
      if (!shown(one)) continue;
      const r = one.getBoundingClientRect();
      if (getComputedStyle(one).position === "fixed" && r.left >= W) continue;
      const across = (r.right > W + 1 || r.left < -1) && !held(one, "overflowX");
      const down = one.closest("dialog[open], [role=menu]") && r.bottom > H + 1 && !held(one, "overflowY");
      if (across || down) found.push(`outside the window: ${name(one)} at ${Math.round(r.left)}..${Math.round(r.right)}, ${Math.round(r.bottom)}`);
    }
    const paint = document.createElement("canvas").getContext("2d", { willReadFrequently: true })!;
    const rgba = (colour: string) => {
      paint.clearRect(0, 0, 1, 1);
      paint.fillStyle = "#000";
      paint.fillStyle = colour;
      paint.fillRect(0, 0, 1, 1);
      const [r, g, b, a] = paint.getImageData(0, 0, 1, 1).data;
      return [r, g, b, a / 255];
    };
    const over = (top: number[], under: number[]) => [0, 1, 2].map((i) => top[i] * top[3] + under[i] * (1 - top[3])).concat(1);
    const light = (c: number[]) => {
      const [r, g, b] = c.slice(0, 3).map((v) => (v / 255 <= 0.04045 ? v / 255 / 12.92 : ((v / 255 + 0.055) / 1.055) ** 2.4));
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    };
    /** The background drawn under `one`, or null over a picture or gradient. */
    const grounds = new Map<Element, number[] | null>();
    const ground = (one: Element): number[] | null => {
      if (grounds.has(one)) return grounds.get(one)!;
      const layers: number[][] = [];
      for (let up: Element | null = one; up; up = up.parentElement) {
        const style = getComputedStyle(up);
        if (style.backgroundImage !== "none") return null;
        const colour = rgba(style.backgroundColor);
        if (colour[3] > 0) layers.push(colour);
        if (colour[3] >= 1) break;
      }
      const under = layers.reduceRight((under, top) => over(top, under), rgba("Canvas"));
      grounds.set(one, under);
      return under;
    };
    const opacities = new Map<Element, number>();
    const opacity = (one: Element | null): number => {
      if (!one) return 1;
      if (!opacities.has(one)) opacities.set(one, Number(getComputedStyle(one).opacity) * opacity(one.parentElement));
      return opacities.get(one)!;
    };
    for (const one of all("*")) {
      if (english === null && one.closest("svg")) continue;
      const own = [...one.childNodes].filter((node) => node.nodeType === Node.TEXT_NODE).map((node) => node.textContent ?? "").join("").trim().replace(/\s+/g, " ");
      const said = [one.getAttribute("aria-label"), one.getAttribute("title"), one.getAttribute("placeholder")].filter(Boolean) as string[];
      // Words marked as another language than the page's (a language named in its own words) are not the app's.
      const foreign = one.closest("[lang]") !== document.documentElement;
      if (english && !foreign && shown(one)) for (const text of [own, ...said]) if (text && english.includes(text)) found.push(`English in German: "${text.slice(0, 60)}" in ${name(one)}`);
      if (!own || !shown(one) || one.closest("[disabled], [aria-disabled=true], svg")) continue;
      const style = getComputedStyle(one);
      const size = parseFloat(style.fontSize);
      if (size >= 24 || (size >= 18.66 && Number(style.fontWeight) >= 700)) continue;
      const under = ground(one);
      if (!under) continue;
      const seen = opacity(one);
      const text = rgba(style.color);
      if (seen === 0) continue;
      text[3] *= seen;
      const [a, b] = [light(over(text, under)), light(under)];
      const ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
      if (ratio < 4.5) found.push(`contrast ${ratio.toFixed(2)}: ${name(one)}`);
    }
    return [...new Set(found)];
  }, [english, part ?? null] as const);
}

/** The ids `seed` made, for `addresses`. */
export interface Seeded { card: number; chat: number; plain: number; lorebook: number; entry: string }

/**
 * One of everything: a card with its lorebook and its chat, which has a memory (18 messages and one reply the helper remembers
 * from), a document attached and a tool the model wrote; a chat without a character, a lorebook with an entry
 * and a persona. The provider is stored first, so no screen leads to first run.
 */
export async function seed(page: Page, request: APIRequestContext, api: FakeProvider): Promise<Seeded> {
  const ok = async (response: Promise<{ status(): number; json(): Promise<any>; text(): Promise<string> }>) => {
    const done = await response;
    expect(done.status(), await done.text()).toBeLessThan(300);
    return done.json().catch(() => null);
  };
  await ok(request.put("/api/provider", { data: { base_url: api.url, model: "tide-1", api_key: "sk-test", sampling: {} } }));
  api.models(["tide-1", "tide-2"]);
  const mira = await ok(request.post("/api/cards", { data: cardFile({ name: "Mira", first_mes: "The lamp is lit.", character_book: { name: "Lighthouse", entries: [{ keys: ["lamp"], content: "The lamp burns oil.", enabled: true, insertion_order: 0, id: 0 }] } }) }));
  const chat = (await ok(request.post("/api/chats", { data: { characters: [{ version_id: mira.version_id, character: "mira" }] } }))).chat.id;
  const plain = (await ok(request.post("/api/chats", { data: { characters: [] } }))).chat.id;
  const lorebook = (await ok(request.post("/api/lorebooks/new", { data: { name: "Harbour Lore" } }))).id;
  const entry = (await ok(request.post(`/api/lorebooks/${lorebook}/entries`, { data: { name: "Gulls", keywords: ["birds"], content: "They steal chips." } }))).reference;
  await ok(request.post("/api/personas", { data: { name: "Ada", description: "A keeper of the light." } }));
  for (let n = 2; n <= 18; n++) await ok(request.post(`/api/chats/${chat}/messages`, { data: { content: `Message ${n}.` } }));
  await ok(request.put(`/api/chats/${chat}/reply`, { data: { reply_length: 350, code_mode: true } }));

  await page.goto(`/#/chats/${chat}`);
  const composer = page.getByLabel("Message", { exact: true });
  api.remembers("PRESENT: Mira, User\nFACTS:\nuser | sister | The user's sister is called Ana. | personal | Mira | current\nEVENTS:");
  api.calls("make_tool", { name: "word_count", description: "Counts the words of a text.", parameters: { type: "object", properties: { text: { type: "string" } } }, code: "export default function word_count({ text }) {\n  return text.trim().split(/\\s+/).length;\n}" });
  api.calls("word_count", { text: "the lamp is lit" });
  api.next(["It has four words."]);
  await composer.fill("My sister Ana comes tonight. How many words are in “the lamp is lit”?");
  await composer.press("Enter");
  await page.locator(".tool-ask").getByRole("button", { name: "Allow" }).click();
  await expect(page.locator("article.message").last()).toContainText("It has four words.");
  api.remembers(NOTHING);
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("button", { name: "Attach, or let the AI write" }).click();
  await page.getByRole("menuitem", { name: "Attach picture or document", exact: true }).click();
  await (await chooser).setFiles({ name: "Coast notes.txt", mimeType: "text/plain", buffer: Buffer.from("The tide turns at nine.") });
  await expect.poll(async () => JSON.stringify(await (await request.get("/api/memories")).json())).toContain("Ana");
  await expect.poll(async () => JSON.stringify(await (await request.get("/api/documents")).json())).toContain("Coast notes");
  return { card: mira.card_id, chat, plain, lorebook, entry };
}

/**
 * Every screen of web/src/main.ts's `screen`, by a short name; the coding task is the one `taskRoute` answers. Not
 * swept apart: `#/library/3/character/1`, `#/library/3/edit` and `#/library/3/edit/1`, old addresses that open the
 * card's page ("card"), and `#/library/3/lorebook.x`, the card's lorebook page for another of its books.
 */
export const addresses = (ids: Seeded): Record<string, string> => ({
  chats: "/#/chats",
  companion: "/#/companion",
  chat: `/#/chats/${ids.chat}`,
  "chat without a character": `/#/chats/${ids.plain}`,
  "coding task": `/#/chats/${ids.chat}/tasks/7`,
  library: "/#/library",
  card: `/#/library/${ids.card}`,
  "card's lorebook": `/#/library/${ids.card}/lorebook`,
  "new card": "/#/library/new",
  lorebooks: "/#/library/lorebooks",
  lorebook: `/#/library/lorebooks/${ids.lorebook}`,
  "lorebook entry": `/#/library/lorebooks/${ids.lorebook}/${ids.entry}`,
  personas: "/#/library/personas",
  memories: "/#/knowledge/memories",
  documents: "/#/knowledge/documents",
  generator: "/#/generator",
  interview: "/#/interview",
  profile: "/#/account/profile",
  server: "/#/account/server",
  settings: "/#/settings",
  trash: "/#/settings/trash",
  advanced: "/#/settings/advanced",
  providers: "/#/settings/providers",
  "prompt preset": "/#/settings/advanced/prompts/new",
  css: "/#/settings/advanced/css",
  "written tools": "/#/settings/tools/written",
  "coding team": "/#/settings/tools/coding",
  about: "/#/settings/about",
  voices: "/#/settings/voices",
  setup: "/#/setup",
});

/**
 * A coding task needs a team run, which no test has, so the page is answered one task (as spec 53 does): two
 * steps done, the verdict and one changed file.
 */
export async function taskRoute(page: Page, chat: number): Promise<void> {
  const at = "2026-11-16T10:00:00Z";
  const step = (id: number, who: object, what: object, detail: object) => ({ id, who, what, detail, state: "done", output: "", files: [], checkpoint: null, undone: false, started_at: at, ended_at: at });
  const task = {
    id: 7, chat_id: chat, chat_title: "Mira", message_id: 3, goal: "Add an export of chats as Markdown", folder: "C:\Projects\harbour",
    crew: { team: "balanced", workers: 1, audit: "end", planner_model: "tide-1", worker_model: "tide-1", auditor_model: "tide-1", permissions: { read: "allow", write: "allow", commands: "ask", install: "ask", web: "never" } },
    state: "done", planned: 1, verdict: { passed: true, tests_passed: 4, tests_total: 4, failures: [], notes: "" }, error: null, started_at: at, ended_at: at,
    steps: [step(1, { role: "planner" }, { code: "planned", steps: 1 }, { code: "show_plan" }), step(2, { role: "auditor" }, { code: "verdict", passed: true, tests_passed: 4, tests_total: 4 }, { code: "none" })],
    files: [{ path: "src/export/markdown.ts", added: 24, removed: 0, diff: "" }],
    ask: null,
  };
  await page.route("**/api/coding/tasks/7", (route) => route.fulfill({ json: task }));
}

/** `look` at every width and scheme, each finding named by where it was seen; a picture of the first state with one.
 * `open` opens the part again at each width: a width where its button is not there is left out, one where it does
 * not open is a finding. */
export async function sweep(page: Page, settle: () => Promise<void>, english: string[] | null, widths: readonly number[], schemes: readonly Scheme[], open?: () => Promise<Opened>, part?: string): Promise<{ found: string[]; picture?: Buffer }> {
  const found: string[] = [];
  let picture: Buffer | undefined;
  for (const width of widths) {
    await page.setViewportSize({ width, height: 900 });
    const state = open ? await open() : "open";
    if (state === "gone") continue;
    if (state === "shut") {
      found.push(`${width}: did not open`);
      continue;
    }
    await settle();
    for (const colorScheme of schemes) {
      await page.emulateMedia({ colorScheme });
      const seen = await look(page, english, part);
      found.push(...seen.map((line) => `${width} ${colorScheme}: ${line}`));
      if (seen.length && !picture) picture = await page.screenshot();
    }
  }
  return { found, picture };
}

/**
 * What a click must never be tried on in the sweep, at a word's start (not inside a path): it removes data (delete,
 * remove, empty, clear, discard, reset, undo, restore, leave, sign out), sends or asks the provider (send, write again,
 * regenerat, generat, make, continue, describe, retry, test, check, speak, listen, play, try, record), moves a flow on (next,
 * start, allow, deny, switch, quit), or reaches outside (download, install, update, import, export, copy). A label is
 * read to its first ":" or " · ": what follows names the item (a menu's "Provider menu: edit, remove").
 */
const DENY = /(?<![\p{L}/])(delete|remove|send|stop|write again|regenerat|make|try|continue|describe|next|download|restore|empty|sign out|log out|reset|undo|install|update|import|export|record|play|listen|speak|leave|clear|discard|copy|start|retry|test|check|generat|allow|deny|quit|switch)/iu;
const head = (label: string) => label.split(/:| · /)[0];
const escaped = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
/** DENY for a screen in German: also the German of each short English text it names (de.ftl's text of the same key). */
function denies(german: boolean): (label: string) => boolean {
  if (!german) return (label) => DENY.test(head(label));
  const de = ftl("de");
  // A placeable (`{ $name }`) stands for any words: "Try { $name }" is "{ $name } anhören".
  const words = [...ftl("en")].filter(([key, text]) => DENY.test(text) && text.replace(/\{[^}]*\}/g, "").trim().split(/\s+/).length <= 3 && /\p{L}/u.test((de.get(key) ?? "").replace(/\{[^}]*\}/g, ""))).map(([key]) => de.get(key)!.split(/\{[^}]*\}/).map(escaped).join(".+"));
  const also = new RegExp(`(?<!\\p{L})(${words.join("|")})(?!\\p{L})`, "iu");
  return (label) => DENY.test(head(label)) || also.test(head(label));
}
/** What shows that a click opened something: a dialog, a menu, a sheet; else its button now expanded (a panel). */
const WINDOW = "dialog[open], [role=menu], [role=dialog]:not(dialog)";
/** Where a part is: open, not opened by its button (`shut`), or its button not on the screen at this width (`gone`). */
type Opened = "open" | "shut" | "gone";

/**
 * Tries each button of the screen at `address` (in `#view`, and `#titlebar`, `#topbar` when `shell`), but those
 * DENY names (in German also by its German words), and of those named alike the first; each that opens a dialog, menu, sheet or panel is swept as the screen is (`sweep`, opened again at
 * each width, as a menu closes then, by its button found again by its words), and closed by Escape, else by loading the address again.
 * A part is open only where the click made it so: a window shown, or its button `aria-expanded` (the rail's fold button is so on every screen).
 */
export async function openers(page: Page, settle: () => Promise<void>, address: string, english: string[] | null, widths: readonly number[], schemes: readonly Scheme[], shell = false): Promise<{ found: string[]; picture?: Buffer; tried: string[]; denied: string[]; rest: string[] }> {
  const scope = shell ? "#view, #titlebar, #topbar" : "#view";
  const candidates = page.locator(`:is(${scope}) :is(button, summary, [role=button]):visible`);
  // A button is known by its words, else its label: the "Licence" of each row, the "Edit" of each field, open the same
  // part; a line's name (`.row-link`) opens that line's item, the same part for every line of a list.
  const key = (all: Element[]) => all.map((one) => (one.matches(".row-link") ? "a line's name" : ((one.textContent || "").trim() || one.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ")));
  const deny = denies(english !== null);
  const names = await candidates.evaluateAll(key);
  const found: string[] = [];
  let picture: Buffer | undefined;
  const tried: string[] = [];
  const denied = names.filter((label, at) => label && deny(label) && names.indexOf(label) === at);
  // The button of `label` as the screen is now: the topbar comes before #view where the window is narrow.
  const button = async (label: string) => {
    const at = (await candidates.evaluateAll(key)).indexOf(label);
    return at < 0 ? null : candidates.nth(at);
  };
  const windows = page.locator(WINDOW).locator("visible=true");
  const isOpen = async (label: string) => (await windows.count()) > 0 || (await (await button(label))?.getAttribute("aria-expanded")) === "true";
  const back = async (label: string) => {
    for (let n = 0; n < 2 && (await isOpen(label)); n++) await page.keyboard.press("Escape");
    if ((await isOpen(label)) || !page.url().endsWith(address.slice(1))) {
      // A goto to another hash is no load: its screen's requests end before the reload, which would leave them unreported.
      await page.goto(address);
      await settle();
      await page.reload();
    }
    await settle();
  };
  for (const [at, label] of names.entries()) {
    try {
    // A button named as one before it (the "…" of each line of a list) opens the same part: the first stands for all.
    if (!label || deny(label) || names.indexOf(label) < at) continue;
    const open = async (): Promise<Opened> => {
      if (await isOpen(label)) return "open";
      const named = await button(label);
      if (!named) return "gone";
      // Brought into view first, its scroll's event past (it fires at the next frame): a menu that places itself in the
      // window closes when what its button stands in scrolls, so the click's own scrolling would shut it at once.
      await named.scrollIntoViewIfNeeded({ timeout: 2000 }).catch(() => null);
      await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
      await named.click({ timeout: 2000 }).catch(() => null);
      await settle();
      return (await isOpen(label)) ? "open" : "shut";
    };
    await page.setViewportSize({ width: widths[0], height: 900 });
    if ((await isOpen(label)) || (await open()) !== "open") {
      await back(label);
      continue;
    }
    tried.push(label);
    // What opened is measured, and the page's width; a panel (a button expanded) is measured with its screen.
    const part = (await windows.count()) ? WINDOW : undefined;
    const swept = await sweep(page, settle, english, widths, schemes, open, part);
    found.push(...swept.found.map((line) => `"${label}" open: ${line}`));
    picture ??= swept.picture;
    await back(label);
    } catch (error) {
      throw new Error(`the button "${label}": ${error instanceof Error ? error.message : String(error)}`);
    }
  }
  const rest = names.filter((label, at) => names.indexOf(label) === at && !tried.includes(label) && !denied.includes(label));
  return { found, picture, tried, denied, rest };
}

/** The screens of each sweep spec, so each file of them runs near the others' time; together they are `addresses`. */
export const AREAS = {
  chats: ["chats", "companion", "chat", "chat without a character", "coding task", "personas", "memories", "documents", "generator", "interview"],
  library: ["library", "card", "card's lorebook", "new card", "lorebooks", "lorebook", "lorebook entry", "setup", "profile", "server"],
  settings: ["settings", "trash", "advanced", "providers", "prompt preset", "css", "written tools", "coding team", "about", "voices"],
} as const;

/**
 * A sweep spec: one of everything seeded on the file's own server, then each screen named a test, swept at every
 * width in light and dark, with each part its buttons open (`openers`); in German, when `german`, with the English
 * texts of en*.ftl looked for. `#/companion` turns into the list of chats under the window that picks the companion:
 * that window is swept with the screen, the list's buttons are under "chats". A picture is attached only to a screen
 * with a finding. Debug: SWEEP_ONLY=<names,> sweeps only those; SWEEP_OUT=<file> writes the findings (and in
 * `<file>.tried` the buttons whose parts each screen opened, those DENY names and those that opened nothing) instead of failing.
 */
export function sweepSpec(names: readonly string[], german: boolean): void {
  test.describe.configure({ mode: "serial" });
  let api: FakeProvider;
  let ids: Seeded;
  const texts = german ? Array.from(english()) : null;
  test.beforeAll(async ({ browser, request }) => {
    api = await startFakeProvider();
    const page = await browser.newPage();
    ids = await seed(page, request, api);
    await page.close();
    if (german) await setSettings(request, { app_language: "de" });
  });
  test.afterAll(() => api.close());
  test("the buttons the sweep never clicks", () => {
    const deny = denies(german);
    const never = german ? ["Löschen", "Senden", "Neu schreiben", "Weiter", "Eve anhören", "Den Charakter erstellen"] : ["Delete", "Send", "Write again", "Continue", "Next", "Try Eve", "Make the character"];
    const clicked = ["+", "src/export/chat.ts", "Provider menu: edit, remove", "Auditor · checks the work", "Attach"];
    expect([...never.filter((label) => !deny(label)), ...clicked.filter(deny)]).toEqual([]);
  });
  const only = process.env.SWEEP_ONLY?.split(",");
  const out = process.env.SWEEP_OUT;
  for (const name of names) {
    if (only && !only.includes(name)) continue;
    test(`the screen ${name}`, async ({ page }, info) => {
      const { problems, settle } = watch(page);
      await taskRoute(page, ids.chat);
      await page.setViewportSize({ width: 1440, height: 900 });
      await page.goto(addresses(ids)[name]);
      await settle();
      const screen = await sweep(page, settle, texts, WIDTHS, ["light", "dark"]);
      const opened = name === "companion" ? { found: [], tried: [], denied: [], rest: [] } : await openers(page, settle, addresses(ids)[name], texts, WIDTHS, ["light", "dark"], name === "chats");
      const found = [...screen.found, ...opened.found];
      const picture = screen.picture ?? ("picture" in opened ? opened.picture : undefined);
      if (picture) await info.attach(name, { body: picture, contentType: "image/png" });
      if (out) appendFileSync(`${out}.tried`, `${german ? "de " : ""}${name}: ${opened.tried.length} ${JSON.stringify(opened.tried)} denied ${JSON.stringify(opened.denied)} opened nothing ${JSON.stringify(opened.rest)}
`);
      if (out) appendFileSync(out, [...problems, ...found].map((line) => `${german ? "de " : ""}${name}: ${line}
`).join(""));
      else expect([...problems, ...found]).toEqual([]);
    });
  }
}
