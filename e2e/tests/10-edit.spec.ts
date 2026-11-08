import type { APIRequestContext, Locator, Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { ccv4File } from "../card";

// A card's page is where it is written: a text, the title, the tags and the lines under About are edited
// where they stand and saved on leaving, each text a new draft, a prompt the card has no block for too; a text's
// clock lists its drafts, one gone back to being the text again as "Restored", a greeting deleted
// too; a text's AI tools show the pretend model's change inside it, kept as a draft or undone, and Stop leaves it
// as it was; a character's talkativeness is a whole percentage, which keeps the card's own more exact value while it
// is not changed; at 600 px the side column is one grey line; the Details view (the view menu's) shows the texts as
// lines, each cut to three, and is remembered. What the page sends is tested here, as no module
// test reaches web/src/views/character.ts.
//
// One database for the file. Every test makes its own card and looks at that one only. `leave` takes the focus
// out of what is written, as a click elsewhere does, and `saved` waits for what the server then holds.
test.describe.configure({ mode: "serial" });

const DESCRIPTION = "Guinivere is the queen's sworn sword. {{char}} keeps her own counsel.";
const SCENARIO = "The court is at feast. {{user}} has just arrived.";
const EXAMPLE = "<START>\n{{user}}: Is the queen safe?\n{{char}}: While I stand.";
/** The second block of Guinivere's description, under an ID too long for one line of a narrow window. */
const MAIL = "wardrobe.a_coat_of_dark_mail_worn_under_a_grey_cloak_in_every_weather_and_every_season_of_the_year";

/**
 * The card "The Royal Protector": Guinivere, whose description is two blocks
 * and who has three greetings, and who has no system prompt.
 */
function file(title: string, description = DESCRIPTION): Buffer {
  const text = (words: string) => JSON.stringify(words);
  return ccv4File(`
spec = "ccv4:1.0.0"

[meta-info]
title = ${text(title)}
tags = ["knight", "court intrigue"]
creator = "Erin"

[name.guin]
text = "Guinivere"

[description.guin]
text = ${text(description)}

[${MAIL}]
text = "A coat of dark mail."

[personality.guin]
text = "Dry, watchful."

[scenario.court]
text = ${text(SCENARIO)}

[dialogue-example.guin]
text = ${text(EXAMPLE)}

[greeting.one]
text = "You are late, {{user}}."

[greeting.two]
text = "The hall is empty."

[greeting.three]
text = "Draw, then."

[creator-note.guin]
text = "Works best with long replies."

[character.guin]
name-card = "Guinivere"
name-char = "name.guin"
greetings = ["greeting.one", "greeting.two", "greeting.three"]
creator-note = "creator-note.guin"
prompt = ["name.guin", "description.guin", "${MAIL}", "personality.guin", "scenario.court", "dialogue-example.guin", "CHAT-HISTORY"]
`);
}

/** Makes the card, past the page. Returns its id. */
async function make(request: APIRequestContext, title: string, description?: string): Promise<number> {
  const response = await request.post("/api/cards", { data: file(title, description) });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).card_id;
}

/** A card's texts as written, past the page. */
interface Text {
  reference: string | null;
  text: string;
}
interface Form {
  version: number;
  title: string;
  tags: string[];
  creator: string;
  characters: {
    label: string;
    name: string;
    greetings: Text[];
    personality: Text[];
    scenario: Text[];
    system_prompt: Text[];
    talkativeness: number;
  }[];
}
const form = async (request: APIRequestContext, card: number): Promise<Form> => (await request.get(`/api/cards/${card}/edit`)).json();

