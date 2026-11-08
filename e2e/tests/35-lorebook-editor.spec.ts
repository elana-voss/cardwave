import type { APIRequestContext, Locator, Page, Request } from "@playwright/test";
import { ccv4File } from "../card";
import { expect, test } from "../test";

// A lorebook's editor, one screen for a lorebook of the library and a card's own: an entry's parts are saved as
// they are left, with no Save (its name written where it stands, Content a text block with its versions); a new
// entry is kept once it has a name; the header's AI tools change every entry, each change kept or undone; a
// card's own lorebook is edited in the card, and moved into the library and back.
//
// Every test makes a lorebook of its own (`make`, the world `CAMLANN` under a name of the test's: five
// entries, of which the third always applies, the fourth is used by meaning and the fifth is switched off and
// has every setting of "More settings") and reads it past the page (`kept`). `open` shows a lorebook's editor
// and waits for its entries; `line` is an entry's line in the list, `title` the name over the entry, `used`
// the choice "Used when", `pills` the keywords of a field, and `sent` notes what the page sends to change
// entries; `edited` waits until the server has the change. A line's link is named by all it says, so a line is
// asked for by its entry's name alone (`.entry-label`). A line pressed shows its entry a moment later: a test
// waits for the entry's name (`show`) before it types. The window is 1280 px wide; from 960 px down the list
// and the entry are screens of their own. No test asks a model: the AI tools' answer is the test's own
// (`page.route`).

const CAMLANN = {
  description: "Of the kingdom and its court.",
  entries: {
    0: { key: ["council", "twelve", "lords"], comment: "The Council of Twelve", content: "Twelve lords sit in council at Camlann Keep." },
    1: { key: ["keep", "castle", "Camlann"], comment: "Camlann Keep", content: "The keep stands over the river." },
    2: { key: [], comment: "The Royal Guard", content: "The guard wears grey.", constant: true },
    3: { key: ["oath"], comment: "The Oath", content: "Sworn at dawn.", vectorized: true },
    4: {
      key: ["ford", "river"],
      comment: "The Ford",
      content: "Shallow in summer.",
      disable: true,
      keysecondary: ["night"],
      selective: true,
      selectiveLogic: 2,
      position: 4,
      depth: 2,
      order: 30,
      probability: 40,
      useProbability: true,
      scanDepth: 6,
      caseSensitive: true,
      matchWholeWords: true,
    },
  },
};

interface Entry {
  reference: string;
  label: string;
  name: string;
  trigger: string;
  keywords: string[];
  content: string;
  enabled: boolean;
  at_depth: boolean;
  depth: number;
  order: number;
  secondary: string[];
  logic: string;
  probability: number;
  scan_depth: number;
  case_sensitive: boolean;
  whole_words: boolean;
}

/** Imports the world under `name`, and answers with the lorebook's number. */
async function make(request: APIRequestContext, name: string): Promise<number> {
  const made = await request.post(`/api/lorebooks?name=${encodeURIComponent(name)}.json`, { data: Buffer.from(JSON.stringify(CAMLANN)) });
  expect(made.status(), await made.text()).toBe(201);
  return (await made.json()).lorebook.id;
}

/** A lorebook as the server keeps it. */
async function kept(request: APIRequestContext, id: number): Promise<{ name: string; description: string; entries: Entry[] }> {
  const shown = await request.get(`/api/lorebooks/${id}/edit`);
  expect(shown.status(), await shown.text()).toBe(200);
  return shown.json();
}

const entryOf = async (request: APIRequestContext, id: number, label: string) => (await kept(request, id)).entries.find((entry) => entry.label === label)!;

/** Opens a lorebook's editor, at an entry or without one, and waits for its entries. */
async function open(page: Page, id: number, entry = ""): Promise<void> {
  await page.goto(`/#/library/lorebooks/${id}${entry && `/${entry}`}`);
  await expect(page.locator(".lore-entries .panel-label")).toContainText("Entries ·");
}

