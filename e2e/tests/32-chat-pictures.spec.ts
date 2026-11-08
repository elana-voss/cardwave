import type { APIRequestContext, Page, Request } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File, pictureFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, SIZES, stopClock, THEMES } from "../pictures";
import { setProvider, setImages } from "../stored";

/** The rail's two Guinivere chats say their day and time, made on the real clock: masked, so the pictures hold. */
const twins = (page: Page) => [page.locator(".nav-chat", { hasText: "Guinivere" })];

// Pictures of the chat's screens, each compared with its stored picture, pixel by pixel, at 1440 px in the
// light theme (CLAUDE.md, "Pictures of the screens"): a chat as bubbles with a message's menu open, and with
// the menu of the message field's "+" open, a chat of
// several characters with the menu of who replies open, the window "Add a character", and the list of chats
// with a row pointed at. The database is this spec's own: five cards, a persona, a lorebook and four chats.
//
// The pictures are `chat`, `tools`, `painted`, `group`, `adding` and `chats`. `painted` is a chat with Guinivere whose
// second message is a picture the image model made, a portrait of 832 by 1216 pixels, as SDXL makes one. `solo` is the chat with Guinivere: her greeting, a
// message of the user's and a reply in three versions, the second in view, with a lorebook of the library
// whose entry the reply was given; the replies are written by the stand-in of ../fake-provider.ts. `group` is
// the chat of Isolde, Captain Vale and Odalys.
// `pair` is the chat of Guinivere and Lancelot, in which a character is added. A chat is read twice at a
// start, when its screen is made and again once the page hears the server, and the second reading draws the
// messages anew, with their round pictures: `open` waits for both, as a picture drawn anew while it is taken
// comes out in two ways (../pictures.ts). A character whose card has no art has its round without a picture,
// for which `open` would wait in vain: the chats it opens are of cards with art.

interface One {
  id: string;
  name: string;
  greeting?: string;
}

/** A card file of the title with the characters, each with its name and, where it has one, its greeting. */
function file(title: string, ones: One[], size: [number, number] = [300, 450]): Buffer {
  const text = (words: string) => JSON.stringify(words);
  const blocks = ones.map(
    ({ id, name, greeting }) => `
[name.${id}]
text = ${text(name)}
${greeting ? `\n[greeting.${id}]\ntext = ${text(greeting)}\n` : ""}
[character.${id}]
name-card = ${text(name)}
name-char = "name.${id}"
greetings = [${greeting ? `"greeting.${id}"` : ""}]
prompt = ["name.${id}", "LOREBOOK", "CHAT-HISTORY"]
`,
  );
  return ccv4File(`spec = "ccv4:1.0.0"\n\n[meta-info]\ntitle = ${text(title)}\n${blocks.join("")}`, size);
}

const GUIN: One = {
  id: "guin",
  name: "Guinivere",
  greeting:
    '*The morning sun filtered through the heavy velvet curtains of my chambers, casting pale gold light across the polished marble floors.*\n\n"The castle is quiet," *she murmured,* "too quiet for my liking."',
};
const ISOLDE: One = { id: "isolde", name: "Isolde", greeting: '"Mind the reeds, traveller. The water is deeper than it looks."' };
const VALE: One = { id: "vale", name: "Captain Vale", greeting: '"Another body by the docks. Walk with me."' };
const ODALYS: One = { id: "odalys", name: "Odalys", greeting: "Odalys sets down her lantern." };

let provider: FakeProvider;
/** The chats: with Guinivere, of the three, and of Guinivere and Lancelot. */
let solo = 0;
let group = 0;
let pair = 0;
/** The chat with Guinivere whose second message is a picture. */
let painted = 0;