/** Waits until the server holds what `read` reads of the card as `value`. */
const saved = <T>(request: APIRequestContext, card: number, read: (form: Form) => T, value: T) =>
  expect.poll(async () => read(await form(request, card))).toEqual(value);

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const field = (page: Page, name: string) => page.getByRole("textbox", { name, exact: true });
const toast = (page: Page) => page.locator("#toast");
/** A text of the card on its page, by its name. */
const part = (page: Page, name: string) => page.locator(".reading section.tb", { has: page.getByRole("heading", { name, exact: true }) });
/** What a text shows while not written in. */
const shows = (page: Page, name: string) => part(page, name).locator(".tb-body");
/** The side column's lines, under Tags and About. */
const lines = (page: Page) => page.locator(".side > div:not(.facts) p").evaluateAll((all) => all.map((one) => (one as HTMLElement).innerText.split("\n")).flat());
/** Takes the focus out of what is written in place, which saves it. */
const leave = (written: Locator) => written.evaluate((node) => (node as HTMLElement).blur());

/** Opens the card's page and waits for its texts. */
async function open(page: Page, card: number): Promise<void> {
  await page.goto(`/#/library/${card}`);
  await expect(part(page, "Personality")).toBeVisible();
}

test("a text, the title, the tags and the lines under About are written where they stand and saved on leaving", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const card = await make(request, "Protector: written");
  await open(page, card);
  await expect(page.locator(".hero h1")).toHaveText("Protector: written");
  expect(await lines(page)).toEqual(["knight", "court intrigue", "Plays Guinivere", "by Erin"]);
  await expect(page.locator(".side .facts p")).toHaveText(/^[\d,]+ tokens$/);
  // No Edit and no clock in the head: the card menu has the rest.
  await expect(button(page, "Edit")).toHaveCount(0);
  await expect(page.locator(".hero-acts").getByRole("button", { name: "Character menu" })).toBeVisible();

  // A text shows its Markdown rendered; a click shows it as written, on the faint fill.
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful.");
  let saves = 0;
  page.on("request", (sent) => (saves += Number(sent.method() === "PUT" && !sent.url().includes("/api/unsaved/"))));
  await shows(page, "Personality").click();
  const personality = field(page, "Personality");
  await expect(personality).toBeFocused();
  await expect(personality).toHaveValue("Dry, watchful.");
  await expect(part(page, "Personality")).toHaveClass(/is-edit/);
  // Left as it was, it is saved as nothing.
  await leave(personality);
  await expect(part(page, "Personality")).not.toHaveClass(/is-edit/);
  await shows(page, "Personality").click();
  await personality.fill("**Dry.**\nWatchful.");
  await leave(personality);
  await expect(shows(page, "Personality").locator("strong")).toHaveText("Dry.");
  await expect(shows(page, "Personality")).toHaveText("Dry.Watchful.");
  await saved(request, card, (edit) => edit.characters[0].personality[0].text, "**Dry.**\nWatchful.");
  expect(saves).toBe(1);

  // A text of two blocks is two texts, told apart by their blocks; macros are shown as written.
  await expect(part(page, "Description · description.guin").locator(".md")).toHaveText(DESCRIPTION.replace("{{char}}", "Guinivere"));
  await expect(part(page, `Description · ${MAIL}`).locator(".md")).toHaveText("A coat of dark mail.");

  // The title, the tags, the creator and the character's name, each where it stands.
  await page.locator(".hero h1").click();
  await field(page, "Title").fill("Protector, written");
  await field(page, "Title").press("Enter");
  await expect(page.locator(".crumbs")).toHaveText("Characters/Protector, written");
  await page.locator(".side p").first().click();
  await expect(field(page, "Tags, separated by commas")).toHaveValue("knight, court intrigue");
  await field(page, "Tags, separated by commas").fill("knight, feast , ,slow burn");
  await field(page, "Tags, separated by commas").press("Enter");
  await page.locator(".side").getByText("Erin", { exact: true }).click();
  await field(page, "Creator").fill("");
  await field(page, "Creator").press("Enter");
  await page.locator(".side").getByText("Guinivere", { exact: true }).click();
  await field(page, "Name in the chat").fill("Guin");
  await field(page, "Name in the chat").press("Enter");
  await saved(request, card, (edit) => [edit.title, edit.tags, edit.creator, edit.characters[0].name], ["Protector, written", ["knight", "feast", "slow burn"], "", "Guin"]);
  // Escape takes a line back.
  await page.locator(".hero h1").click();
  await field(page, "Title").fill("Something else");
  await field(page, "Title").press("Escape");
  await expect(page.locator(".hero h1")).toHaveText("Protector, written");
  // The page shows the card as saved, edited today.
  await expect.poll(() => lines(page)).toEqual(["knight", "feast", "slow burn", "Plays Guin", "by creator", expect.stringMatching(/^edited /)]);

  // The old editor's address opens the page.
  await page.goto(`/#/library/${card}/edit/1`);
  await expect(shows(page, "Scenario")).toHaveText(SCENARIO.replace("{{user}}", "User"));
  // A text the character has no block for is empty, and asks for its words; it has nothing for the AI tools.
  await expect(shows(page, "Instructions for the AI")).toHaveText("Empty · instructions the AI follows in every chat");
  await expect(button(page, "AI tools for Instructions for the AI")).toBeDisabled();
  // Written, it is a prompt of the card.
  await shows(page, "Instructions for the AI").click();
  await field(page, "Instructions for the AI").fill("Keep to the court's voice.");
  await leave(field(page, "Instructions for the AI"));
  await saved(request, card, (edit) => edit.characters[0].system_prompt.map((one) => one.text), ["Keep to the court's voice."]);
});