const panel = (page: Page) => page.getByRole("complementary", { name: "Entries" });
const lines = (page: Page) => page.locator(".entry-line");
const line = (page: Page, name: string) => lines(page).filter({ has: page.locator(".entry-label").getByText(name, { exact: true }) });
const labels = (page: Page) => page.locator(".entry-label");
const title = (page: Page) => page.locator(".entry-form .edit-head h2");
/** The entry's Content, as it shows while it is not written in. */
const content = (page: Page) => page.getByRole("region", { name: "Content" }).locator(".tb-body");
/** Presses an entry's line, and waits until that entry is the one in view. */
async function show(page: Page, name: string): Promise<void> {
  await line(page, name).getByRole("link").click();
  await expect(title(page)).toHaveText(name);
}
const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const field = (page: Page, name: string) => page.locator(".entry-form").getByLabel(name, { exact: true });
const used = (page: Page) => page.getByRole("group", { name: "Used when" });
const pressed = (group: Locator) => group.locator('button[aria-pressed="true"]');
/** The keywords of the field named `name`, as its pills say them. */
const pills = (page: Page, name = "Keywords") => page.locator(".entry-form .fld", { has: page.getByLabel(name, { exact: true }) }).locator(".key");
const toast = (page: Page) => page.locator("#toast span");
/** Whether the address names the entry `reference` of the lorebook `id`, or none. */
const at = (id: number, reference = "") => new RegExp(`#/library/lorebooks/${id}${reference && `/${reference.replace(".", "\\.")}`}$`);

/** Notes what the page sends to change, add or take out entries. */
function sent(page: Page): Request[] {
  const all: Request[] = [];
  page.on("request", (request) => {
    if (request.url().includes("/entries") && request.method() !== "GET") all.push(request);
  });
  return all;
}

/** Waits until what `sent` noted holds `count` changes, and answers the last. */
async function edited(changes: Request[], count: number): Promise<Request> {
  await expect.poll(() => changes.length).toBe(count);
  await changes.at(-1)!.response();
  return changes.at(-1)!;
}

