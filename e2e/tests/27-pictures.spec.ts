import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { picture, SIZES, stopClock, storeModel, THEMES } from "../pictures";

// Pictures of what the library's screens share: the list with the rail, and the dialog "New chat" over it.
// Each is compared with its stored picture, pixel by pixel, at 1440 px in the light theme: that is the test
// of the look (CLAUDE.md, "Pictures of the screens"). The database is this spec's own: it makes four cards
// and a chat, the same in every run, and stores a provider.
//
// The pictures are `library` and `dialog`, kept in `27-pictures.spec.ts-snapshots/`; the other screens have
// theirs in the specs 29, 31, 32, 34, 36 and 38. The helpers, and how a picture is kept, renewed and kept
// still, are in ../pictures.ts.

/** The cards, in the order the library lists them: the first a favorite with a chat, the last without art. */
const CARDS = [
  { name: "The Royal Protector", first_mes: '*The morning sun fell through the heavy curtains.* "The castle is quiet," she said, "too quiet for my liking."', tags: ["knight", "court intrigue", "slow burn"] },
  { name: "Captain Vale", first_mes: '"Another body by the docks. Walk with me."', tags: ["mystery", "detective", "noir"] },
  { name: "Isolde", first_mes: '"Mind the reeds, traveller. The water is deeper than it looks."', tags: ["fantasy", "witch"] },
  { name: "Tern Rock", first_mes: "The lamp is lit on Tern Rock.", tags: [] },
];

async function make(request: APIRequestContext): Promise<void> {
  await storeModel(request, "picture-model");
  const ids: number[] = [];
  for (const [at, card] of CARDS.entries()) {
    // A picture of its own grey size for each but the last, which has none.
    const made = await request.post("/api/cards", { data: cardFile(card, at === CARDS.length - 1 ? [1, 1] : [300, 450]) });
    expect(made.status(), await made.text()).toBe(201);
    ids.push((await made.json()).card_id);
  }
  expect((await request.patch(`/api/cards/${ids[0]}`, { data: { favorite: true } })).status()).toBe(200);
  const { card, characters } = await (await request.get(`/api/cards/${ids[0]}`)).json();
  // A chat with the first card, by which its row says when it was last chatted with.
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.version_id, character: characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
}

test.beforeAll(({ request }) => make(request));

/** Opens the library's list, with its four cards and their pictures. */
async function library(page: Page): Promise<void> {
  await page.goto("/#/library");
  await expect(page.locator(".card-row")).toHaveCount(CARDS.length);
}

const row = (page: Page, title: string) => page.locator(".card-row", { hasText: title });

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the library's list: the rail or the bar, tabs, the search, the switch groups, rows, and a row's menu", async ({ page }) => {
        await library(page);
        // In a wide window the second row is pointed at and its menu is open, as the board draws a row.
        if (width > 600) {
          await row(page, "Captain Vale").hover();
          await row(page, "Captain Vale").getByRole("button", { name: "More" }).click();
          await expect(page.getByRole("menuitem").first()).toBeFocused();
        }
        await picture(page, named("library"));
      });

      test("a dialog: New chat over the library, its search in focus", async ({ page }) => {
        await library(page);
        const create = width > 600 ? page.locator("#rail") : page.locator("#topbar");
        await create.getByRole("button", { name: "Create" }).click();
        await page.getByRole("menuitem", { name: "New chat" }).click();
        const window = page.getByRole("dialog", { name: "New chat" });
        await expect(window.locator(".card-row")).toHaveCount(CARDS.length);
        await expect(window.getByLabel("Search characters")).toBeFocused();
        await picture(page, named("dialog"));
      });

    });
  }
}
