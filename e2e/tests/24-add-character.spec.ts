import type { APIRequestContext, Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Characters added to a chat: one picked in "Add a character" joins the chat and replies when it is its turn,
// and "New chat" starts a chat of several characters, taken in their order.
//
// One database for the file. The cards are made once (`TITLES`), and every test starts a chat of its own.
// `seek` opens the window "Add a character" from the menu of "+" and searches it for one card, `join` has a character join the
// chat in view, and `asked` notes what the page asks a reply with. Who replies is the pill over the message
// field (`replier`), whose words say the choice; `lines` are the lines of its menu, which are in the page
// while it is shut too. The last test opens the same window as "New chat", from Create, over the list of
// chats: who it has taken are the pills of its foot, each named "Remove" and the name.

/**
 * One character of a card: its ID in the card, its name, and what the prompt says of it. With a `label` it is
 * called so in lists, and a `silent` one has no greeting.
 */
interface Character {
  id: string;
  name: string;
  about: string;
  label?: string;
  silent?: true;
}

const HALDEN: Character = { id: "halden", name: "Halden", about: "Halden keeps the reef light." };
const ISOLDE: Character = { id: "isolde", name: "Isolde", about: "Isolde cuts reed on the saltings." };
const ADA: Character = { id: "ada", name: "Ada", about: "Ada rows the skerry boat." };
const BO: Character = { id: "bo", name: "Bo", about: "Bo mends the skerry nets." };

/** What Isolde's card brings: a lorebook with one entry, which always applies. */
const SALTINGS = `
[lore.flood]
name = "Spring tide"
trigger = "always"
keywords = []
text = "The saltings flood at the spring tide."

[lorebook.saltings]
name = "Saltings"
entries = ["lore.flood"]
`;

/** A card called `title` with these characters; with `lore`, each has the lorebook "Saltings". */
function file(title: string, characters: Character[], lore = ""): Buffer {
  const text = (words: string) => JSON.stringify(words);
  const blocks = characters.map(
    ({ id, name, about, label, silent }) => `
[name.${id}]
text = ${text(name)}

[description.${id}]
text = ${text(about)}
${silent ? "" : `
[greeting.${id}]
text = ${text(`${name} looks up.`)}
`}
[character.${id}]
name-card = ${text(label ?? name)}
name-char = "name.${id}"
greetings = [${silent ? "" : `"greeting.${id}"`}]
lorebooks = ${lore ? '["lorebook.saltings"]' : "[]"}
prompt = ["name.${id}", "description.${id}", "LOREBOOK", "CHAT-HISTORY"]
`,
  );
  return ccv4File(`spec = "ccv4:1.0.0"\n\n[meta-info]\ntitle = ${text(title)}\n${lore}${blocks.join("")}`, [40, 60]);
}

/** The cards' titles, each a word no other card has. */
const TITLES = { halden: "Halden Reefwarden", isolde: "Isolde Marshlight", twins: "Skerrytwins" };

let provider: FakeProvider;
/** The cards, each as its id and its newest version. */
const cards = { halden: { id: 0, version: 0 }, isolde: { id: 0, version: 0 }, twins: { id: 0, version: 0 } };

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  const add = async (title: string, characters: Character[], lore = "") => {
    const made = await request.post("/api/cards", { data: file(title, characters, lore) });
    expect(made.status(), await made.text()).toBe(201);
    // The first card edited once, so that a card's number is never its version's.
    if (title === TITLES.halden) {
      const edit = `/api/cards/${(await made.json()).card_id}/edit`;
      const again = await request.put(edit, { data: { ...(await (await request.get(edit)).json()), creator: "Halden's maker" } });
      expect(again.status(), await again.text()).toBe(200);
    }
    const { id, version_id } = (await (await request.get(`/api/cards?q=${encodeURIComponent(title)}`)).json())[0];
    return { id: id as number, version: version_id as number };
  };
  cards.halden = await add(TITLES.halden, [HALDEN]);
  cards.isolde = await add(TITLES.isolde, [ISOLDE], SALTINGS);
  // Imported with two characters, it keeps its first: a card holds one.
  cards.twins = await add(TITLES.twins, [ADA, BO]);
});
test.afterAll(() => provider.close());

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const messages = (page: Page) => page.locator(".message");
const composer = (page: Page) => page.getByLabel("Message", { exact: true });
const toast = (page: Page) => page.locator("#toast");
/** What the notice at the window's foot says, without its button. */
const said = (page: Page) => toast(page).locator("span");
const panel = (page: Page) => page.getByRole("complementary", { name: "Chat details" });
/** A part of the panel, by its name. */
const part = (page: Page, name: string) => panel(page).locator(".panel-part", { has: page.getByText(name, { exact: true }) });
/** The lines of the panel's part "Characters", and the names in them: a line has its "…" and that menu's lines too. */
const cast = (page: Page) => part(page, "Characters").locator(".item");
const listed = (page: Page) => cast(page).locator(".item-text");
/** The "+" of the message field, whose menu has "Add a character". */
const plus = (page: Page) => button(page, "Attach, or let the AI write");
/** The window a character is picked in. */
const picker = (page: Page) => page.getByRole("dialog", { name: "Add a character" });
const find = (page: Page) => picker(page).getByLabel("Search characters");
const rows = (page: Page) => picker(page).locator(".pick-list .row");
/** Who replies: the pill over the message field, which says the choice. */
const replier = (page: Page) => page.getByRole("button", { name: /^Who replies/ });
/** The lines of its menu, open or shut. */
const lines = (page: Page) => page.locator('.replier [role="menuitemradio"]');
/** What the pill calls the turn order a chat starts with. */
const NAMED = "Whoever is named replies";
/** The menu's lines for the turn orders, which stand over those for the characters. */
const ORDERS = [NAMED, "Each replies in turn", "A random one replies"];
const speakers = (page: Page) => messages(page).locator(".speaker");
/** The prompt the provider was last given, as one text. */
const lastPrompt = () => provider.asked.at(-1)!.body.messages.map((message: { content: string }) => message.content).join("\n");

