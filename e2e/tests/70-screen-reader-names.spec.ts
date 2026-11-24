import type { Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { NOTHING, startFakeProvider, type FakeProvider } from "../fake-provider";
import { setSettings } from "../stored";

// Every control has a name a screen reader says: a test per screen finds none unnamed on it, and none in the
// menus and windows its buttons open (`opens`). What counts is the page's accessibility tree as Playwright reads
// it (`ariaSnapshot`, which names a control as a browser does: its label, its aria-label, its words, a field's
// placeholder), so only what shows is asked; a control of the kinds in `CONTROLS` without a name is a line
// without one (`- button`, `- textbox: words`), told with the lines above it. The database is the file's own: a
// card Mira with her lorebook, a chat with her of 20 messages and a memory, a document, a library lorebook, a
// persona and a card in the Trash. The start screen, the sign-in screen, a coding task, the coding team's tasks
// and the tools the model wrote are answered by `page.route`, as in their own specs. An opener is pressed, the
// check made while its menu or window shows, and Escape closes it again. Words stand out from what is under them
// at 4.5 to 1 at least (WCAG AA), in Retrowave the account's letter in its marked line (`contrast` reads the
// colours as drawn, a see-through background laid over what is under it); Light's and Dark's are the design system's.

let provider: FakeProvider;
let card = 0;
let chat = 0;

const CONTROLS = "button|link|textbox|searchbox|checkbox|switch|radio|combobox|slider|spinbutton|menuitem|menuitemradio|menuitemcheckbox|tab|option|listbox";
/** A control's line without a name: its role, perhaps its states in brackets, perhaps a colon and its value. */
const UNNAMED = new RegExp(`^\\s*- (${CONTROLS})((?: \\[[^\\]]*\\])*)(:.*)?$`);

/** Expects no unnamed control on the page, the lines of any found told with the three lines above each. */
async function allNamed(page: Page): Promise<void> {
  const lines = (await page.locator("body").ariaSnapshot()).split("\n");
  const found = lines.flatMap((line, at) => (UNNAMED.test(line) ? [[...lines.slice(Math.max(0, at - 3), at), `>> ${line}`].join("\n")] : []));
  expect(found, "controls without a name").toEqual([]);
}

/** Presses each opener in turn, checks the page while the window it opened shows, or while it says it is open, and closes it with Escape. */
async function opens(page: Page, ...openers: Locator[]): Promise<void> {
  const windows = page.locator("dialog[open]");
  for (const opener of openers) {
    await opener.click();
    const open = windows.or(opener.and(page.locator("[aria-expanded=true]")));
    await expect(open.first(), `${opener} opens`).toBeVisible();
    await allNamed(page);
    await page.keyboard.press("Escape");
    await expect(open).toHaveCount(0);
  }
}

/** Opens `address`, waits for `shown`, and checks the screen. */
async function screen(page: Page, address: string, shown: (page: Page) => Locator): Promise<void> {
  await page.goto(address);
  await expect(shown(page).first()).toBeVisible();
  await allNamed(page);
}

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true }).first();

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  expect((await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } })).status()).toBe(200);
  const book = { name: "Lighthouse", entries: [{ keys: ["lamp"], content: "The lamp burns oil.", enabled: true, insertion_order: 0, id: 0 }] };
  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", description: "Keeper of the lighthouse.", first_mes: "The lamp is lit.", character_book: book }, [300, 450]) });
  expect(made.status(), await made.text()).toBe(201);
  const { card_id, version_id } = await made.json();
  card = card_id;
  const started = await request.post("/api/chats", { data: { characters: [{ version_id, character: "mira" }] } });
  expect(started.status(), await started.text()).toBe(201);
  chat = (await started.json()).chat.id;
  for (let n = 2; n <= 19; n++) {
    expect((await request.post(`/api/chats/${chat}/messages`, { data: { content: `Is the lamp lit? (${n})` } })).status()).toBe(201);
  }
  provider.remembers("PRESENT: Mira, User\nFACTS:\nlamp | fuel | The lamp burns oil. | world | everyone | current\nEVENTS:");
  expect((await request.post(`/api/chats/${chat}/generate`, { data: {} })).status()).toBe(202);
  await expect.poll(async () => (await (await request.get("/api/memories")).json()).length).toBe(1);
  provider.remembers(NOTHING);
  expect((await request.post(`/api/chats/${chat}/documents?name=Log.txt`, { data: Buffer.from("The lamp was lit at dusk.") })).status()).toBe(201);
  const world = JSON.stringify({ description: "Coast", entries: { 0: { uid: 0, key: ["tide"], comment: "Tides", content: "The tide is high.", constant: false } } });
  expect((await request.post("/api/lorebooks?name=Coast.json", { data: Buffer.from(world) })).status()).toBe(201);
  const other = await request.post("/api/cards", { data: cardFile({ name: "Odd", first_mes: "Hm." }) });
  expect((await request.patch(`/api/cards/${(await other.json()).card_id}`, { data: { trashed: true } })).status()).toBe(200);
  expect((await request.post("/api/personas", { data: { name: "Wanderer", description: "A traveller." } })).status()).toBe(201);
});
test.afterAll(() => provider.close());

