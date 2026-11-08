import type { APIRequestContext, Page } from "@playwright/test";
import { expect, linesOf, pickFrom, test } from "../test";
import { cardFile, ccv4File } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// The chat's side panel: who the user is in the chat (a persona chosen, and a new one made there), and the
// chat's lorebooks as switches, of which one switched off stays out of the replies; and a reply's statistics.
//
// One database for the file. Every test starts a chat of its own, with one of the two cards made here. A part
// of the side panel that is hidden is in the page still, so the parts shown are asked for with
// `.panel-label:visible`.
test.describe.configure({ mode: "serial" });

/** A card whose character brings two lorebooks; two of the three entries always apply. */
const FEN = `
spec = "ccv4:1.0.0"

[meta-info]
title = "Wren of the Fen"

[name.wren]
text = "Wren"

[greeting.nets]
text = "Wren looks up from the nets."

[greeting.boat]
text = "Wren ties up the boat."

[lore.heron]
name = "The Grey Heron"
trigger = "always"
keywords = []
text = "A grey heron watches the fen."

[lore.sluice]
keywords = ["sluice"]
text = "The sluice gate is rusted shut."

[lore.eels]
name = "Eel season"
trigger = "always"
keywords = []
text = "The eels run in autumn."

[lorebook.fen]
name = "The Fen"
entries = ["lore.heron", "lore.sluice"]

[lorebook.trade]
name = "Trade"
entries = ["lore.eels"]

[character.wren]
name-card = "Wren"
name-char = "name.wren"
greetings = ["greeting.nets", "greeting.boat"]
lorebooks = ["lorebook.fen", "lorebook.trade"]
prompt = ["name.wren", "LOREBOOK", "CHAT-HISTORY"]
`;

const HERON = "A grey heron watches the fen.";
const EELS = "The eels run in autumn.";

let provider: FakeProvider;
/** The card versions to chat with: Wren has a picture and lorebooks, Moss neither. */
const versions = { wren: 0, moss: 0 };

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  const add = async (file: Buffer): Promise<number> => {
    const response = await request.post("/api/cards", { data: file });
    expect(response.status()).toBe(201);
    return (await response.json()).version_id;
  };
  versions.wren = await add(ccv4File(FEN, [40, 60]));
  versions.moss = await add(cardFile({ name: "Moss Fenwick", first_mes: "Moss nods." }));
});
test.afterAll(() => provider.close());

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });

const messages = (page: Page) => page.locator(".message");
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const panel = (page: Page) => page.getByRole("complementary", { name: "Chat details" });
const persona = (page: Page) => panel(page).getByLabel("Persona", { exact: true });
const lorebook = (page: Page, name: string) => panel(page).getByRole("switch", { name, exact: true });
/** A part of the panel, by its name. */
const part = (page: Page, name: string) => panel(page).locator(".panel-part", { has: page.getByText(name, { exact: true }) });
const used = (page: Page) => part(page, "Used in last reply").locator(".item.used");
const lorebookLines = (page: Page) => part(page, "Lorebooks").locator(".item");

/** Starts a chat with one of the two characters and returns its id. */
async function start(request: APIRequestContext, who: "wren" | "moss"): Promise<number> {
  const character = who === "wren" ? "wren" : "moss-fenwick";
  const response = await request.post("/api/chats", { data: { characters: [{ version_id: versions[who], character }] } });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).chat.id;
}