test("a text's clock lists its drafts, and one gone back to is the text again, a deleted greeting too", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const card = await make(request, "Protector: drafts");
  await open(page, card);
  await shows(page, "Personality").click();
  await field(page, "Personality").fill("Dry, watchful, exact.");
  await leave(field(page, "Personality"));
  await saved(request, card, (edit) => edit.characters[0].personality[0].text, "Dry, watchful, exact.");

  const clock = button(page, "Earlier versions of Personality");
  const list = page.getByRole("menu", { name: "Earlier versions of Personality" });
  await part(page, "Personality").hover();
  await clock.click();
  await expect(list.locator(".l1")).toHaveText(["Now", "Imported"]);
  await expect(list.locator(".sub").first()).toHaveText(/^Edited by you · /);
  // A draft pressed shows against the text: what would come back, and what would go.
  await list.getByRole("menuitem").nth(1).click();
  await expect(shows(page, "Personality").locator("del")).toHaveText("watchful, exact.");
  await expect(shows(page, "Personality").locator("ins")).toHaveText("watchful.");
  await expect(part(page, "Personality").locator(".tb-foot .meta")).toHaveText(/^Version of /);
  // Escape shows the text as it is.
  await page.keyboard.press("Escape");
  await expect(list).toHaveCount(0);
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful, exact.");
  await expect(clock).toBeFocused();

  await clock.click();
  await list.getByRole("menuitem").nth(1).click();
  await button(page, "Restore this version").click();
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful.");
  await saved(request, card, (edit) => edit.characters[0].personality[0].text, "Dry, watchful.");
  await clock.click();
  await expect(list.locator(".l1")).toHaveText(["Now", "Edited by you", "Imported"]);
  await expect(list.locator(".sub").first()).toHaveText(/^Restored · /);
  await page.keyboard.press("Escape");

  // A greeting deleted comes back from any greeting's clock.
  const first = part(page, "First message");
  await expect(first.locator(".count")).toHaveText("1 / 3");
  await button(page, "Next first message").click();
  await expect(first.locator(".count")).toHaveText("2 / 3");
  await first.hover();
  await button(page, "Delete this first message").click();
  await expect(toast(page)).toHaveText(/^First message deleted\./);
  // The greeting after it takes its place.
  await expect(first.locator(".count")).toHaveText("2 / 2");
  await expect(shows(page, "First message")).toHaveText("Draw, then.");
  await saved(request, card, (edit) => edit.characters[0].greetings.map((one) => one.text), ["You are late, {{user}}.", "Draw, then."]);
  await first.hover();
  await button(page, "Earlier versions of First message").click();
  const greetings = page.getByRole("menu", { name: "Earlier versions of First message" });
  await greetings.getByRole("menuitem", { name: /^Deleted first message/ }).click();
  await expect(first.locator("ins")).toHaveText("The hall is empty.");
  await button(page, "Restore this version").click();
  await expect(first.locator(".count")).toHaveText("3 / 3");
  await expect(shows(page, "First message")).toHaveText("The hall is empty.");
  await saved(request, card, (edit) => edit.characters[0].greetings.length, 3);

  // "+" adds a greeting, written at once and saved on leaving.
  await button(page, "Add a first message").click();
  await expect(field(page, "First message")).toBeFocused();
  await field(page, "First message").fill("Hail.");
  await leave(field(page, "First message"));
  await expect(first.locator(".count")).toHaveText("4 / 4");
  await saved(request, card, (edit) => edit.characters[0].greetings.map((one) => one.text).at(-1), "Hail.");
});

