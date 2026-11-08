import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile, ccv4File } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Lorebooks in the library, in a chat and on a card: an import of lorebook files, one made from scratch, one of
// the library added to a chat, one attached to a card and detached again without being deleted, and one used in every
// chat or given to a persona.
//
// One database for the file. Every test starts without lorebooks in the library and makes its own.
test.describe.configure({ mode: "serial" });

/** A card whose character brings a lorebook of its own, with one entry that always applies. */
const FERRY = `
spec = "ccv4:1.0.0"

[meta-info]
title = "Tam of the Ferry"

[name.tam]
text = "Tam"

[greeting.rope]
text = "Tam coils the rope."

[lore.bell]
name = "Ferry bell"
trigger = "always"
keywords = []
text = "The ferry bell hangs by the landing."

[lorebook.river]
name = "River"
entries = ["lore.bell"]

[character.tam]
name-card = "Tam"
name-char = "name.tam"
greetings = ["greeting.rope"]
lorebooks = ["lorebook.river"]
prompt = ["name.tam", "LOREBOOK", "CHAT-HISTORY"]
`;

const FERRY_BELL = "The ferry bell hangs by the landing.";
const FOG = "Fog comes up the harbour at dusk.";
const PIER = "The pier is rotten.";

let provider: FakeProvider;
/** The card versions to chat with: Tam brings a lorebook, Ada none. And their cards. */
const versions = { tam: 0, ada: 0 };
const cards = { tam: 0, ada: 0 };

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  const add = async (who: "tam" | "ada", file: Buffer): Promise<void> => {
    const response = await request.post("/api/cards", { data: file });
    expect(response.status()).toBe(201);
    const { card_id, version_id } = await response.json();
    [cards[who], versions[who]] = [card_id, version_id];
  };
  await add("tam", ccv4File(FERRY));
  await add("ada", cardFile({ name: "Ada Quill", first_mes: "Ada looks up." }));
});
test.afterAll(() => provider.close());

/** Deletes every lorebook of the library for good, wherever it is. */
test.beforeEach(async ({ request }) => {
  // The cards' own lorebooks, which the list shows too, are the cards'.
  const listed = async (path: string): Promise<{ id: number }[]> => ((await (await request.get(path)).json()) as { id: number; card?: unknown }[]).filter((one) => !one.card);
  for (const { id } of [...(await listed("/api/lorebooks")), ...(await listed("/api/lorebooks?show=archived"))]) {
    expect((await request.patch(`/api/lorebooks/${id}`, { data: { trashed: true } })).status()).toBe(200);
  }
  const trash: { items: { kind: string; id: number }[] } = await (await request.get("/api/trash")).json();
  for (const { kind, id } of trash.items) {
    if (kind === "lorebook") expect((await request.delete(`/api/lorebooks/${id}`)).status()).toBe(204);
  }
});

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const search = (page: Page) => page.getByLabel("Search lorebooks");
const names = (page: Page) => page.locator(".card-row .row-title");
const row = (page: Page, name: string) => page.locator(".card-row", { hasText: name });
const messages = (page: Page) => page.locator(".message");
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const panel = (page: Page) => page.getByRole("complementary", { name: "Chat details" });
const lorebook = (page: Page, name: string) => panel(page).getByRole("switch", { name, exact: true });
/** A part of the panel, by its name. */
const part = (page: Page, name: string) => panel(page).locator(".panel-part", { has: page.getByText(name, { exact: true }) });
const used = (page: Page) => part(page, "Used in last reply").locator(".item.used");
const lorebookLines = (page: Page) => part(page, "Lorebooks").locator(".item");
/** What an import of several files says, at the window's foot, and its line of one file or item. */
const importing = (page: Page) => page.getByRole("status", { name: "Import" });
const imported = (page: Page, name: string) => importing(page).locator(".import-line", { hasText: name });

/** One entry of a lorebook file: it applies always, or when one of its keys is said. */
interface Entry {
  name: string;
  content: string;
  keys?: string[];
}

/** A lorebook file as SillyTavern writes its world info, with what else the file says of itself. */
function world(entries: Entry[], about: Record<string, unknown> = {}): Buffer {
  const numbered = entries.map(({ name, content, keys }, uid) => [uid, { uid, key: keys ?? [], comment: name, content, constant: !keys }]);
  return Buffer.from(JSON.stringify({ entries: Object.fromEntries(numbered), ...about }));
}

