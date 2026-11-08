import { expect, test } from "../test";
import { cardFile } from "../card";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// The picture of Knowledge › Documents, compared with its stored picture, pixel by pixel, at 1440 px in the light
// theme (CLAUDE.md, "Pictures of the screens"): a document of a chat and one of a character, a row pointed at. No
// board draws the screen; it is made as Knowledge › Memories (docs/design.md, "Knowledge › Documents").
//
// The picture is `documents`. The database is this spec's own: a card, a chat with it, and the two documents, given
// through the API; no search model is set up, so both wait for it.

test.beforeAll(async ({ request }) => {
  const card = await request.post("/api/cards", { data: cardFile({ name: "Guinivere", description: "A queen of a quiet castle.", first_mes: "The castle is quiet." }) });
  expect(card.status(), await card.text()).toBe(201);
  const made = await card.json();
  const chat = await request.post("/api/chats", { data: { characters: [{ version_id: made.version_id, character: "guinivere" }] } });
  expect(chat.status(), await chat.text()).toBe(201);
  const id = (await chat.json()).chat.id;
  const give = async (path: string, text: string) => expect((await request.post(path, { data: Buffer.from(text) })).status()).toBe(201);
  await give(`/api/chats/${id}/documents?name=${encodeURIComponent("Council minutes.txt")}`, "The council moved the hearing to noon. ".repeat(40));
  await give(`/api/cards/${made.card_id}/documents?name=${encodeURIComponent("Castle history.md")}`, "# The castle\nBuilt on the old hill by the first queen. ".repeat(25));
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("Knowledge › Documents: a document of a chat and one of a character, one pointed at", async ({ page }) => {
        await page.goto("/#/knowledge/documents");
        const rows = page.locator(".document-row");
        await expect(rows).toHaveCount(2);
        await rows.nth(1).hover();
        await expect(rows.nth(1).locator(".reveal")).toHaveCSS("opacity", "1");
        await picture(page, named("documents"));
      });
    });
  }
}