async function make(request: APIRequestContext): Promise<void> {
  provider = await startFakeProvider();
  const set = await setProvider(request, { base_url: provider.url, model: "picture-model", api_key: "sk-test", sampling: {} });
  expect(set.status(), await set.text()).toBe(200);
  const posted = async (path: string, data: unknown) => {
    const made = await request.post(path, { data });
    expect(made.status(), await made.text()).toBe(201);
    return made.json();
  };
  /** Imports a card and answers its newest version. */
  const card = async (made: Buffer): Promise<{ id: number; version: number }> => {
    const { card_id } = await posted("/api/cards", made);
    const { card } = await (await request.get(`/api/cards/${card_id}`)).json();
    return { id: card_id, version: card.version_id };
  };
  const chat = async (characters: { version_id: number; character: string }[]): Promise<number> => (await posted("/api/chats", { characters })).chat.id;
  /** Has a character write the chat's next reply as told, or its newest again, and waits for its end. */
  const reply = async (to: number, said: string, data: object): Promise<number> => {
    provider.next([said]);
    const made = await request.post(`/api/chats/${to}/generate`, { data });
    expect(made.status(), await made.text()).toBe(202);
    const { id } = await made.json();
    await expect
      .poll(async () => {
        const { messages } = await (await request.get(`/api/chats/${to}`)).json();
        return messages.find((message: { id: number }) => message.id === id)?.complete;
      })
      .toBe(true);
    return id;
  };

  // The user is Wanderer in every chat started from here on.
  const wanderer = await posted("/api/personas", { name: "Wanderer", description: "A traveller." });
  expect((await request.patch(`/api/personas/${wanderer.id}`, { data: { is_default: true } })).status()).toBe(200);

  const protector = await card(file("The Royal Protector", [GUIN]));
  const vale = await card(file("Captain Vale", [VALE]));
  const odalys = await card(file("Odalys", [ODALYS]));
  const isolde = await card(file("Isolde", [{ ...ISOLDE, greeting: '"Mind the reeds, traveller."' }]));
  const court = await card(file("Camlann Court", [{ id: "lancelot", name: "Lancelot" }]));
  const rock = await card(file("Tern Rock", [{ id: "keeper", name: "Tern Rock", greeting: "The lamp is lit on Tern Rock." }], [1, 1]));

  const world = JSON.stringify({ description: "Kingdom of Camlann", entries: { 0: { uid: 0, key: [], comment: "The Council of Twelve", content: "Twelve sit in council.", constant: true } } });
  const { lorebook } = await posted("/api/lorebooks?name=Kingdom%20of%20Camlann.json", Buffer.from(world));

  // The list of chats has the chat written in last first: the two that are pictured come last.
  await chat([{ version_id: rock.version, character: "keeper" }]);
  pair = await chat([
    { version_id: protector.version, character: "guin" },
    { version_id: court.version, character: "lancelot" },
  ]);

  group = await chat([
    { version_id: isolde.version, character: "isolde" },
    { version_id: vale.version, character: "vale" },
    { version_id: odalys.version, character: "odalys" },
  ]);
  const cast: { id: number; name: string }[] = (await (await request.get(`/api/chats/${group}`)).json()).characters;
  const who = (name: string) => cast.find((one) => one.name === name)!.id;
  await posted(`/api/chats/${group}/messages`, { content: "Captain, what do you make of the body by the docks?" });
  const first = await reply(group, '*He crouches by the water’s edge.* "Another one. Same knot on the wrists."', { speaker_id: who("Captain Vale") });
  await reply(group, '"Same knot. Same tide."', { regenerate: true });
  expect((await request.put(`/api/chats/${group}/head`, { data: { message_id: first, follow: true } })).status()).toBe(200);

  // A picture of a portrait's size, made at the chat provider's image API.
  expect((await setImages(request, { model: "picture-image" })).status()).toBe(200);
  provider.paints(pictureFile([832, 1216]));
  painted = await chat([{ version_id: protector.version, character: "guin" }]);
  provider.next(["throne room, morning light, 1 woman"]);
  await posted(`/api/chats/${painted}/picture`, {});
  // Archived, it stays out of the list of chats, whose picture is of four.
  expect((await request.patch(`/api/chats/${painted}`, { data: { archived: true } })).status()).toBe(200);

  solo = await chat([{ version_id: protector.version, character: "guin" }]);
  expect((await request.post(`/api/chats/${solo}/lorebooks`, { data: { lorebook_id: lorebook.id } })).status()).toBe(200);
  await posted(`/api/chats/${solo}/messages`, { content: "*knocks twice* Your Highness, the council has moved the hearing to noon." });
  await reply(solo, '"Noon." *She sets the letter down.*', {});
  const shown = await reply(solo, '*She does not look up from her letters.* "Then we have until noon. Sit."', { regenerate: true });
  await reply(solo, '"Then we ride at noon."', { regenerate: true });
  expect((await request.put(`/api/chats/${solo}/head`, { data: { message_id: shown, follow: true } })).status()).toBe(200);
  expect((await request.patch(`/api/chats/${solo}`, { data: { favorite: true } })).status()).toBe(200);
}