/** Starts a chat with these characters, each as a card's version and its ID there, past the page. Returns its id. */
async function start(request: APIRequestContext, ...characters: [version: number, character: Character][]): Promise<number> {
  const data = { characters: characters.map(([version_id, { id }]) => ({ version_id, character: id })) };
  const response = await request.post("/api/chats", { data });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).chat.id;
}

/** The chat's characters as the server has them: their names. */
const names = async (request: APIRequestContext, chat: number): Promise<string[]> =>
  (await (await request.get(`/api/chats/${chat}`)).json()).characters.map((one: { name: string }) => one.name);

async function open(page: Page, chat: number): Promise<void> {
  await page.goto(`/#/chats/${chat}`);
  await expect(messages(page).first()).toBeVisible();
}

/** Opens the window and searches it for the one card called `title`. */
async function seek(page: Page, title: string): Promise<Locator> {
  await plus(page).click();
  await page.getByRole("menuitem", { name: "Add a character" }).click();
  await find(page).fill(title);
  await expect(rows(page)).toHaveCount(1);
  await expect(rows(page)).toContainText(title);
  return rows(page);
}

/** Has the character of the card called `title` join the chat in view. */
async function join(page: Page, title: string): Promise<void> {
  const row = await seek(page, title);
  await row.getByRole("button", { name: `Add ${title}`, exact: true }).click();
  await expect(page.locator("dialog")).toHaveCount(0);
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

/** Notes what the page asks a reply with, from now on. */
function asked(page: Page): unknown[] {
  const bodies: unknown[] = [];
  page.on("request", (request) => {
    if (request.url().endsWith("/generate")) bodies.push(request.postDataJSON());
  });
  return bodies;
}

test("a character picked joins the chat and replies when it is its turn", async ({ page, request }) => {
  const chat = await start(request, [cards.halden.version, HALDEN]);
  const sent = asked(page);
  await open(page, chat);
  await expect(composer(page)).toHaveAttribute("placeholder", "Message Halden");

  await join(page, TITLES.isolde);
  // The notice says who joined, and the chat shows her: in the message field's words, among those who can be
  // picked to reply, in the panel's list, and with the lorebook her card brings.
  await expect(said(page)).toHaveText("Isolde joined the chat.");
  await expect(button(page, "Undo")).toBeVisible();
  await expect(composer(page)).toHaveAttribute("placeholder", "Message Halden, Isolde");
  await expect(replier(page)).toBeVisible();
  await expect(replier(page)).toHaveText(NAMED);
  await expect(lines(page)).toHaveText([...ORDERS, "Halden", "Isolde"]);
  // The bar says who the chat is with now, under its first character's name.
  await expect(page.getByRole("heading", { level: 1 }).locator(".chat-who > *")).toHaveText(["Halden", "with Isolde"]);
  await expect(listed(page)).toHaveText(["Halden", "Isolde"]);
  await expect(panel(page).getByRole("switch", { name: "Saltings", exact: true })).toBeChecked();
  // She wrote no greeting.
  await expect(speakers(page)).toHaveText(["Halden"]);
  expect(await names(request, chat)).toEqual(["Halden", "Isolde"]);

  // The next message is answered by her, as the other spoke last: the prompt is hers, with the other's words
  // under his name. The page names nobody: the chat's turn says who replies.
  const pill = await replier(page).elementHandle();
  if (!pill) throw new Error("the choice has no pill");
  await say(page, "Who is out on the saltings?");
  expect(sent).toEqual([{}]);
  await expect(speakers(page)).toHaveText(["Halden", "You", "Isolde"]);
  expect(lastPrompt()).toContain(ISOLDE.about);
  expect(lastPrompt()).not.toContain(HALDEN.about);
  expect(lastPrompt()).toContain("Halden: Halden looks up.");
  expect(lastPrompt()).toContain("The saltings flood at the spring tide.");

  // The pill is the same one still: it is not made anew while the characters and the choice stay.
  expect(await pill.evaluate((node) => node.isConnected)).toBe(true);

  // Under the newest message, a character's too, "Generate reply" has the next one speak: he answers her.
  await button(page, "Generate reply").click();
  await expect(messages(page)).toHaveCount(4);
  await expect(button(page, "Write again")).toBeEnabled();
  await expect(speakers(page)).toHaveText(["Halden", "You", "Isolde", "Halden"]);
  expect(sent).toEqual([{}, {}]);
  expect(lastPrompt()).toContain(HALDEN.about);
  expect(lastPrompt()).toContain("Isolde: Echo: Who is out on the saltings?");
});

test("a card whose other character, of before, is in the chat still gives its own", async ({ page, request }) => {
  const chat = await start(request, [cards.halden.version, HALDEN]);
  // The chat as one from before has it: with another character of Halden's card, which a card held then.
  await page.route(`**/api/chats/${chat}`, async (route) => {
    const json = await (await route.fetch()).json();
    json.characters[0].character = "halden-before";
    await route.fulfill({ json });
  });
  await open(page, chat);
  const row = await seek(page, TITLES.halden);
  await expect(row.getByRole("button", { name: `Add ${TITLES.halden}`, exact: true })).toBeVisible();
});

test("New chat starts a chat with several characters: “+” takes each, in its order, and “Start chat” starts it", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New chat" }).click();
  const window = page.getByRole("dialog", { name: "New chat" });
  const search = window.getByLabel("Search characters");
  const lines = window.locator(".pick-list .row");
  const foot = window.locator(".pick-foot");
  const taken = foot.getByRole("button", { name: /^Remove / });
  // How often the window reads Isolde's card for its characters.
  let reads = 0;
  page.on("request", (sent) => void (sent.method() === "GET" && new URL(sent.url()).pathname === `/api/cards/${cards.isolde.id}` && reads++));
  const look = async (title: string) => {
    await search.fill(title);
    await expect(lines).toHaveCount(1);
    await expect(lines).toContainText(title);
  };

  // At first a line has "+" before "Chat", and nobody is taken.
  await look(TITLES.isolde);
  await expect(lines.getByRole("button")).toHaveCount(2);
  await expect(lines.getByRole("button").first()).toHaveAccessibleName(`Add ${TITLES.isolde} to a group chat`);
  await expect(lines.getByRole("button").last()).toHaveAccessibleName(`Chat with ${TITLES.isolde}`);
  await expect(foot).toBeHidden();
  // "+" takes the character and starts nothing: the foot says who is taken, the line that the card has nobody left.
  await window.getByRole("button", { name: `Add ${TITLES.isolde} to a group chat` }).click();
  await expect(taken).toHaveText(["Isolde"]);
  await expect(foot).toContainText("Chat with");
  await expect(lines.locator(".meta", { hasText: "Added" })).toBeVisible();
  await expect(lines.getByRole("button")).toHaveCount(0);
  await expect(search).toBeFocused();

  // From then on a line has "Add"; the card imported with two characters adds its first, without asking which.
  await look(TITLES.twins);
  // The card was read once, for its character: its line drawn anew as taken did not read it again.
  expect(reads).toBe(1);
  await expect(lines.getByRole("button")).toHaveCount(1);
  await expect(lines.getByRole("button")).toHaveAccessibleName(`Add ${TITLES.twins}`);
  await lines.getByRole("button", { name: `Add ${TITLES.twins}` }).click();
  await expect(lines.locator(".meta", { hasText: "Added" })).toBeVisible();
  await expect(taken).toHaveText(["Isolde", "Ada"]);
  await look(TITLES.halden);
  await lines.getByRole("button", { name: `Add ${TITLES.halden}` }).click();
  await expect(taken).toHaveText(["Isolde", "Ada", "Halden"]);

  // A pill takes its character out again: the focus goes to the pill in its place, and the card gives it again.
  await foot.getByRole("button", { name: "Remove Ada" }).click();
  await expect(taken).toHaveText(["Isolde", "Halden"]);
  await expect(foot.getByRole("button", { name: "Remove Halden" })).toBeFocused();
  await look(TITLES.twins);
  await lines.getByRole("button", { name: `Add ${TITLES.twins}` }).click();
  await expect(taken).toHaveText(["Isolde", "Halden", "Ada"]);

  // A chat that does not start says why in the window, which keeps who is taken.
  await page.route("**/api/chats", (route) => (route.request().method() === "POST" ? route.fulfill({ status: 500, json: { code: "internal", error: "the chats are away", details: {} } }) : route.fallback()));
  await foot.getByRole("button", { name: "Start chat" }).click();
  await expect(window.getByRole("alert")).toHaveText("Something went wrong in Cardwave. Try again.");
  await expect(taken).toHaveText(["Isolde", "Halden", "Ada"]);
  await page.unroute("**/api/chats");

  // "Start chat" starts it with them in the order taken, each with its card's newest version: the first greets and names it.
  const started = page.waitForRequest((sent) => sent.method() === "POST" && sent.url().endsWith("/api/chats"));
  await foot.getByRole("button", { name: "Start chat" }).click();
  expect((await started).postDataJSON().characters).toEqual([
    { version_id: cards.isolde.version, character: ISOLDE.id },
    { version_id: cards.halden.version, character: HALDEN.id },
    { version_id: cards.twins.version, character: ADA.id },
  ]);
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(messages(page).locator(".text")).toHaveText(["Isolde looks up."]);
  await expect(page.getByRole("heading", { level: 1 }).locator(".chat-who > *")).toHaveText(["Isolde", "with Halden, Ada"]);
  await expect(listed(page)).toHaveText(["Isolde", "Halden", "Ada"]);
  await expect(replier(page)).toBeVisible();
});

