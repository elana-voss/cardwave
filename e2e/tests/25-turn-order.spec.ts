import type { APIRequestContext, Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Who replies in a chat of several characters: the one named, and a turn order chosen, which is kept with its
// chat, and by "New chat with these characters" of the chat's menu, which renames it too; and the characters
// replying by themselves with the side panel's pause and count, which leaving their chat ends. The chat's title is
// written where it stands in the header: by the menu's Rename, and by a click on it in a chat of one.
//
// One database for the file. Its cards are made once, a card holds one character, and every test starts a chat
// of its own with the three characters, Wren, who greets, Odalys and Pike (`start`). `say` and `more` tell who wrote the reply,
// `turn` reads the chat's turn past the page, and `sent` notes what the page sends to an address. Who replies
// is the pill over the message field (`replier`), whose words say the choice; `lines` are the lines of its
// menu, which are in the page while it is shut too, and `choose` opens it and picks one.

const TITLE = "Tarnwater Crew";
/** The characters in speaking order, each of a card of its own. The first greets. */
const NAMES = ["Wren", "Odalys", "Pike"];

/** What the pill and the menu of who replies call the turn orders, the first being the one a chat starts with, and what the pill says of each when pointed at. */
const NAMED = "Whoever is named replies";
const IN_TURN = "Each replies in turn";
const RANDOM = "A random one replies";
const MEANS = {
  [NAMED]: "The character named in the newest messages replies, and where none is named, one of the others by chance.",
  [IN_TURN]: "The characters reply one after the other, in the order the side panel lists them.",
  [RANDOM]: "One of the characters replies by chance, and not the one who spoke last.",
};

/** The card of the character `name`, the `at`th of `NAMES`. */
function file(name: string, at: number): Buffer {
  const id = name.toLowerCase();
  const greeting = at === 0 ? `\n[greeting.${id}]\ntext = "${name} looks up."\n` : "";
  const block = `
[name.${id}]
text = "${name}"
${greeting}
[character.${id}]
name-card = "${name}"
name-char = "name.${id}"
greetings = [${at === 0 ? `"greeting.${id}"` : ""}]
prompt = ["name.${id}", "CHAT-HISTORY"]
`;
  return ccv4File(`spec = "ccv4:1.0.0"\n\n[meta-info]\ntitle = "${TITLE}: ${name}"\n${block}`, [40, 60]);
}

let provider: FakeProvider;
/** Each card's newest version, by its character's name. */
const versions: Record<string, number> = {};

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  // The cards once, also where a test that failed has the tests after it start anew.
  for (const [at, name] of NAMES.entries()) {
    const found = async () => (await (await request.get(`/api/cards?q=${encodeURIComponent(`${TITLE}: ${name}`)}`)).json())[0];
    if (!(await found())) {
      const made = await request.post("/api/cards", { data: file(name, at) });
      expect(made.status(), await made.text()).toBe(201);
    }
    versions[name] = (await found()).version_id;
  }
});
test.afterAll(() => provider.close());

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const messages = (page: Page) => page.locator(".message:not(.asked)");
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
/** Who replies: the pill over the message field, which says the choice. */
const replier = (page: Page) => page.getByRole("button", { name: /^Who replies/ });
/** The lines of its menu, open or shut. */
const lines = (page: Page) => page.locator('.replier [role="menuitemradio"]');
/** Opens the menu of who replies and picks the line called so: an order, or a character. */
async function choose(page: Page, called: string): Promise<void> {
  await replier(page).click();
  await lines(page).filter({ hasText: called }).click();
}
const speakers = (page: Page) => messages(page).locator(".speaker");
/** A character's line in the menu of who replies. */
const always = (page: Page, name: string) => lines(page).filter({ hasText: name });
const box = async (locator: Locator) => (await locator.boundingBox())!;

/** Starts a chat with the three characters, past the page. Returns its id. */
async function start(request: APIRequestContext): Promise<number> {
  const data = { characters: NAMES.map((name) => ({ version_id: versions[name], character: name.toLowerCase() })) };
  const response = await request.post("/api/chats", { data });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).chat.id;
}