async function open(page: Page, chat: number): Promise<void> {
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

async function regenerate(page: Page): Promise<void> {
  const count = messages(page).last().locator(".count");
  const before = (await count.count()) ? Number((await count.innerText()).split("/")[1]) : 1;
  await button(page, "Write again").click();
  await expect(count).toHaveText(`${before + 1} / ${before + 1}`);
  await expect(button(page, "Write again")).toBeEnabled();
}

/** The prompt the provider was last given, as one text. */
const lastPrompt = () => provider.asked.at(-1)!.body.messages.map((message: { content: string }) => message.content).join("\n");

const chatOf = async (request: APIRequestContext, chat: number) => (await (await request.get(`/api/chats/${chat}`)).json()) as any;

// The chat itself: icons, the message field, the chat's menu.

test("a reply's (i) opens its statistics: model and provider, response time, context and what was sent", async ({ page, request }) => {
  await open(page, await start(request, "wren"));
  // The greeting no model wrote has none.
  await expect(messages(page).first().getByRole("button", { name: "About this reply" })).toHaveCount(0);
  await say(page, "Hello");
  await messages(page).last().getByRole("button", { name: "About this reply" }).click();
  const box = page.getByRole("dialog", { name: "About this reply" });
  await expect(box.locator(".item-text > .meta")).toHaveText([
    "test-model · A program on this computer",
    /^\d+\.\d s to the first word · \d+\.\d s in all$/,
    /^[\d,]+ of [\d,]+ tokens used · [\d,]+ free$/,
  ]);
  await expect(box.getByRole("progressbar", { name: "How much of what the AI can read is used" })).toBeVisible();
  await expect(box.locator(".item.sent > .item-label")).toHaveText(/^Sent to the AI · [\d,]+ tokens$/);
  await expect(box.locator(".tok > span:first-child")).toHaveText(["Character", "Persona", "Memory", "Lorebook", "Earlier messages"]);
  await box.getByRole("button", { name: "Close", exact: true }).last().click();
  await expect(box).toHaveCount(0);
});

// The side panel.

test("who the user is in the chat is chosen in the side panel, and a new persona is made there", async ({ page, request }) => {
  const chat = await start(request, "wren");
  await open(page, chat);
  const shown = persona(page);
  const mine = messages(page).nth(1).locator(".speaker");
  await expect(linesOf(persona(page))).toHaveText(["User", "New persona…"]);
  await expect(shown).toHaveText("User");
  // No prompt preset made yet: nothing to choose, so the part is not there.
  await expect(panel(page).getByLabel("Prompt preset", { exact: true })).toBeHidden();
  await say(page, "Hello");
  await expect(mine).toHaveText("You");
  expect(lastPrompt()).not.toContain("Ines Fenn");

  // "New persona…" opens a small form; the field goes on showing who the user is until there is another.
  const form = panel(page).locator(".persona-form");
  await expect(form).toBeHidden();
  await pickFrom(persona(page), "New persona…");
  await expect(form).toBeVisible();
  await expect(shown).toHaveText("User");
  await expect(form.getByLabel("Name")).toBeFocused();
  // Cancel makes none and empties the form.
  await form.getByLabel("Name").fill("Nobody");
  await form.getByRole("button", { name: "Cancel" }).click();
  await expect(form).toBeHidden();
  await pickFrom(persona(page), "New persona…");
  await expect(form.getByLabel("Name")).toHaveValue("");
  // A name of spaces is refused in the server's words, and the form stays.
  await form.getByLabel("Name").fill("   ");
  await form.getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("alert")).toHaveText("A persona needs a name.");
  await expect(form).toBeVisible();
  await expect(linesOf(persona(page))).toHaveCount(2);

  // The form outlives what happens in the chat meanwhile.
  await form.getByLabel("Name").fill("  Ines Fenn ");
  await form.getByLabel("Description").fill("A surveyor of the fen.");
  await regenerate(page);
  await expect(form.getByLabel("Name")).toHaveValue("  Ines Fenn ");
  await form.getByRole("button", { name: "Save" }).click();
  await expect(form).toBeHidden();
  await expect(linesOf(persona(page))).toHaveText(["User", "Ines Fenn", "New persona…"]);
  await expect(shown).toHaveText("Ines Fenn");
  // The user's messages go by that name, and the next reply is written for it.
  await expect(mine).toHaveText("Ines Fenn (you)");
  await expect(page.getByRole("alert")).toHaveCount(0);
  const ines = (await chatOf(request, chat)).chat.persona_id;
  expect(ines).toEqual(expect.any(Number));
  await regenerate(page);
  expect(lastPrompt()).toContain("Name: Ines Fenn\nA surveyor of the fen.");

  // A choice the server does not take is not shown as made.
  await page.route("**/api/chats/*/persona", (route) => route.fulfill({ status: 500, json: { code: "internal", error: "no persona today", details: {} } }));
  await pickFrom(persona(page), "User");
  await expect(page.getByRole("alert")).toHaveText("Something went wrong in Cardwave. Try again.");
  await expect(shown).toHaveText("Ines Fenn");
  await expect(mine).toHaveText("Ines Fenn (you)");
  await page.unroute("**/api/chats/*/persona");

  // Back to nobody in particular.
  await pickFrom(persona(page), "User");
  await expect(mine).toHaveText("You");
  await expect(shown).toHaveText("User");
  expect((await chatOf(request, chat)).chat.persona_id).toBeNull();
  // The persona is there for every chat, and the one chosen is shown after a new start.
  await pickFrom(persona(page), "Ines Fenn");
  await expect(mine).toHaveText("Ines Fenn (you)");
  await page.reload();
  await expect(shown).toHaveText("Ines Fenn");
  await expect(mine).toHaveText("Ines Fenn (you)");
  await open(page, await start(request, "moss"));
  await expect(linesOf(persona(page))).toHaveText(["User", "Ines Fenn", "New persona…"]);
  await expect(shown).toHaveText("User");
});