test("a character's talkativeness is a whole percentage, kept as exact as the card has it until changed", async ({ page, request }) => {
  const card = await make(request, "Protector: talkative");
  await open(page, card);
  // A card that says nothing has 50, as it counts; it is the character's last text, with what it does.
  await expect(page.locator(".reading > section").last()).toHaveText(/^How often they speak in a group chat50 % · how readily the character replies in a chat of several where a random one replies$/);
  // One more exact than a whole percentage.
  const edit = await form(request, card);
  edit.characters[0].talkativeness = 0.333;
  expect((await request.put(`/api/cards/${card}/edit`, { data: edit })).status()).toBe(200);
  await page.reload();
  await expect(part(page, "Personality")).toBeVisible();
  const talk = () => field(page, "How often they speak in a group chat, in percent, from 0 to 100");
  await shows(page, "How often they speak in a group chat").click();
  await expect(talk()).toHaveValue("33");
  let saves = 0;
  page.on("request", (sent) => (saves += Number(sent.method() === "PUT" && !sent.url().includes("/api/unsaved/"))));
  // A number that is no whole one from 0 to 100 is not saved, and the text shows what it was.
  for (const wrong of ["101", "-1", "12.5", ""]) {
    await talk().fill(wrong);
    await talk().press("Enter");
    await expect(shows(page, "How often they speak in a group chat")).toHaveText(/^33 % /);
    await shows(page, "How often they speak in a group chat").click();
  }
  // Typed back to what it shows, it is what the card had: no change.
  await talk().fill("33");
  await talk().press("Enter");
  expect(saves).toBe(0);
  await shows(page, "How often they speak in a group chat").click();
  await talk().fill("0");
  await talk().press("Enter");
  await saved(request, card, (edit) => edit.characters.map((one) => one.talkativeness), [0]);
});

test("at 600 px the side column is one grey line under the buttons, and a text's drafts open inside the window", async ({ page, request }) => {
  await page.setViewportSize({ width: 600, height: 900 });
  const card = await make(request, "Protector: narrow");
  await open(page, card);
  await expect(page.locator(".fold-line")).toHaveText(/^Plays Guinivere · by Erin · knight, court intrigue · [\d,]+ tokens$/);
  await expect(page.locator(".side")).toBeHidden();
  await button(page, "Earlier versions of Personality").click();
  const list = page.getByRole("menu", { name: "Earlier versions of Personality" });
  const box = await list.boundingBox();
  expect(box!.x + box!.width).toBeLessThanOrEqual(600);
});