test("Chats", async ({ page }) => {
  await screen(page, "/#/chats", (p) => p.getByRole("main").getByText("Mira"));
  await opens(page, button(page, "Sort"), button(page, "More"));
});

test("A chat", async ({ page }) => {
  await screen(page, `/#/chats/${chat}`, (p) => p.getByText("Is the lamp lit?"));
  await opens(page, button(page, "Chat options"), button(page, "Attach, or let the AI write"), button(page, "Message options"), button(page, "Persona"));
});

test("Characters", async ({ page }) => {
  await screen(page, "/#/library", (p) => button(p, "Continue chat"));
  await opens(page, button(page, "Sort and filter"), button(page, "More"));
});

test("A card's page", async ({ page }) => {
  await screen(page, `/#/library/${card}`, (p) => button(p, "Character menu"));
  await opens(page, button(page, "Character menu"), button(page, "Earlier pictures"), button(page, "AI tools for Description"));
});

test("A new card", async ({ page }) => {
  await screen(page, "/#/library/new", (p) => p.getByRole("textbox", { name: "Title" }));
  await opens(page, button(page, "Character menu"));
  await button(page, "More texts").click();
  await expect(page.getByRole("region", { name: "Scenario" })).toBeVisible();
  await allNamed(page);
  // A text is written where it stands: a click shows its field.
  await page.getByText("Empty · where and when the chat begins").click();
  await expect(page.getByRole("region", { name: "Scenario" }).getByRole("textbox")).toBeFocused();
  await allNamed(page);
});

test("Lorebooks", async ({ page }) => {
  await screen(page, "/#/library/lorebooks", (p) => p.getByRole("link", { name: "Coast" }));
  await opens(page, button(page, "More"));
});

test("A lorebook's editor", async ({ page }) => {
  await screen(page, `/#/library/${card}/lorebook`, (p) => p.getByRole("textbox", { name: "Keywords" }));
  await opens(page, button(page, "Lorebook settings"), button(page, "AI tools for the lorebook"), button(page, "Entry menu"));
});

test("Personas", async ({ page }) => {
  await screen(page, "/#/library/personas", (p) => p.getByText("Wanderer"));
  await opens(page, button(page, "More"));
  await button(page, "Edit").click();
  await expect(page.getByRole("textbox", { name: "Name" })).toBeVisible();
  await allNamed(page);
});

test("Memories", async ({ page }) => {
  await screen(page, "/#/knowledge/memories", (p) => p.getByText("The lamp burns oil."));
  await opens(page, button(page, "More"));
});

test("Documents", async ({ page }) => {
  await screen(page, "/#/knowledge/documents", (p) => p.getByText("Log", { exact: true }));
  await opens(page, button(page, "More"));
});

test("Profile", async ({ page }) => {
  await screen(page, "/#/account/profile", (p) => button(p, "Change the name"));
  await opens(page, button(page, "Set password"));
});

test("Sharing", async ({ page }) => {
  await screen(page, "/#/account/server", (p) => button(p, "Add account"));
  await opens(page, button(page, "Add account"));
});

test("Settings", async ({ page }) => {
  await screen(page, "/#/settings", (p) => button(p, "Save backup"));
  await opens(page, button(page, "Language the AI writes in"), button(page, "Change the chat model"), button(page, "Set up voice"), button(page, "Set up search"), button(page, "Save backup"));
});

test("Trash", async ({ page }) => {
  await screen(page, "/#/settings/trash", (p) => button(p, "Restore"));
});

test("Advanced", async ({ page }) => {
  await screen(page, "/#/settings/advanced", (p) => p.getByRole("textbox", { name: "Temperature" }));
  await opens(page, button(page, "New preset"), button(page, "More"), button(page, "Change folder"));
});

test("A prompt preset", async ({ page }) => {
  await screen(page, "/#/settings/advanced/prompts/new", (p) => p.getByRole("textbox", { name: "System prompt" }));
});

test("Providers", async ({ page }) => {
  await screen(page, "/#/settings/providers", (p) => button(p, "Add provider"));
  await opens(page, button(page, "Add provider"), button(page, "Choose a folder of models"));
});

test("Tools the AI wrote", async ({ page }) => {
  const tool = { id: 1, name: "word_count", description: "Counts the words of a text.", code: "export default () => 1;", on: true, created_at: 0, chat_id: null, chat_title: null, uses: 0 };
  await page.route("**/api/tools/written", (route) => route.fulfill({ json: [tool] }));
  await screen(page, "/#/settings/tools/written", (p) => button(p, "Word count"));
  await opens(page, button(page, "Word count"));
});

test("Coding team", async ({ page }) => {
  const task = { id: 1, chat_id: chat, goal: "Fix the dates in the list", folder: "C:\\Projects", state: "running", verdict: null, started_at: 0 };
  await page.route("**/api/coding/tasks", (route) => route.fulfill({ json: [task] }));
  await screen(page, "/#/settings/tools/coding", (p) => p.getByRole("link", { name: /Fix the dates/ }));
  await opens(page, button(page, "Change the planner model"));
});

