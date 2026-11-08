import type { APIRequestContext, Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { cardFile, type Size } from "../card";
import { picture, SIZES, stopClock, storeModel, THEMES } from "../pictures";

// Pictures of the library's other screens, each compared with its stored picture, pixel by pixel, at 1440 px
// in the light theme (CLAUDE.md, "Pictures of the screens"): the Gallery, Discovery, the lorebooks, and the
// personas with a form open. The list itself is spec 27's. The database is this spec's own: it makes five
// cards, two lorebooks and three personas, and stores a provider.
//
// The pictures are `gallery`, `discovery`, `lorebooks` and `personas`.

/** The cards, in the order they are made: the first a favorite with a chat, the fourth without art. */
const CARDS: [data: Record<string, unknown>, art: Size][] = [
  [{ name: "The Royal Protector", first_mes: '*The morning sun fell through the heavy curtains.* "The castle is quiet," she said, "too quiet for my liking."', tags: ["knight", "court intrigue", "slow burn"] }, [300, 450]],
  [{ name: "Captain Vale", first_mes: '"Another body by the docks. Walk with me."', tags: ["mystery", "detective", "noir"] }, [450, 300]],
  [{ name: "Isolde", first_mes: '"Mind the reeds, traveller. The water is deeper than it looks."', tags: ["fantasy", "witch", "slow burn"] }, [300, 300]],
  [{ name: "Tern Rock", first_mes: "The lamp is lit on Tern Rock.", tags: ["lighthouse", "sea"] }, [1, 1]],
  [{ name: "Wren Halloway", first_mes: '"You are late," Wren says, and does not look up from the ledger.', tags: ["romance", "slow burn"] }, [300, 450]],
];

/** A lorebook file as SillyTavern writes its world info. */
const world = (entries: string[], description: string) =>
  JSON.stringify({ description, entries: Object.fromEntries(entries.map((comment, uid) => [uid, { uid, key: [], comment, content: `${comment}.`, constant: true }])) });

async function make(request: APIRequestContext): Promise<void> {
  await storeModel(request, "picture-model");
  const posted = async (path: string, data: unknown) => {
    const made = await request.post(path, { data });
    expect(made.status(), await made.text()).toBe(201);
    return made.json();
  };
  const ids: number[] = [];
  for (const [card, art] of CARDS) ids.push((await posted("/api/cards", cardFile(card, art))).card_id);
  expect((await request.patch(`/api/cards/${ids[0]}`, { data: { favorite: true } })).status()).toBe(200);
  const { card, characters } = await (await request.get(`/api/cards/${ids[0]}`)).json();
  // Started before there is a persona, so without one.
  await posted("/api/chats", { characters: [{ version_id: card.version_id, character: characters[0].id }] });

  const houses = ["The Council of Twelve", "Camlann Keep", "The Royal Guard", ...Array.from({ length: 9 }, (_, at) => `House ${at + 1}`)];
  const camlann = await posted("/api/lorebooks?name=Kingdom%20of%20Camlann.json", Buffer.from(world(houses, "The court, its houses and who owes whom.")));
  expect((await request.patch(`/api/lorebooks/${camlann.lorebook.id}`, { data: { favorite: true } })).status()).toBe(200);
  await posted("/api/lorebooks?name=Moor.json", Buffer.from(world(["The moor"], "Of the moor and its paths.")));

  const rowan = await posted("/api/personas", { name: "Rowan", description: "Himself." });
  expect((await request.patch(`/api/personas/${rowan.id}`, { data: { is_default: true } })).status()).toBe(200);
  await posted("/api/personas", { name: "Night Porter", description: "Keeps the door, and knows who came in after dark and who did not leave again." });
  await posted("/api/personas", { name: "Wanderer", description: "A traveller with a sword and no past." });
}

test.beforeAll(({ request }) => make(request));

/** Opens the library's list, with its cards. */
async function library(page: Page): Promise<void> {
  await page.goto("/#/library");
  await expect(page.locator(".card-row")).toHaveCount(CARDS.length);
}

const row = (page: Page, title: string) => page.locator(".card-row", { hasText: title });

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;
    /** The pointer leaves for the window's corner, where it points at nothing. */
    const away = (page: Page) => page.mouse.move(width - 2, height - 2);

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the Gallery: tiles, a favorite's star, a card without art, and a tile pointed at", async ({ page }) => {
        await library(page);
        await chooseView(page, "Gallery");
        await expect(page.locator(".tile")).toHaveCount(CARDS.length);
        await expect(page.locator(".tile-hover")).toHaveCount(CARDS.length - 1);
        if (width > 600) await page.locator(".tile", { hasText: "Isolde" }).hover();
        await picture(page, named("gallery"));
      });

      test("Discovery: large entries, the picture on a blurred copy of itself, the sides taking turns", async ({ page }) => {
        await library(page);
        await chooseView(page, "Discovery");
        await expect(page.locator(".entry")).toHaveCount(CARDS.length);
        await expect(page.locator(".art-bg")).toHaveCount(CARDS.length - 1);
        await away(page);
        await picture(page, named("discovery"));
      });

      test("the lorebooks: a box with the book in a picture's place, and a row pointed at", async ({ page }) => {
        await page.goto("/#/library/lorebooks");
        await expect(page.locator(".card-row")).toHaveCount(2);
        if (width > 600) await row(page, "Moor").hover();
        else await away(page);
        await picture(page, named("lorebooks"));
      });

      test("the personas: the round letter, a persona's form in its row, and a row pointed at", async ({ page }) => {
        await page.goto("/#/library/personas");
        await expect(page.locator(".card-row")).toHaveCount(3);
        await row(page, "Night Porter").hover();
        if (width > 600) await row(page, "Night Porter").getByRole("button", { name: "Edit" }).click();
        else {
          await row(page, "Night Porter").getByRole("button", { name: "More" }).click();
          await page.getByRole("menuitem", { name: "Edit" }).click();
        }
        await expect(page.getByLabel("Name")).toBeFocused();
        if (width > 600) await row(page, "Wanderer").hover();
        else await away(page);
        await picture(page, named("personas"));
      });

      // The board of 600 px draws the list as a phone shows it.
      if (width <= 600) {
      }
    });
  }
}