test("a text's AI tools show the background model's change inside it, kept or undone, and a kept one is a draft", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status(), await provider.text()).toBe(200);
  const card = await make(request, "Protector: AI tools");
  await open(page, card);
  const personality = part(page, "Personality");
  const tools = button(page, "AI tools for Personality");
  const menu = page.getByRole("menu", { name: "AI tools for Personality" });
  const foot = personality.locator(".tb-foot");
  await personality.hover();
  await tools.click();
  await expect(menu.getByRole("menuitem")).toHaveText(["Improve the writing", "Fix grammar and spelling", "Make it shorter", "Make it longer", "Translate…", "Ask for a change…"]);
  // The menu stands beside the text, covering none of it, and ends at the page's right margin, where its rule ends.
  const [menuBox, textBox, rule] = [await menu.boundingBox(), await shows(page, "Personality").boundingBox(), await page.locator("header.pbar").boundingBox()];
  expect(menuBox!.x).toBeGreaterThanOrEqual(textBox!.x + textBox!.width);
  expect(menuBox!.x + menuBox!.width).toBeCloseTo(rule!.x + rule!.width, 0);

  // While the model writes, the text is grey and Stop leaves it as it was.
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route("**/api/rewrite", async (route) => {
    await held;
    await route.fallback();
  });
  await menu.getByRole("menuitem", { name: "Improve the writing" }).click();
  await expect(menu).toHaveCount(0);
  await expect(foot.locator(".meta")).toHaveText("Improving the writing…");
  await expect(personality.locator(".working")).toBeVisible();
  await button(page, "Stop").click();
  await expect(foot).toBeHidden();
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful.");
  release();
  await page.unroute("**/api/rewrite");

  // The change shows inside the text: words taken out struck through, new ones marked. Undo leaves the text.
  await personality.hover();
  await tools.click();
  await menu.getByRole("menuitem", { name: "Make it longer" }).click();
  await expect(shows(page, "Personality").locator("del")).toHaveText("Dry, watchful.");
  await expect(shows(page, "Personality").locator("ins")).toHaveText(/^This is Cardwave's pretend model\./);
  await expect(foot.locator(".meta")).toHaveText("Make it longer · 1 change");
  await button(page, "Undo").click();
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful.");

  // Translate… asks for the language in the menu, sent with Enter; Keep saves the change as a draft.
  await personality.hover();
  await tools.click();
  await menu.getByRole("menuitem", { name: "Translate…" }).click();
  const asked = page.waitForRequest("**/api/rewrite");
  await field(page, "Into which language?").fill("German");
  await field(page, "Into which language?").press("Enter");
  expect((await asked).postDataJSON()).toMatchObject({ tool: "translate", given: "German", what: "Personality", text: "Dry, watchful." });
  await expect(foot.locator(".meta")).toHaveText("Translated into German · 1 change");
  // The kept change shows while it is being saved.
  let saving = () => {};
  const unsaved = new Promise<void>((done) => (saving = done));
  await page.route("**/api/cards/*/edit*", async (route) => {
    if (route.request().method() === "PUT") await unsaved;
    await route.fallback();
  });
  await button(page, "Keep").click();
  await expect(shows(page, "Personality")).toHaveText(/^This is Cardwave's pretend model\./);
  saving();
  await page.unroute("**/api/cards/*/edit*");
  await saved(request, card, (edit) => edit.characters[0].personality[0].text.startsWith("This is Cardwave's pretend model."), true);
  await personality.hover();
  await button(page, "Earlier versions of Personality").click();
  await expect(page.getByRole("menu", { name: "Earlier versions of Personality" }).locator(".sub").first()).toHaveText(/^Translated · /);
});