/** The lorebook most tests take along: "Fog" applies always, "Pier" when a pier is spoken of. */
const HARBOUR: Entry[] = [
  { name: "Fog", content: FOG },
  { name: "Pier", content: PIER, keys: ["pier"] },
];

/** Imports a lorebook past the page, under the name of its file, with the changes named. Returns its id. */
async function add(request: APIRequestContext, name: string, entries: Entry[] = HARBOUR, change?: Record<string, boolean>): Promise<number> {
  const response = await request.post(`/api/lorebooks?name=${encodeURIComponent(`${name}.json`)}`, { data: world(entries) });
  expect(response.status(), await response.text()).toBe(201);
  const { id } = (await response.json()).lorebook;
  if (change) await alter(request, id, change);
  return id;
}

async function alter(request: APIRequestContext, id: number, change: Record<string, boolean>): Promise<void> {
  const response = await request.patch(`/api/lorebooks/${id}`, { data: change });
  expect(response.status(), await response.text()).toBe(200);
}

/** Starts a chat with one of the two characters, with these lorebooks of the library taken along. Returns its id. */
async function start(request: APIRequestContext, who: "tam" | "ada", ...taken: number[]): Promise<number> {
  const character = who === "tam" ? "tam" : "ada-quill";
  const response = await request.post("/api/chats", { data: { characters: [{ version_id: versions[who], character }] } });
  expect(response.status(), await response.text()).toBe(201);
  const chat: number = (await response.json()).chat.id;
  for (const lorebook_id of taken) {
    expect((await request.post(`/api/chats/${chat}/lorebooks`, { data: { lorebook_id } })).status()).toBe(200);
  }
  return chat;
}

async function open(page: Page): Promise<void> {
  await page.goto("/#/library/lorebooks");
  await expect(page.locator(".rows-plain > li").first()).toBeVisible();
}

async function openChat(page: Page, chat: number): Promise<void> {
  await page.goto(`/#/chats/${chat}`);
  await expect(messages(page).first()).toBeVisible();
}

/** Sends a message and waits for the reply to it to end. */
async function say(page: Page, text: string): Promise<void> {
  // The reply is the second message more: before it is there, "Write again" is the one of the message before.
  const before = await messages(page).count();
  await composer(page).fill(text);
  await composer(page).press("Enter");
  await expect(messages(page)).toHaveCount(before + 2);
  await expect(button(page, "Write again")).toBeEnabled();
}

/** The prompt the provider was last given, as one text. */
const lastPrompt = () => provider.asked.at(-1)!.body.messages.map((message: { content: string }) => message.content).join("\n");

// The library's section.