test("an entry's parts are saved as they are left, and its line follows", async ({ page, request }) => {
  const id = await make(request, "Saved");
  const changes = sent(page);
  await open(page, id);
  await expect(button(page, "Save")).toHaveCount(0);

  // The name is written where it stands; Enter saves it.
  await title(page).click();
  await page.getByLabel("Entry name").fill("The High Council");
  await page.getByLabel("Entry name").press("Enter");
  expect((await edited(changes, 1)).postDataJSON()).toEqual({ name: "The High Council" });
  await expect(title(page)).toHaveText("The High Council");
  await expect(labels(page).first()).toHaveText("The High Council");
  await expect(lines(page).first().getByRole("link")).toHaveAttribute("aria-current", "true");

  // A keyword is saved as it is entered, and so is one taken away.
  await field(page, "Keywords").fill("thirteen");
  await field(page, "Keywords").press("Enter");
  expect((await edited(changes, 2)).postDataJSON()).toEqual({ keywords: ["council", "twelve", "lords", "thirteen"] });
  await page.getByRole("button", { name: "Remove twelve" }).click();
  expect((await edited(changes, 3)).postDataJSON()).toEqual({ keywords: ["council", "lords", "thirteen"] });
  await expect(lines(page).first().locator(".entry-link > .meta")).toHaveText("Keywords: council, lords, thirteen");

  // Content is written where it stands, and saved as it is left: a version of its words.
  await content(page).click();
  await page.getByRole("textbox", { name: "Content" }).fill("Thirteen lords sit in council.");
  await page.getByRole("textbox", { name: "Content" }).press("Escape");
  const words = await edited(changes, 4);
  expect(words.postDataJSON()).toEqual({ content: "Thirteen lords sit in council." });
  await expect(content(page)).toHaveText("Thirteen lords sit in council.");
  const saved = await entryOf(request, id, "The High Council");
  expect([saved.name, saved.keywords, saved.content]).toEqual(["The High Council", ["council", "lords", "thirteen"], "Thirteen lords sit in council."]);
  // Its clock lists the versions, and goes back to one.
  await button(page, "Earlier versions of Content").click();
  await expect(page.getByRole("menuitem")).toHaveCount(2);
  await page.getByRole("menuitem").nth(1).click();
  await button(page, "Restore this version").click();
  const back = await edited(changes, 5);
  expect(back.url()).toContain("made=restored");
  await expect(content(page)).toHaveText(CAMLANN.entries[0].content);

  // The hint under "Used when" is the one of the choice: "By meaning" alone has one.
  const meaningHint = page.getByText("By meaning: used when");
  await expect(meaningHint).toBeHidden();
  // "Always" needs no keywords: their field goes, and the line says "Always".
  await used(page).getByRole("button", { name: "Always" }).click();
  await expect(field(page, "Keywords")).toBeHidden();
  expect((await edited(changes, 6)).postDataJSON()).toEqual({ trigger: "always" });
  await expect(lines(page).first().locator(".entry-link > .meta")).toHaveText("Always");
  expect((await entryOf(request, id, "The High Council")).trigger).toBe("always");

  // "More settings" opens in place; a number is saved as it is left, a wrong one not.
  await button(page, "More settings").click();
  await field(page, "Order").fill("7");
  await field(page, "Order").press("Tab");
  expect((await edited(changes, 7)).postDataJSON()).toEqual({ order: 7 });
  await field(page, "Chance (%)").fill("140");
  await field(page, "Chance (%)").press("Tab");
  await page.waitForTimeout(200);
  expect(changes).toHaveLength(7);
  // Without secondary keywords there is no choice of how they count, nor a hint that names it.
  const secondHint = page.getByText("A keyword alone is then not enough");
  await expect(secondHint).toBeHidden();
  // It stays open from one entry to the next.
  await show(page, "The Ford");
  await expect(field(page, "Order")).toHaveValue("30");
  await expect(secondHint).toBeVisible();
  await used(page).getByRole("button", { name: "By meaning" }).click();
  await expect(meaningHint).toBeVisible();

  // The entry's "…": Rename writes the name, Delete entry takes it out with Undo.
  await page.getByRole("button", { name: "Entry menu" }).click();
  await page.getByRole("menuitem", { name: "Rename" }).click();
  await expect(page.getByLabel("Entry name")).toBeFocused();
  await page.getByLabel("Entry name").press("Escape");
  await page.getByRole("button", { name: "Entry menu" }).click();
  await page.getByRole("menuitem", { name: "Delete entry" }).click();
  await expect(toast(page)).toHaveText("Entry “The Ford” deleted.");
  await expect(panel(page).locator(".panel-label")).toHaveText("Entries · 4");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(panel(page).locator(".panel-label")).toHaveText("Entries · 5");
  await expect(title(page)).toHaveText("The Ford");
});