test("the whole card's AI tools change its texts one after the other, each kept or undone inside it, or all at once", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status(), await provider.text()).toBe(200);
  const card = await make(request, "Protector: the whole card");
  await open(page, card);
  const sparkle = button(page, "AI tools for the character");
  const menu = page.locator(".hero-acts");
  const line = page.locator(".card-ai");
  await sparkle.click();
  await expect(menu.getByRole("menuitem")).toHaveText(["Improve the writing", "Fix grammar and spelling", "Make it shorter", "Make it longer", "Translate…", "Ask for a change…"]);

  // The texts with words are asked of one after the other; those still to come are grey meanwhile.
  const asked: Record<string, unknown>[] = [];
  let release = () => {};
  const held = new Promise<void>((done) => (release = done));
  await page.route("**/api/rewrite", async (route) => {
    asked.push(route.request().postDataJSON());
    if (asked.length === 3) await held;
    await route.fallback();
  });
  await menu.getByRole("menuitem", { name: "Improve the writing" }).click();
  // The pretend model takes about a second a text.
  await expect(line).toHaveText(/^Improving the writing… · 3 of 9 texts\s*Stop$/, { timeout: 10_000 });
  await expect(part(page, "Personality").locator(".working")).toBeVisible();
  await expect(sparkle).toBeDisabled();
  // A change kept while the others are still being made leaves the line as it is, Stop too.
  await part(page, "First message").getByRole("button", { name: "Keep", exact: true }).click();
  await expect(shows(page, "First message")).toHaveText(/^This is Cardwave's pretend model\./);
  await expect(line).toHaveText(/^Improving the writing… · 3 of 9 texts\s*Stop$/);
  release();
  await expect(line).toContainText("8 texts changed by AI", { timeout: 20_000 });
  expect(asked.map((one) => one.what)).toEqual(["First message", "First message", "First message", "Description · description.guin", `Description · ${MAIL}`, "Personality", "Scenario", "Example dialogue", "Creator notes"]);
  expect(asked.every((one) => one.tool === "improve")).toBe(true);
  expect(asked[5].card).toEqual({ name: "Guinivere", description: `${DESCRIPTION}\n\nA coat of dark mail.`, personality: "Dry, watchful.", scenario: SCENARIO });

  // Each change shows inside its text with its own Keep and Undo.
  const personality = part(page, "Personality");
  await expect(shows(page, "Personality").locator("del")).toHaveText("Dry, watchful.");
  await expect(personality.locator(".tb-foot .meta")).toHaveText("Improve the writing · 1 change");
  await personality.getByRole("button", { name: "Undo", exact: true }).click();
  await expect(shows(page, "Personality")).toHaveText("Dry, watchful.");
  await expect(line).toContainText("7 texts changed by AI");

  // The text's own tool asks just as the whole card's did.
  await personality.hover();
  await button(page, "AI tools for Personality").click();
  const alone = page.waitForRequest("**/api/rewrite");
  await page.getByRole("menu", { name: "AI tools for Personality" }).getByRole("menuitem", { name: "Improve the writing" }).click();
  expect((await alone).postDataJSON()).toEqual(asked[5]);
  await personality.getByRole("button", { name: "Undo", exact: true }).click();

  await part(page, "Scenario").getByRole("button", { name: "Keep", exact: true }).click();
  await expect(shows(page, "Scenario")).toHaveText(/^This is Cardwave's pretend model\./);
  await saved(request, card, (edit) => edit.characters[0].scenario[0].text.startsWith("This is Cardwave's pretend model."), true);
  await expect(line).toContainText("6 texts changed by AI");

  // Undo all leaves every other text as it was.
  await button(page, "Undo all").click();
  await expect(line).toBeHidden();
  await expect(shows(page, "Creator notes")).toHaveText("Works best with long replies.");
  await expect(sparkle).toBeEnabled();
  await page.unroute("**/api/rewrite");

  // "Ask for a change…" asks in the line first; Keep all saves every change in one save, the sparkle grey until
  // it is saved, each text's draft named after the tool.
  await sparkle.click();
  await menu.getByRole("menuitem", { name: "Ask for a change…" }).click();
  const kinder = page.waitForRequest("**/api/rewrite");
  await field(page, "What should change?").fill("Make her kinder");
  await field(page, "What should change?").press("Enter");
  expect((await kinder).postDataJSON()).toMatchObject({ tool: "ask", given: "Make her kinder", what: "First message" });
  await expect(line).toContainText("texts changed by AI", { timeout: 20_000 });
  let saving = () => {};
  const unsaved = new Promise<void>((done) => (saving = done));
  await page.route("**/api/cards/*/edit*", async (route) => {
    if (route.request().method() === "PUT") await unsaved;
    await route.fallback();
  });
  await button(page, "Keep all changes").click();
  await expect(line).toBeHidden();
  await expect(sparkle).toBeDisabled();
  saving();
  await expect(sparkle).toBeEnabled();
  await page.unroute("**/api/cards/*/edit*");
  await saved(request, card, (edit) => [edit.characters[0].personality[0].text, edit.characters[0].greetings[2].text].every((text) => text.startsWith("This is Cardwave's pretend model.")), true);
  await expect(shows(page, "Personality")).toHaveText(/^This is Cardwave's pretend model\./);
  await personality.hover();
  await button(page, "Earlier versions of Personality").click();
  await expect(page.getByRole("menu", { name: "Earlier versions of Personality" }).locator(".sub").first()).toHaveText(/^Changed as asked · /);
});

test("the Details view: chosen in the view menu and remembered, its texts as lines cut to three, written where they stand", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const long = Array.from({ length: 8 }, (_, at) => `Paragraph ${at + 1} of a long description, of the court and the oath she keeps.`).join("\n\n");
  const card = await make(request, "Protector: details", long);
  await open(page, card);
  await chooseView(page, "Details");
  await expect(page.locator(".hero")).toHaveCount(0);
  // The picture and the box at the left (here empty, so hidden); at the right one grey line of facts and the tags as chips.
  await expect(page.locator(".cdv-side .gbox")).toHaveCount(1);
  await expect(page.locator(".cdv-facts")).toHaveText(/^Plays Guinivere · by Erin( · edited [^·]+)? · [\d,]+ tokens$/);
  await expect(page.locator(".cdv-tags .pill")).toHaveText(["knight", "court intrigue"]);
  // Each text a line, its name in the left column; a long one shows three lines until "Show all".
  const line = (name: string) => page.locator(".cdv-texts section.tb", { has: page.getByRole("heading", { name, exact: true }) });
  await expect(line("First message").getByRole("button", { name: "Add a first message" })).toBeVisible();
  const description = line("Description · description.guin");
  await expect.poll(() => description.locator(".md").evaluate((md) => md.scrollHeight > md.clientHeight + 1 && md.clientHeight < 80)).toBe(true);
  await description.getByRole("button", { name: "Show all" }).click();
  await expect(description.getByRole("button", { name: "Show all" })).toBeHidden();
  // A text, the tags and the creator are written where they stand, as in Showcase.
  await line("Personality").locator(".tb-body").click();
  await field(page, "Personality").fill("Exact.");
  await leave(field(page, "Personality"));
  await saved(request, card, (edit) => edit.characters[0].personality[0].text, "Exact.");
  await page.locator(".cdv-tags").click();
  await field(page, "Tags, separated by commas").fill("knight, feast");
  await field(page, "Tags, separated by commas").press("Enter");
  await page.locator(".cdv-facts").getByText("Erin", { exact: true }).click();
  await field(page, "Creator").fill("Mara");
  await field(page, "Creator").press("Enter");
  await saved(request, card, (edit) => [edit.tags, edit.creator], [["knight", "feast"], "Mara"]);
  // Remembered: the page opened again is in Details; Showcase brings the first view back.
  await page.reload();
  await expect(line("Personality")).toBeVisible();
  await chooseView(page, "Showcase");
  await expect(part(page, "Personality")).toBeVisible();
  await expect(page.locator(".cdv")).toHaveCount(0);
});