test("Import takes lorebook files, says what came of each and shows the new ones", async ({ page, request }) => {
  await add(request, "Moor", [{ name: "Peat", content: "Peat is cut in spring." }], { favorite: true });
  await open(page);
  await button(page, "Favourites").click();
  await search(page).fill("moor");
  await expect(names(page)).toHaveText(["Moor"]);

  // A file that is no lorebook is refused by its name, with the reason; the list stays as it was asked for.
  await page.setInputFiles("input[type=file]", { name: "notes.json", mimeType: "application/json", buffer: Buffer.from("not a lorebook") });
  await expect(importing(page).getByRole("heading")).toHaveText("No lorebooks imported · 1 failed");
  await expect(imported(page, "notes.json")).toContainText("The file is not valid JSON");
  await expect(search(page)).toHaveValue("moor");
  await expect(button(page, "Favourites")).toHaveAttribute("aria-pressed", "true");
  await expect(names(page)).toHaveText(["Moor"]);
  // The panel stays for the file that failed, and would take the next files too: it is closed.
  await importing(page).getByRole("button", { name: "Close" }).click();

  // Two files at once. One is called as its file is, the other as it calls itself; what an import has to say is told.
  const outlet = { uid: 9, key: ["out"], comment: "Outlet", content: "For an outlet.", position: 7 };
  const coast = Buffer.from(JSON.stringify({ entries: { 0: { uid: 0, key: ["wreck"], comment: "Wreck", content: "A wreck." }, 9: outlet } }));
  const named = world([{ name: "Reef", content: "The reef shows at low water." }], { name: "The North Reef", description: "What the pilots know." });
  await page.setInputFiles("input[type=file]", [
    { name: "coast.json", mimeType: "application/json", buffer: coast },
    { name: "export.json", mimeType: "application/json", buffer: named },
    { name: "notes.json", mimeType: "application/json", buffer: Buffer.from("[]") },
  ]);
  await expect(importing(page).getByRole("heading")).toHaveText("2 lorebooks imported · 1 failed");
  await expect(importing(page).locator(".import-name")).toHaveText(["coast", "The North Reef", "notes.json"]);
  await expect(imported(page, "coast")).toContainText("lorebook entries for an outlet were imported switched off (1)");
  await expect(imported(page, "The North Reef")).toContainText("Imported");
  await expect(imported(page, "notes.json")).toContainText("The file holds no lorebook");
  // The new ones are in view at once, whatever the list was searched or filtered for.
  await expect(search(page)).toHaveValue("");
  await expect(button(page, "All")).toHaveAttribute("aria-pressed", "true");
  await expect(button(page, "Favourites")).toHaveAttribute("aria-pressed", "false");
  // Tam's card brings "River": the list has it too.
  await expect(names(page)).toHaveText(["coast", "Moor", "River", "The North Reef"]);
  await expect(row(page, "coast").locator(".tags")).toHaveText("2 entries: Wreck, Outlet");
  await expect(row(page, "The North Reef").locator(".excerpt")).toHaveText("What the pilots know.");

  // The same file again is another lorebook.
  await page.setInputFiles("input[type=file]", { name: "coast.json", mimeType: "application/json", buffer: coast });
  await expect(names(page)).toHaveText(["coast", "coast", "Moor", "River", "The North Reef"]);
});

test("a card's own lorebook is listed in its card, with Copy to library, Move to library and Export", async ({ page, request }) => {
  await open(page);
  const river = row(page, "River");
  await expect(river).toContainText("in Tam of the Ferry");
  await expect(river.getByRole("button", { name: "Favourite" })).toHaveCount(0);
  await expect(river.getByRole("link", { name: "River" })).toHaveAttribute("href", `#/library/${cards.tam}/lorebook`);
  await river.getByRole("button", { name: "More" }).click();
  await expect(page.getByRole("menuitem")).toHaveText([/^Copy to library/, /^Move to library/, "Export"]);
  await expect(item(page, "Copy to library")).toHaveAttribute("aria-description", "A separate lorebook to use elsewhere. This character keeps its own.");
  await expect(page.getByRole("menuitem", { name: /^Copy to library/ })).toContainText("A separate lorebook to use elsewhere. This character keeps its own.");

  // Copied, the library has a lorebook of its own beside the card's; Undo deletes it for good.
  await page.getByRole("menuitem", { name: /^Copy to library/ }).click();
  await expect(page.locator("#toast span")).toHaveText("Copied to the library.");
  await expect(names(page)).toHaveText(["River", "River"]);
  expect(await inLibrary(request)).toEqual(["River"]);
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(names(page)).toHaveText(["River"]);
  expect(await inLibrary(request)).toEqual([]);

  // Moved, it is the library's, which the card uses; Undo puts it back into the card.
  await river.getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: /^Move to library/ }).click();
  await expect(page.locator("#toast span")).toHaveText("Moved to the library.");
  await expect(river).not.toContainText("in Tam of the Ferry");
  expect(await inLibrary(request)).toEqual(["River"]);
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(river).toContainText("in Tam of the Ferry");
  expect(await inLibrary(request)).toEqual([]);
  // Moved and put back, the card has a version of its own: the chats after start with it.
  versions.tam = (await (await request.get(`/api/cards/${cards.tam}`)).json()).card.version_id;
});