test("“New entry” opens a new entry, kept as the lorebook's last once it has a name", async ({ page, request }) => {
  const id = await make(request, "Added");
  const changes = sent(page);
  await open(page, id);
  await show(page, "Camlann Keep");
  await panel(page).getByRole("button", { name: "New entry" }).click();
  await expect(page).toHaveURL(at(id, "new"));
  // Its name is written in the heading's place, as a made entry's; the list marks its line at the end.
  const named = title(page).getByRole("textbox", { name: "Entry name" });
  await expect(named).toBeFocused();
  await expect(named).toHaveAttribute("placeholder", "Name the entry");
  await expect(page.locator(".entry-form .hint")).toHaveText(/leave it empty to make none/);
  await expect(page.getByRole("button", { name: "Entry menu" })).toHaveCount(0);
  await expect(panel(page).locator("[aria-current]")).toHaveText("New entry");
  // Without a name nothing is kept.
  await named.press("Enter");
  expect(changes).toHaveLength(0);

  // A name has 64 signs at most, counted as signs.
  await title(page).click();
  await named.fill("🌊".repeat(70));
  await expect(named).toHaveValue("🌊".repeat(64));
  await named.fill("The Mill");
  // A name that could not be kept stays written, to be tried again.
  await page.route("**/entries", (route) => route.fulfill({ status: 500, json: { code: "internal", error: "down" } }), { times: 1 });
  await named.press("Enter");
  await expect(named).toHaveValue("The Mill");
  await named.press("Enter");
  await expect(toast(page)).toHaveText("Entry added.");
  expect(changes.map((change) => [change.method(), change.postDataJSON()])).toEqual([
    ["POST", { name: "The Mill" }],
    ["POST", { name: "The Mill" }],
  ]);
  // It is the last entry, in view under its own address, and the lorebook has one more.
  const mill = await entryOf(request, id, "The Mill");
  await expect(page).toHaveURL(at(id, mill.reference));
  await expect(panel(page).locator(".panel-label")).toHaveText("Entries · 6");
  await expect(labels(page).last()).toHaveText("The Mill");
  await expect(lines(page).last().getByRole("link")).toHaveAttribute("aria-current", "true");
  await expect(title(page)).toHaveText("The Mill");
  await expect(content(page)).toContainText("Empty");
  // The way back leads to the entry before, not to the new one's place.
  await page.goBack();
  await expect(title(page)).toHaveText("Camlann Keep");
});

test("the header's AI tools change every entry, each change kept or undone, “Keep all” in the bar", async ({ page, request }) => {
  const id = await make(request, "Fixed");
  const changes = sent(page);
  const asked: { tool: string; given?: string; entries: { reference: string; text: string }[] }[] = [];
  // `held` keeps the answer back until the test lets it go.
  let held: Promise<void> | null = null;
  await page.route("**/api/rewrite/lore", async (route) => {
    const body = route.request().postDataJSON();
    asked.push(body);
    await held;
    // Each entry's words with a full stop more, but the third's.
    const answer = body.entries.map((entry: { text: string }, at: number) => ({ ...entry, text: at === 2 ? entry.text : `${entry.text}.` }));
    await route.fulfill({ json: answer });
  });
  await open(page, id);
  const tools = page.getByRole("button", { name: "AI tools for the lorebook" });
  await tools.click();
  await expect(page.getByRole("menuitem")).toHaveText(["Write missing keywords", "Fix grammar in every entry", "Translate the lorebook…"]);
  // Every entry here has keywords, or needs none.
  await page.getByRole("menuitem", { name: "Write missing keywords" }).click();
  await expect(toast(page)).toHaveText("Every entry has keywords.");
  expect(asked).toHaveLength(0);

  await tools.click();
  await page.getByRole("menuitem", { name: "Fix grammar in every entry" }).click();
  const bar = page.locator(".lore-bar");
  await expect(bar).toContainText("4 entries changed by AI");
  expect(asked[0].tool).toBe("fix");
  expect(asked[0].entries).toHaveLength(5);
  // The entry in view shows its change against it, with Keep and Undo; its line says so.
  const change = page.getByRole("region", { name: "Proposed by the AI" });
  await expect(change.locator("ins")).toHaveCount(1);
  await expect(change.locator("ins")).toHaveText("Keep..");
  await expect(lines(page).first().locator(".entry-link > .meta")).toContainText("Proposed by the AI");
  expect(changes).toHaveLength(0);
  await change.getByRole("button", { name: "Keep" }).click();
  const kept1 = await edited(changes, 1);
  expect(kept1.url()).toContain("made=fix");
  expect(kept1.postDataJSON()).toEqual({ content: `${CAMLANN.entries[0].content}.` });
  await expect(bar).toContainText("3 entries changed by AI");
  await expect(change).toHaveCount(0);
  // Undone, one changes nothing; "Keep all" keeps the rest.
  await show(page, "Camlann Keep");
  await change.getByRole("button", { name: "Undo" }).click();
  await expect(bar).toContainText("2 entries changed by AI");
  await bar.getByRole("button", { name: "Keep all changes" }).click();
  await expect(bar).toBeHidden();
  await expect.poll(() => changes.length).toBe(3);
  const now = await kept(request, id);
  expect(now.entries.map((entry) => entry.content.endsWith("."))).toEqual([true, true, true, true, true]);
  expect(now.entries[1].content).toBe(CAMLANN.entries[1].content);

  // While a tool runs, another is not run; an entry changed meanwhile (here in another window) gets no change.
  let letGo = () => {};
  held = new Promise((resolve) => (letGo = resolve));
  await tools.click();
  await page.getByRole("menuitem", { name: "Fix grammar in every entry" }).click();
  await expect(bar).toContainText("Fixing grammar in every entry…");
  await tools.click();
  await page.getByRole("menuitem", { name: "Fix grammar in every entry" }).click();
  expect(asked).toHaveLength(2);
  const keep = (await kept(request, id)).entries[1];
  const meanwhile = await request.patch(`/api/lorebooks/${id}/entries/${keep.reference}`, { data: { keywords: ["keep"] } });
  expect(meanwhile.status()).toBe(200);
  await expect(line(page, "Camlann Keep").locator(".meta")).toHaveText("Keywords: keep");
  letGo();
  await expect(bar).toContainText("3 entries changed by AI");
  await expect(line(page, "Camlann Keep").locator(".meta")).toHaveText("Keywords: keep");
  await bar.getByRole("button", { name: "Undo all" }).click();
  await expect(bar).toBeHidden();

  // Translate asks into which language in the bar.
  await tools.click();
  await page.getByRole("menuitem", { name: "Translate the lorebook…" }).click();
  await bar.getByRole("textbox", { name: "Into which language?" }).fill("German");
  await bar.getByRole("textbox", { name: "Into which language?" }).press("Enter");
  await expect(bar).toContainText("entries changed by AI");
  expect(asked.at(-1)).toMatchObject({ tool: "translate", given: "German" });
});