test("a chat of several: Characters shows each one's round in speaking order and a “+” that adds one; in the Trash the chat is only read and says how to write again", async ({ page, request }) => {
  const chat = await start(request, [cards.halden.version, HALDEN], [cards.isolde.version, ISOLDE]);
  await open(page, chat);
  // Each round in the bar names its character while pointed at.
  await expect(page.locator(".chat-rounds .avatar")).toHaveCount(2);
  for (const name of ["Halden", "Isolde"]) await expect(page.locator(`.chat-rounds [title="${name}"]`)).toHaveCount(1);
  await expect(cast(page).locator(".avatar")).toHaveCount(2);
  await expect(part(page, "Characters").getByText("In speaking order")).toBeVisible();
  await part(page, "Characters").getByRole("button", { name: "Add a character" }).click();
  await expect(picker(page)).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(picker(page)).toHaveCount(0);

  expect((await request.patch(`/api/chats/${chat}`, { data: { trashed: true } })).status()).toBe(200);
  await open(page, chat);
  const band = page.locator(".chat-dock .banner");
  await expect(band).toContainText("This chat is in the Trash. Restore it to go on writing.");
  await expect(composer(page)).toBeHidden();
  await expect(panel(page).getByText("In the Trash: restore the chat to change it.")).toBeVisible();
  await expect(part(page, "Characters").getByRole("button", { name: "Add a character" })).toHaveCount(0);
  await band.getByRole("button", { name: "Restore" }).click();
  await expect(composer(page)).toBeVisible();
  await expect(band).toBeHidden();
  await expect(panel(page).getByText("In the Trash: restore the chat to change it.")).toBeHidden();
});