test("New lorebook on the empty tab names a lorebook, which opens empty in its editor at a new entry", async ({ page, request }) => {
  // Tam's card is in the Trash meanwhile: its own lorebook would be listed.
  const trash = async (trashed: boolean) => expect((await request.patch(`/api/cards/${cards.tam}`, { data: { trashed } })).status()).toBe(200);
  await trash(true);
  await page.goto("/#/library/lorebooks");
  await expect(page.locator(".rows-plain .empty")).toContainText("No lorebooks yet.");
  await button(page, "New lorebook").click();
  const dialog = page.getByRole("dialog", { name: "New lorebook" });
  await dialog.getByLabel("Name").fill("Reedmere");
  await dialog.getByLabel("Description").fill("Of the mere.");
  await dialog.getByRole("button", { name: "Save" }).click();

  // The editor of the lorebook made, which has no entries, at a new entry.
  await expect(page).toHaveURL(/#\/library\/lorebooks\/\d+\/new$/);
  await expect(dialog).toHaveCount(0);
  const made = ((await (await request.get("/api/lorebooks")).json()) as { card?: unknown }[]).find((one) => !one.card);
  expect(made).toMatchObject({ name: "Reedmere", description: "Of the mere.", entries: 0 });
  await expect(page.locator(".crumbs")).toContainText("Reedmere");
  await expect(page.getByRole("complementary", { name: "Entries" }).locator("[aria-current]")).toHaveText("New entry");
  const named = page.locator(".entry-form .edit-head h2").getByRole("textbox", { name: "Entry name" });
  await named.fill("Heron");
  await named.press("Enter");
  await expect(page.locator("#toast span")).toHaveText("Entry added.");

  // In the list it is a lorebook as any other.
  await page.locator(".crumbs").getByRole("link", { name: "Lorebooks" }).click();
  await expect(row(page, "Reedmere")).toContainText("1 entry");
  await trash(false);
});

// The chat's side panel.

test("Add a lorebook offers the library's lorebooks in plain view, and the one chosen joins the chat's own", async ({ page, request }) => {
  await add(request, "Harbour");
  await add(request, "Moor", [{ name: "Peat", content: "Peat is cut in spring." }]);
  await add(request, "Atlas", HARBOUR, { archived: true });
  await add(request, "Reef", HARBOUR, { trashed: true });
  const chat = await start(request, "tam");
  await openChat(page, chat);
  await expect(lorebookLines(page)).toHaveText(["River"]);

  // The "+" beside the part's name opens the library's lorebooks, by name: not the archived one, nor the one in the Trash.
  const adder = part(page, "Lorebooks").getByRole("button", { name: "Add a lorebook to this chat" });
  await adder.click();
  await expect(page.getByRole("menuitem")).toHaveText(["Harbour", "Moor"]);
  await item(page, "Harbour").click();
  await expect(lorebookLines(page)).toHaveText(["River", "Harbour"]);
  await expect(lorebook(page, "Harbour")).toBeChecked();
  // The button has the focus again, and no longer offers what the chat has.
  await expect(adder).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem")).toHaveText(["Moor"]);
  await page.keyboard.press("Escape");

  // The next reply is given its entries beside the card's, each listed as used.
  await say(page, "Is the pier safe?");
  expect(lastPrompt()).toContain(FERRY_BELL);
  expect(lastPrompt()).toContain(FOG);
  expect(lastPrompt()).toContain(PIER);
  await expect(used(page)).toHaveText(["Entry of RiverFerry bell", "Entry of HarbourFog", "Entry of HarbourPier"]);
  // It is the chat's after a reload too.
  await page.reload();
  await expect(lorebookLines(page)).toHaveText(["River", "Harbour"]);

  // With nothing left to take, the menu leads to the library.
  await adder.click();
  await item(page, "Moor").click();
  await expect(lorebookLines(page)).toHaveText(["River", "Harbour", "Moor"]);
  await adder.click();
  await expect(page.getByRole("menuitem")).toHaveText(["Import lorebooks into the library…"]);
  await item(page, "Import lorebooks into the library…").click();
  await expect(page).toHaveURL(/#\/library\/lorebooks$/);
});

test("a chat without lorebooks shows no Lorebooks in its side panel, and the chat's menu adds one, the panel closed or not", async ({ page, request }) => {
  await add(request, "Harbour");
  const chat = await start(request, "ada");
  await openChat(page, chat);
  await expect(panel(page)).toBeVisible();
  await expect(panel(page).getByRole("heading", { name: "Lorebooks" })).toBeHidden();
  await page.getByRole("button", { name: "Hide side panel" }).click();
  await expect(panel(page)).toBeHidden();

  // "Add a lorebook" of the chat's menu opens the panel, shows the part and opens its "+".
  await page.getByRole("button", { name: "Chat options" }).click();
  await item(page, "Add a lorebook").click();
  await expect(panel(page)).toBeVisible();
  await expect(page.getByRole("menuitem")).toHaveText(["Harbour"]);
  await item(page, "Harbour").click();
  await expect(lorebookLines(page)).toHaveText(["Harbour"]);
  // While the panel shows the part, the menu has no "Add a lorebook".
  await page.getByRole("button", { name: "Chat options" }).click();
  await expect(item(page, "Rename")).toBeVisible();
  await expect(item(page, "Add a lorebook")).toBeHidden();
  await page.keyboard.press("Escape");
});

// A card's page: the lorebooks in its box.

/** A part of the box on a card's page, by its name. */
const boxPart = (page: Page, name: string) => page.locator(".part", { has: page.getByRole("heading", { name, exact: true }) });
const cardLorebooks = (page: Page) => boxPart(page, "Lorebooks").locator(".row:visible");
const attacher = (page: Page) => boxPart(page, "Lorebooks").getByRole("button", { name: "Add a lorebook" });
const noneYet = (page: Page) => boxPart(page, "Lorebooks").getByText("None yet.");

async function openCard(page: Page, who: "tam" | "ada"): Promise<void> {
  await page.goto(`/#/library/${cards[who]}`);
  await expect(button(page, "Character menu")).toBeVisible();
}

/** The names of the library's lorebooks in plain view. */
async function inLibrary(request: APIRequestContext): Promise<string[]> {
  const lorebooks: { name: string; card?: unknown }[] = await (await request.get("/api/lorebooks")).json();
  return lorebooks.filter((lorebook) => !lorebook.card).map((lorebook) => lorebook.name);
}

test("“+” attaches a lorebook of the library to a card, and its × detaches it without deleting it", async ({ page, request }) => {
  await add(request, "Harbour");
  const moor = await add(request, "Moor", [{ name: "Peat", content: "Peat is cut in spring." }]);
  await add(request, "Atlas", HARBOUR, { archived: true });
  await add(request, "Reef", HARBOUR, { trashed: true });
  await openCard(page, "ada");
  // A card without lorebooks shows no part for them: the card menu's "Add a lorebook" shows it, as yet empty, and
  // opens its "+": the library's lorebooks, by name, not the archived one, nor the one in the Trash.
  await expect(boxPart(page, "Lorebooks")).toHaveCount(0);
  await button(page, "Character menu").click();
  // The card menu's lines stand in groups under rules: the chat's, what adds to the character, the card's own, Move to Trash.
  const lines = await page.locator(".pop[role=menu]:visible > *").evaluateAll((all) => all.map((line) => (line.tagName === "HR" ? "rule" : (line.ariaLabel ?? line.textContent))));
  // New chat stands first where an earlier test left the card a chat.
  expect(lines.filter((line) => line !== "New chat")).toEqual(["Add a way to chat…", "Translate the character…", "rule", "Add a lorebook", "Add expressions", "Add a 3D figure", "Add a document", "rule", "Export as card file", "Archive", "rule", "Move to Trash"]);
  await item(page, "Add a lorebook").click();
  await expect(noneYet(page)).toBeVisible();
  await expect(page.getByRole("menuitem")).toHaveText(["Harbour", "Moor"]);
  await item(page, "Harbour").click();
  await expect(cardLorebooks(page)).toHaveText(["Harbour"]);
  await expect(noneYet(page)).toHaveCount(0);
  // The button has the focus again, and no longer offers what the card has.
  await expect(attacher(page)).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem")).toHaveText(["Moor"]);
  await item(page, "Moor").click();
  await expect(cardLorebooks(page)).toHaveText(["Harbour", "Moor"]);
  // They are the card's after a reload, and no other card's.
  await page.reload();
  await expect(cardLorebooks(page)).toHaveText(["Harbour", "Moor"]);
  // With nothing left to attach, the menu leads to the library.
  await attacher(page).click();
  await expect(page.getByRole("menuitem")).toHaveText(["Import lorebooks into the library…"]);
  await page.keyboard.press("Escape");

  // The × shows while its line is pointed at.
  const detach = button(page, "Remove Harbour from this character");
  await expect(detach).toHaveCSS("opacity", "0");
  await cardLorebooks(page).first().hover();
  await expect(detach).toHaveCSS("opacity", "1");
  // What the server refuses is said, and the line stays.
  await page.route("**/api/cards/*/lorebooks/*", (route) => route.fulfill({ status: 409, json: { code: "not_now", error: "the shelf is locked", details: { what: "shelf_locked" } } }));
  await detach.click();
  await expect(page.getByRole("alert")).toHaveText("That cannot be done now. Try again in a moment.");
  await expect(cardLorebooks(page)).toHaveText(["Harbour", "Moor"]);
  await page.unroute("**/api/cards/*/lorebooks/*");

  // Removed, it is gone from the card and still in the library, for the "+" to offer again.
  await detach.click();
  await expect(cardLorebooks(page)).toHaveText(["Moor"]);
  await expect(page.getByRole("alert")).toHaveCount(0);
  await expect(attacher(page)).toBeFocused();
  expect(await inLibrary(request)).toEqual(["Harbour", "Moor"]);
  await page.keyboard.press("Enter");
  await expect(page.getByRole("menuitem")).toHaveText(["Harbour"]);
  await page.keyboard.press("Escape");

  // One that went to the Trash stays the card's until it is deleted for good, and its line says where it is.
  await alter(request, moor, { trashed: true });
  await page.reload();
  await expect(cardLorebooks(page)).toHaveText(["Moor · in Trash"]);
  expect((await request.delete(`/api/lorebooks/${moor}`)).status()).toBe(204);
  await page.reload();
  await expect(boxPart(page, "Lorebooks")).toHaveCount(0);
  // The card menu offers "Add a lorebook" only while the part does not show.
  await button(page, "Character menu").click();
  await expect(item(page, "Add a lorebook")).toBeVisible();
  await page.keyboard.press("Escape");
  await openCard(page, "tam");
  await button(page, "Character menu").click();
  await expect(item(page, "Add a lorebook")).toBeHidden();
  await page.keyboard.press("Escape");
  await expect(cardLorebooks(page)).toHaveText(["River · this character's own"]);
});

test("a lorebook is made one for every chat in its settings, and given to a persona in the persona's form", async ({ page, request }) => {
  const world = await add(request, "World", [{ name: "Sky", content: "The sky is green." }]);
  await add(request, "Moor", [{ name: "Peat", content: "Peat is cut in spring." }]);

  // "Use in every chat", the last line of "Lorebook settings", is kept with Save; the library's row says so.
  await page.goto(`/#/library/lorebooks/${world}`);
  await button(page, "Lorebook settings").click();
  const everywhere = page.getByRole("switch", { name: "Use in every chat" });
  await expect(everywhere).not.toBeChecked();
  await everywhere.check();
  await button(page, "Save").click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.goto("/#/library/lorebooks");
  await expect(row(page, "World")).toContainText("In every chat");
  await expect(row(page, "Moor")).not.toContainText("In every chat");

  // A persona is given Moor in its form, with Save.
  const made = await request.post("/api/personas", { data: { name: "Wanderer" } });
  expect(made.status()).toBe(201);
  const persona: number = (await made.json()).id;
  await page.goto("/#/library/personas");
  await row(page, "Wanderer").hover();
  await row(page, "Wanderer").getByRole("button", { name: "Edit" }).click();
  const form = page.locator(".persona-form");
  await form.getByRole("button", { name: "Add a lorebook" }).click();
  await expect(page.getByRole("menuitem")).toHaveText(["Moor", "World"]);
  await item(page, "Moor").click();
  await expect(form.locator(".persona-lorebooks li")).toHaveText(["Moor"]);
  await button(page, "Save").click();
  await expect(form).toHaveCount(0);

  // A chat as that persona has both beside the card's own, each with its switch, no × and in grey why it is there;
  // one as nobody has World alone.
  const response = await request.post("/api/chats", { data: { characters: [{ version_id: versions.tam, character: "tam" }], persona_id: persona } });
  expect(response.status()).toBe(201);
  await openChat(page, (await response.json()).chat.id);
  await expect(lorebookLines(page)).toHaveText(["River", "World every chat", "Moor persona"]);
  await expect(lorebookLines(page).locator(".meta")).toHaveText(["every chat", "persona"]);
  await expect(lorebook(page, "Moor persona")).toBeChecked();
  await expect(panel(page).getByRole("button", { name: "Remove lorebook Moor from this chat" })).toHaveCount(0);
  await openChat(page, await start(request, "ada"));
  await expect(lorebookLines(page)).toHaveText(["World every chat"]);
});