test("“Lorebook settings” changes the name, the description, the scan depth and the token budget; the header stars and archives it", async ({ page, request }) => {
  const id = await make(request, "Settings");
  await open(page, id);
  await button(page, "Lorebook settings").click();
  const dialog = page.getByRole("dialog", { name: "Lorebook settings" });
  await dialog.getByLabel("Name", { exact: true }).fill("Camlann");
  await dialog.getByLabel("Messages searched").fill("6");
  await dialog.getByLabel("Token limit").fill("300");
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(dialog).toBeHidden();
  const now = await kept(request, id);
  expect([now.name, now.description]).toEqual(["Camlann", CAMLANN.description]);
  expect(now).toMatchObject({ scan_depth: 6, token_budget: 300 });

  await page.locator(".lorebook header").getByRole("button", { name: "Favourite" }).click();
  await page.locator(".lorebook header").getByRole("button", { name: "Lorebook menu" }).click();
  await page.getByRole("menuitem", { name: "Archive" }).click();
  await expect(toast(page)).toContainText("archived");
  const listed = await (await request.get("/api/lorebooks?show=archived")).json();
  expect(listed.find((one: { id: number; card?: unknown }) => one.id === id && !one.card)).toMatchObject({ favorite: true, archived: true });
});

/** A card whose character brings the lorebook `harbour`, of two entries. */
const HARBOUR = `
spec = "ccv4:1.0.0"

[meta-info]
title = "The Harbour Master"

[name.mira]
text = "Mira"

[lore.lamp]
name = "The lamp"
keywords = ["lamp"]
text = "The lamp turns every ten seconds."

[lore.reef]
name = "The reef"
keywords = ["reef"]
text = "The reef lies north."

[lorebook.harbour]
name = "Harbour"
entries = ["lore.lamp", "lore.reef"]

[character.mira]
name-card = "Mira"
name-char = "name.mira"
lorebooks = ["lorebook.harbour"]
prompt = ["name.mira", "LOREBOOK", "CHAT-HISTORY"]
`;