/** The chat's turn as the server has it: its order, and the name of the character picked by hand. */
async function turn(request: APIRequestContext, chat: number): Promise<[order: string, picked: string | null]> {
  const view = await (await request.get(`/api/chats/${chat}`)).json();
  const picked = view.characters.find((one: { id: number }) => one.id === view.chat.replier_id);
  return [view.chat.turn_order, picked?.name ?? null];
}

/** What the server calls the chat. */
const titleOf = async (request: APIRequestContext, chat: number) => (await (await request.get(`/api/chats/${chat}`)).json()).chat.title;

test("a click on the chat's title in its header writes it there: Escape takes it back, leaving saves", async ({ page, request }) => {
  const data = { characters: [{ version_id: versions.Wren, character: "wren" }] };
  const made = await request.post("/api/chats", { data });
  expect(made.status(), await made.text()).toBe(201);
  const chat = (await made.json()).chat.id;
  expect((await request.put(`/api/chats/${chat}/title`, { data: { title: "Harbour" } })).status()).toBe(200);
  await page.goto(`/#/chats/${chat}`);
  const line = page.locator(".chat-bar h1 .meta");
  await expect(line).toHaveText("Harbour");

  await line.click();
  const title = page.locator(".chat-bar h1").getByLabel("Chat title");
  await expect(title).toHaveValue("Harbour");
  await title.fill("Dockside");
  await title.press("Escape");
  await expect(line).toHaveText("Harbour");
  expect(page.url()).toMatch(new RegExp(`#/chats/${chat}$`));

  await line.click();
  await title.fill("Dockside");
  await composer(page).click();
  await expect(line).toHaveText("Dockside");
  expect(await titleOf(request, chat)).toBe("Dockside");
  expect(page.url()).toMatch(new RegExp(`#/chats/${chat}$`));
});

async function open(page: Page, chat: number): Promise<void> {
  await page.goto(`/#/chats/${chat}`);
  await expect(messages(page).first()).toBeVisible();
  await expect(replier(page)).toBeVisible();
}

/** Waits for the reply that makes the chat's messages `count`, and tells who wrote it. */
async function replied(page: Page, count: number): Promise<string> {
  await expect(messages(page)).toHaveCount(count);
  await expect(button(page, "Write again")).toBeEnabled();
  return (await speakers(page).last().textContent()) ?? "";
}

/** Sends a message, waits for the reply to it to end, and tells who wrote it. */
async function say(page: Page, text: string): Promise<string> {
  // The reply is the second message more: before it is there, "Write again" is the one of the message before.
  const before = await messages(page).count();
  await composer(page).fill(text);
  await composer(page).press("Enter");
  return replied(page, before + 2);
}

/** Has the next one speak without a message of the user's, and tells who it was. */
async function more(page: Page): Promise<string> {
  const before = await messages(page).count();
  await button(page, "Generate reply").click();
  return replied(page, before + 1);
}

/** Notes what the page sends to addresses that end so, from now on. */
function sent(page: Page, ending: string): unknown[] {
  const bodies: unknown[] = [];
  page.on("request", (request) => {
    if (request.url().endsWith(ending)) bodies.push(request.postDataJSON());
  });
  return bodies;
}