test("New chat says who the user is in it, “as” a persona, which Change picks for the chat it starts", async ({ page, request }) => {
  const newChat = async () => {
    await page.goto("/#/chats");
    await page.locator("#rail").getByRole("button", { name: "Create" }).click();
    await page.getByRole("menuitem", { name: "New chat" }).click();
    return page.getByRole("dialog", { name: "New chat" });
  };
  const as = (window: Locator) => window.locator(".pick-as");
  // Without a persona nothing is said.
  await expect(as(await newChat())).toBeHidden();
  await page.keyboard.press("Escape");

  // The file's last test: the personas it makes stay.
  const made: number[] = [];
  for (const name of ["Wanderer", "Ines"]) made.push((await (await request.post("/api/personas", { data: { name } })).json()).id);
  // Without a default the user is nobody in particular, and Change offers each persona.
  let window = await newChat();
  await expect(as(window)).toContainText("as Guest");
  await as(window).getByRole("button", { name: "Change" }).click();
  await expect(page.getByRole("menuitemradio")).toHaveText([/Guest/, /Ines/, /Wanderer/]);
  await page.getByRole("menuitemradio", { name: "Wanderer" }).click();
  await expect(as(window)).toContainText("as Wanderer");
  const started = page.waitForRequest((sent) => sent.method() === "POST" && sent.url().endsWith("/api/chats"));
  await window.getByLabel("Search characters").fill(TITLES.halden);
  await window.getByRole("button", { name: `Chat with ${TITLES.halden}` }).click();
  expect((await started).postDataJSON().persona_id).toBe(made[0]);

  // The default is the one said at first.
  expect((await request.patch(`/api/personas/${made[1]}`, { data: { is_default: true } })).status()).toBe(200);
  window = await newChat();
  await expect(as(window)).toContainText("as Ines");
});