test("a card's own lorebook is edited in the card, without star, Archive or Delete, and moved into the library and back", async ({ page, request }) => {
  const made = await request.post("/api/cards", { data: ccv4File(HARBOUR) });
  expect(made.status(), await made.text()).toBe(201);
  const { card_id: card } = await made.json();
  const changes = sent(page);
  await page.goto(`/#/library/${card}/lorebook`);
  await expect(title(page)).toHaveText("The lamp");
  await expect(page.locator(".crumbs")).toHaveText(/Characters\s*\/\s*The Harbour Master\s*\/\s*Harbour\s*· this character's own/);
  const header = page.locator(".lorebook header");
  await expect(header.getByRole("button", { name: "Favourite" })).toHaveCount(0);
  await header.getByRole("button", { name: "Lorebook menu" }).click();
  await expect(page.getByRole("menuitem")).toHaveText([/Copy to library/, /Move to library/, "Export"]);
  await page.keyboard.press("Escape");

  // An entry's words are a new version of the card.
  const before = (await (await request.get(`/api/cards/${card}`)).json()).card.version_id;
  await content(page).click();
  await page.getByRole("textbox", { name: "Content" }).fill("The lamp turns every twelve seconds.");
  await page.getByRole("textbox", { name: "Content" }).press("Escape");
  expect((await edited(changes, 1)).url()).toContain(`/api/cards/${card}/lorebook/entries/lore.lamp`);
  expect((await (await request.get(`/api/cards/${card}`)).json()).card.version_id).not.toBe(before);
  const own = await (await request.get(`/api/cards/${card}/lorebook/edit`)).json();
  expect(own.entries[0].content).toBe("The lamp turns every twelve seconds.");

  // The library lists it "in" its card; moved there, its editor is the library's, and Undo puts it back.
  await header.getByRole("button", { name: "Lorebook menu" }).click();
  await page.getByRole("menuitem", { name: /Move to library/ }).click();
  await expect(page).toHaveURL(/#\/library\/lorebooks\/\d+$/);
  await expect(toast(page)).toHaveText("Moved to the library.");
  await expect(page.locator(".crumbs")).toHaveText(/Lorebooks\s*\/\s*Harbour/);
  await expect(content(page)).toHaveText("The lamp turns every twelve seconds.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(page).toHaveURL(new RegExp(`#/library/${card}/lorebook\\.harbour$`));
  await expect(page.locator(".crumbs")).toContainText("this character's own");
  await expect(content(page)).toHaveText("The lamp turns every twelve seconds.");
});

test("the lorebook's AI tools on their way ask the model no more once its page is left", async ({ page, request }) => {
  const id = await make(request, "Left");
  let answer = () => {};
  const held = new Promise<void>((done) => (answer = done));
  for (const asked of ["**/api/rewrite", "**/api/rewrite/lore"]) await page.route(asked, async (route) => (await held, route.fallback().catch(() => {})));
  const leftWhileAsking = async (url: string) => {
    const stopped = page.waitForEvent("requestfailed", { predicate: (one) => one.url().endsWith(url), timeout: 5000 });
    await page.goto("/#/library/lorebooks");
    await stopped;
  };
  // The whole lorebook's tool.
  await open(page, id);
  await button(page, "AI tools for the lorebook").click();
  await page.getByRole("menuitem", { name: "Fix grammar in every entry" }).click();
  await leftWhileAsking("/api/rewrite/lore");
  // An entry's Content's own tool.
  await open(page, id);
  await lines(page).first().click();
  await page.getByRole("region", { name: "Content" }).hover();
  await button(page, "AI tools for Content").click();
  await page.getByRole("menuitem").first().click();
  await leftWhileAsking("/api/rewrite");
  answer();
});

test("in a narrow window the entry list is the page's width, not a sheet over the lorebook's bar", async ({ page, request }) => {
  await page.setViewportSize({ width: 960, height: 700 });
  await open(page, await make(request, "Narrow"));
  const list = (await panel(page).boundingBox())!;
  const whole = (await page.locator(".lorebook").boundingBox())!;
  expect(Math.round(list.x)).toBe(Math.round(whole.x));
  expect(Math.round(list.width)).toBe(Math.round(whole.width));
});