test("a chat of several characters has the one named reply", async ({ page, request }) => {
  const chat = await start(request);
  const asked = sent(page, "/generate");
  await open(page, chat);

  // The bar names the first character and, under it, the others; the message field all of them.
  await expect(page.getByRole("heading", { level: 1 }).locator(".chat-who > *")).toHaveText(["Wren", "with Odalys, Pike"]);
  await expect(composer(page)).toHaveAttribute("placeholder", "Message Wren, Odalys, Pike");
  // The pill says the choice, and a chat starts with the order that goes by names.
  await expect(replier(page)).toHaveText(NAMED);
  await expect(replier(page)).toHaveAccessibleName(`Who replies: ${NAMED}`);
  await expect(replier(page)).toHaveAttribute("title", MEANS[NAMED]);
  expect(await turn(request, chat)).toEqual(["natural", null]);
  // Its menu offers the orders, then the characters, each group under its name, and ticks the choice.
  const ticked = () => lines(page).evaluateAll((all) => all.map((one) => one.getAttribute("aria-checked") === "true"));
  await replier(page).click();
  await expect(page.locator(".replier .menu-group")).toHaveText(["Who replies", "Always"]);
  await expect(lines(page)).toHaveText([NAMED, IN_TURN, RANDOM, ...NAMES]);
  expect(await ticked()).toEqual([true, false, false, false, false, false]);
  await expect(lines(page).nth(0).locator("svg")).toHaveCount(1);
  await expect(lines(page).locator("svg")).toHaveCount(1);
  // It opens upward, from the pill's left edge on: its foot stands over the pill.
  const [menu, pill] = [await box(page.locator(".replier .pop")), await box(replier(page))];
  expect(menu.y + menu.height).toBeLessThanOrEqual(pill.y);
  expect(menu.x).toBe(pill.x);
  // The arrows go through its lines, the last of which has the characters keep replying by themselves, and Escape
  // closes it and gives the pill the focus.
  await expect(lines(page).nth(0)).toBeFocused();
  await page.keyboard.press("ArrowUp");
  await expect(page.getByRole("menuitem", { name: "Characters keep talking by themselves" })).toBeFocused();
  await page.keyboard.press("ArrowUp");
  await expect(always(page, "Pike")).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(page.locator(".replier .pop")).toBeHidden();
  await expect(replier(page)).toBeFocused();
  expect(await turn(request, chat)).toEqual(["natural", null]);

  // The one the user names replies,
  expect(await say(page, "Pike, what do you see?")).toBe("Pike");
  // and the one a character names answers it.
  provider.next(["Wren would know."]);
  expect(await say(page, "And you, Odalys?")).toBe("Odalys");
  expect(await more(page)).toBe("Wren");
  // The user names the one who spoke last, and is answered by him.
  expect(await say(page, "Wren, go on.")).toBe("Wren");
  // A name inside a word names nobody: one of those who did not speak last replies.
  expect(["Odalys", "Pike"]).toContain(await say(page, "Wrens nest in the reeds."));
  await expect(speakers(page)).toHaveCount(10);

  // The page named nobody: the chat's turn said who replies.
  expect(asked).toEqual([{}, {}, {}, {}, {}]);
  // Written again, a reply is its writer's.
  const writer = await speakers(page).last().textContent();
  await button(page, "Write again").click();
  await expect(page.locator(".message .count")).toHaveText("2 / 2");
  await expect(button(page, "Write again")).toBeEnabled();
  await expect(speakers(page).last()).toHaveText(writer!);
  expect(asked.at(-1)).toEqual({ regenerate: true });
});

test("an order chosen is kept with its chat, and in turn each replies after the one before", async ({ page, request }) => {
  const [chat, other] = [await start(request), await start(request)];
  const set = sent(page, "/turn");
  await open(page, chat);

  await choose(page, IN_TURN);
  await expect(replier(page)).toHaveAttribute("title", MEANS[IN_TURN]);
  await expect(replier(page)).toHaveText(IN_TURN);
  // The pill, made anew with the choice, has the focus, and its menu ticks the order chosen.
  await expect(replier(page)).toBeFocused();
  await expect(lines(page).filter({ hasText: IN_TURN })).toHaveAttribute("aria-checked", "true");
  await expect(lines(page).filter({ hasText: NAMED })).toHaveAttribute("aria-checked", "false");
  expect(set).toEqual([{ order: "list" }]);
  expect(await turn(request, chat)).toEqual(["list", null]);

  // Wren greeted: the others follow in the order they are in the chat, whoever is named, and then he again.
  expect(await say(page, "Wren, you first.")).toBe("Odalys");
  expect(await say(page, "Wren?")).toBe("Pike");
  expect(await more(page)).toBe("Wren");
  expect(await more(page)).toBe("Odalys");

  // The chat is read with its order when the app starts anew, and another chat has its own.
  await page.reload();
  await expect(messages(page).first()).toBeVisible();
  await expect(replier(page)).toHaveText(IN_TURN);
  await expect(replier(page)).toHaveAttribute("title", MEANS[IN_TURN]);
  await open(page, other);
  await expect(messages(page)).toHaveCount(1);
  await expect(replier(page)).toHaveText(NAMED);
  expect(await turn(request, other)).toEqual(["natural", null]);
});