test("a chat's lorebooks are switches, and one switched off stays out of the replies", async ({ page, request }) => {
  const chat = await start(request, "wren");
  await open(page, chat);
  // Code mode's among them.
  await expect(panel(page).getByRole("switch")).toHaveCount(4);
  await expect(lorebookLines(page)).toHaveText(["The Fen", "Trade"]);
  await expect(lorebook(page, "The Fen")).toBeChecked();
  await expect(lorebook(page, "Trade")).toBeChecked();
  // Before any reply nothing was given to one, and "Used in last reply" does not show.
  await expect(page.getByRole("heading", { name: "Used in last reply" })).toBeHidden();
  await expect(used(page)).toHaveCount(0);

  const fen = await lorebook(page, "The Fen").elementHandle();
  await say(page, "Hello");
  expect(lastPrompt()).toContain(HERON);
  expect(lastPrompt()).toContain(EELS);
  await expect(used(page)).toHaveText(["Entry of The FenThe Grey Heron", "Entry of TradeEel season"]);
  // A part that shows what it showed is left as it is.
  expect(await fen!.evaluate((node) => node.isConnected)).toBe(true);

  // Switched off with the keyboard: the switch moves, keeps the focus, and the next reply goes without the lorebook.
  await lorebook(page, "Trade").focus();
  await page.keyboard.press("Space");
  await expect(lorebook(page, "Trade")).not.toBeChecked();
  await expect(lorebook(page, "Trade")).toBeFocused();
  await expect(lorebook(page, "The Fen")).toBeChecked();
  // What the last reply was given is still what it was given.
  await expect(used(page)).toHaveCount(2);
  await regenerate(page);
  expect(lastPrompt()).toContain(HERON);
  expect(lastPrompt()).not.toContain(EELS);
  await expect(used(page)).toHaveText(["Entry of The FenThe Grey Heron"]);
  // The version before shows what that one was given.
  await messages(page).last().getByRole("button", { name: "Previous version" }).click();
  await expect(used(page)).toHaveCount(2);

  // It is the chat's, so it is there after a new start; another chat with the card has its own.
  await page.reload();
  await expect(lorebook(page, "Trade")).not.toBeChecked();
  await expect(lorebook(page, "The Fen")).toBeChecked();
  const other = await start(request, "wren");
  expect((await chatOf(request, other)).lorebooks.map((book: { on: boolean }) => book.on)).toEqual([true, true]);

  // A switch the server does not take stays where it was.
  await page.route("**/api/chats/*/lore", (route) => route.fulfill({ status: 500, json: { code: "internal", error: "no lore today", details: {} } }));
  await lorebook(page, "Trade").click();
  await expect(page.getByRole("alert")).toHaveText("Something went wrong in Cardwave. Try again.");
  await expect(lorebook(page, "Trade")).not.toBeChecked();
  await page.unroute("**/api/chats/*/lore");
  await lorebook(page, "Trade").click();
  await expect(lorebook(page, "Trade")).toBeChecked();
  await expect(page.getByRole("alert")).toHaveCount(0);
  await regenerate(page);
  expect(lastPrompt()).toContain(EELS);
});

test("a click chooses a reply, whose part of the side panel shows what it was given; a second click or Escape goes back to the newest", async ({ page, request }) => {
  await open(page, await start(request, "wren"));
  await say(page, "Hello");
  await lorebook(page, "Trade").click();
  await expect(lorebook(page, "Trade")).not.toBeChecked();
  await say(page, "Again");
  await expect(used(page)).toHaveText(["Entry of The FenThe Grey Heron"]);
  // The panel counts no tokens: those are the reply's statistics'.
  await expect(part(page, "Used in last reply").getByText(/tokens/)).toHaveCount(0);
  // Its grey line says how to see another reply's, and goes while one is chosen; a lorebook's switch says what it does.
  const hint = part(page, "Used in last reply").getByText("Click a reply to see what it used.");
  await expect(hint).toBeVisible();
  await expect(lorebook(page, "Trade")).toHaveAttribute("title", "Use in this chat");

  // The greeting, "Hello", then the first reply.
  const first = messages(page).nth(2);
  await first.locator(".text").click();
  await expect(first).toHaveClass(/chosen/);
  await expect(panel(page).getByText("Click a reply to see what it used.")).toBeHidden();
  await expect(part(page, "Used in this reply").locator(".item.used")).toHaveText(["Entry of The FenThe Grey Heron", "Entry of TradeEel season"]);
  await first.locator(".text").click();
  await expect(page.locator(".message.chosen")).toHaveCount(0);
  await expect(used(page)).toHaveText(["Entry of The FenThe Grey Heron"]);
  await first.locator(".text").click();
  await expect(part(page, "Used in this reply")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator(".message.chosen")).toHaveCount(0);
  await expect(used(page)).toHaveText(["Entry of The FenThe Grey Heron"]);
});

// The two layouts.