test.beforeAll(({ request }) => make(request));
test.afterAll(() => provider.close());

const button = (page: Page, name: string | RegExp) => page.getByRole("button", { name, exact: true });
const messages = (page: Page) => page.locator(".message");

/** Opens a chat and waits for its `count` messages, as its second reading draws them, and the round pictures beside their names. */
async function open(page: Page, chat: number, count: number): Promise<void> {
  let read = 0;
  const counted = (request: Request) => {
    if (request.method() === "GET" && new URL(request.url()).pathname === `/api/chats/${chat}`) read += 1;
  };
  page.on("requestfinished", counted);
  await page.goto(`/#/chats/${chat}`);
  await expect.poll(() => read).toBe(2);
  page.off("requestfinished", counted);
  await expect(messages(page)).toHaveCount(count);
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done))));
  await expect.poll(() => page.locator("img.avatar").evaluateAll((all: HTMLImageElement[]) => all.every((one) => one.complete && one.naturalWidth > 0))).toBe(true);
}

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;
    /** The pointer leaves for the window's corner, where it points at nothing. */
    const away = (page: Page) => page.mouse.move(width - 2, height - 2);

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(async ({ page }) => {
        await stopClock(page);
      });

      test("a chat as bubbles: narration in italics, the user's message at the right, the newest reply's versions and its menu open", async ({ page }) => {
        await open(page, solo, 3);
        await expect(messages(page).last().locator(".count")).toHaveText("2 / 3");
        await messages(page).last().getByRole("button", { name: "Message options" }).click();
        await page.getByRole("menuitem", { name: "Copy" }).hover();
        await picture(page, named("chat"), twins(page));
      });

      test("the menu of the message field's \"+\" open, with words in the field", async ({ page }) => {
        await open(page, solo, 3);
        await page.getByLabel("Message", { exact: true }).fill("i want see lamp");
        await button(page, "Attach, or let the AI write").click();
        await page.getByRole("menuitem", { name: "Write for me" }).hover();
        await picture(page, named("tools"), twins(page));
      });

      test("a picture the image model made, a portrait, in its message's bubble", async ({ page }) => {
        await open(page, painted, 2);
        await expect.poll(() => page.locator("img.picture").evaluate((shown: HTMLImageElement) => shown.complete && shown.naturalWidth)).toBe(832);
        await away(page);
        await picture(page, named("painted"), twins(page));
      });

      test("a chat of several characters: who it is with, Generate reply, the menu of who replies open, and the panel's characters", async ({ page }) => {
        await open(page, group, 3);
        await button(page, /^Who replies/).click();
        await expect(page.getByRole("menuitemradio", { name: "Whoever is named replies" })).toBeFocused();
        await away(page);
        await picture(page, named("group"), twins(page));
      });

      if (width <= 600) {
      }

      test("Add a character: the library's cards, one in the chat already", async ({ page }) => {
        await open(page, pair, 1);
        await button(page, "Attach, or let the AI write").click();
        await page.getByRole("menuitem", { name: "Add a character" }).click();
        const window = page.getByRole("dialog", { name: "Add a character" });
        await expect(window.locator(".card-row")).toHaveCount(6);
        await expect.poll(() => window.locator("img.cover").evaluateAll((all: HTMLImageElement[]) => all.every((one) => one.complete))).toBe(true);
        await away(page);
        await picture(page, named("adding"), twins(page));
      });

      test("the list of chats in another order than its own, which its button says: a favorite, a chat of several pointed at, and one whose card has no art", async ({ page }) => {
        await page.goto("/#/chats");
        await expect(page.locator(".card-row")).toHaveCount(4);
        await button(page, "Sort").click();
        const panel = page.getByRole("dialog", { name: "Sort" });
        await panel.getByRole("button", { name: "Name" }).click();
        await panel.getByRole("button", { name: "Apply" }).click();
        await expect(page.locator("dialog")).toHaveCount(0);
        await expect(page.locator(".card-row .row-title")).toHaveText(["Guinivere", "Guinivere", "Isolde", "Tern Rock"]);
        // The card without art has the chat's drawing in its picture's place.
        await expect(page.locator(".card-row span.cover")).toHaveCount(1);
        await page.locator(".card-row").nth(2).hover();
        await picture(page, named("chats"), twins(page));
      });

    });
  }
}