test("the chat's menu renames it, and starts a new chat with these characters and its turn order", async ({ page, request }) => {
  const chat = await start(request);
  await open(page, chat);
  await choose(page, IN_TURN);
  await expect(replier(page)).toHaveText(IN_TURN);
  await button(page, "Chat options").click();
  await page.getByRole("menuitem", { name: "Rename", exact: true }).click();
  // The title is written in the line under the name, where "with …" stands, and Enter saves it.
  const title = page.locator(".chat-bar h1").getByLabel("Chat title");
  await expect(title).toBeFocused();
  await title.fill("The night watch");
  await title.press("Enter");
  await expect(title).toHaveCount(0);
  await expect(page.locator(".chat-bar h1 .meta")).toHaveText("with Odalys, Pike");
  await expect.poll(async () => (await (await request.get(`/api/chats/${chat}`)).json()).chat.title).toBe("The night watch");

  await button(page, "Chat options").click();
  await page.getByRole("menuitem", { name: "New chat with these characters", exact: true }).click();
  await expect(page).not.toHaveURL(new RegExp(`#/chats/${chat}$`));
  await expect(replier(page)).toHaveText(IN_TURN);
  const made = Number(new URL(page.url()).hash.split("/").pop());
  expect(await turn(request, made)).toEqual(["list", null]);
  // Wren greets as a chat begins; the others have no greeting.
  await expect(speakers(page)).toHaveText(["Wren"]);
});

test("the characters reply by themselves with the pause and count the side panel sets, and not again when their chat is opened anew", async ({ page, request }) => {
  const chat = await start(request);
  const set = await request.put(`/api/chats/${chat}/talk`, { data: { talk_pause: 4, talk_replies: 3 } });
  expect(set.status(), await set.text()).toBe(200);
  await open(page, chat);
  /** Sets the side panel's field `label`, and waits until the chat's `key` holds it. */
  const number = async (label: string, key: string, value: number) => {
    await page.getByLabel(label).fill(String(value));
    await page.getByLabel(label).press("Enter");
    await expect.poll(async () => (await (await request.get(`/api/chats/${chat}`)).json()).chat[key]).toBe(value);
  };
  // Pause and count show only while they keep replying by themselves.
  await expect(page.getByLabel("Pause between replies")).toBeHidden();

  // Two replies after Wren's greeting, and they stop, saying so.
  await replier(page).click();
  await page.getByRole("menuitem", { name: "Characters keep talking by themselves" }).click();
  await expect(page.getByLabel("Pause between replies")).toHaveValue("4");
  // Set while they reply, in the pause after the first (4 s, so that a loaded machine is in it).
  await number("Replies in a row", "talk_replies", 2);
  await expect(page.getByText(/of 2 replies/)).toBeVisible();
  await number("Pause between replies", "talk_pause", 1);
  await replied(page, 3);
  await expect(page.getByText("The characters stopped after 2 replies.")).toBeVisible();
  await expect(messages(page)).toHaveCount(3);

  // Going on, they wait 1 s after a reply; the chat left and opened again does not go on by itself.
  await expect(page.getByLabel("Pause between replies")).toBeHidden();
  await button(page, "Go on").click();
  // While they reply by themselves a message has Copy alone, so the reply is waited for by its count.
  await expect(messages(page)).toHaveCount(4);
  await page.goto("/#/chats");
  await open(page, chat);
  await page.waitForTimeout(1500);
  await expect(messages(page)).toHaveCount(4);
  await expect(page.getByText(/keep replying by themselves:/)).toBeHidden();
  // The user's next message is answered as always, by one reply.
  await say(page, "Quiet now.");
  await page.waitForTimeout(500);
  await expect(messages(page)).toHaveCount(6);
});