test("A coding task", async ({ page }) => {
  const permissions = { read: "allow", write: "allow", commands: "ask", install: "ask", web: "never" };
  const step = (id: number, who: object, what: object, checkpoint: object | null) => ({ id, who, what, detail: { code: "none" }, state: "done", output: [], files: [], checkpoint, undone: false, started_at: 0 });
  const task = {
    id: 7,
    chat_id: chat,
    chat_title: "Mira",
    message_id: 1,
    goal: "Add an export",
    folder: "C:\\Projects",
    crew: { team: "balanced", workers: 2, audit: "end", planner_model: "a", worker_model: "b", auditor_model: "a", permissions },
    state: "done",
    planned: 1,
    verdict: { passed: true, tests_passed: 1, tests_total: 1, failures: [], notes: "" },
    error: null,
    started_at: 0,
    ended_at: 0,
    steps: [step(1, { role: "planner" }, { code: "planned", steps: 1 }, null), step(2, { role: "worker", number: 1 }, { code: "work", step: "Write src/a.ts" }, { code: "before_step", step: 1 })],
    files: [{ path: "src/a.ts", added: 1, removed: 0, diff: "+a" }],
    ask: null,
  };
  await page.route("**/api/coding/tasks/7", (route) => route.fulfill({ json: task }));
  await screen(page, `/#/chats/${chat}/tasks/7`, (p) => p.getByText("Wrote src/a.ts"));
});

test("About Cardwave", async ({ page }) => {
  await screen(page, "/#/settings/about", (p) => button(p, "Licence of bge-m3"));
  await opens(page, button(page, "Licence of bge-m3"));
});

test("Voices", async ({ page }) => {
  await screen(page, "/#/settings/voices", (p) => button(p, "Set a voice for a character"));
  await opens(page, button(page, "Make a voice from a recording"), button(page, "Set a voice for a character"));
});

test("First run", async ({ page }) => {
  await screen(page, "/#/setup", (p) => button(p, "Continue"));
});

test("The start screen, while the server waits for the password", async ({ page }) => {
  await page.route("**/api/lock", (route) => route.fulfill({ json: { locked: true, password: true, name: "local" } }));
  await screen(page, "/", (p) => p.getByRole("textbox"));
});

test("Signing in, from another device", async ({ page }) => {
  const accounts = [
    { id: 1, name: "local", local: true, current: false, password: true },
    { id: 2, name: "Ann", local: false, current: false, password: false },
  ];
  await page.route("**/api/sign-in", (route) => route.fulfill({ json: { needed: true, remote: true, accounts } }));
  await screen(page, "/", (p) => p.getByText("Ann"));
});

test("The companion window", async ({ page, request }) => {
  await setSettings(request, { companion: { card_id: card, starts: true, hidden_until: null } });
  await screen(page, "/companion.html", (p) => p.locator("canvas.companion-figure"));
  await page.locator("canvas.companion-figure").dblclick();
  await expect(page.getByRole("dialog", { name: "Chat with your companion" })).toBeVisible();
  await allNamed(page);
});

/** The contrast of `words`' colour on the background drawn under it. */
function contrast(words: Locator): Promise<number> {
  return words.evaluate((node: Element) => {
    const parse = (text: string): number[] => {
      const srgb = text.match(/color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)(?: \/ ([\d.e-]+))?\)/);
      if (srgb) return [Number(srgb[1]) * 255, Number(srgb[2]) * 255, Number(srgb[3]) * 255, srgb[4] === undefined ? 1 : Number(srgb[4])];
      const [r, g, b, a] = (text.match(/[\d.]+/g) ?? []).map(Number);
      return [r, g, b, a ?? 1];
    };
    let under = [0, 0, 0, 0];
    for (let at: Element | null = node; at && under[3] < 1; at = at.parentElement) {
      const [r, g, b, a] = parse(getComputedStyle(at).backgroundColor);
      const left = 1 - under[3];
      under = [under[0] + r * a * left, under[1] + g * a * left, under[2] + b * a * left, under[3] + a * left];
    }
    const page = parse(getComputedStyle(document.body).backgroundColor);
    const left = 1 - under[3];
    const back = [0, 1, 2].map((i) => under[i] + page[i] * left);
    const [r, g, b, a] = parse(getComputedStyle(node).color);
    const front = [r, g, b].map((c, i) => c * a + back[i] * (1 - a));
    const light = (rgb: number[]) =>
      rgb.map((c) => c / 255).map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)).reduce((sum, c, i) => sum + c * [0.2126, 0.7152, 0.0722][i], 0);
    const [dim, bright] = [light(front), light(back)].sort((x, y) => x - y);
    return (bright + 0.05) / (dim + 0.05);
  });
}

test("in Retrowave the account's letter stands out in its round while its line is the one marked", async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem("theme", "retrowave"));
  await page.goto("/#/account");
  const letter = page.locator("#rail .account[aria-current=page] .initial");
  await expect(letter).toBeVisible();
  expect(await contrast(letter)).toBeGreaterThanOrEqual(4.5);
});
