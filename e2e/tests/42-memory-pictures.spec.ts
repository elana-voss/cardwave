import { expect, test } from "../test";
import { cardFile } from "../card";
import { NOTHING, startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// The picture of Knowledge › Memories, compared with its stored picture, pixel by pixel, at 1440 px in the light
// theme (CLAUDE.md, "Pictures of the screens"): three memories of one chat, a row pointed at. No board draws the
// screen; it is made of the library's lists (docs/design.md, "Knowledge").
//
// The picture is `memories`. The database is this spec's own: a card, a chat with it of 19 messages and one reply,
// the block whose memory helper the stand-in of ../fake-provider.ts answers with the three memories.

let provider: FakeProvider;

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "picture-model", api_key: "sk-picture", sampling: {} } });
  expect(set.status()).toBe(200);
  const card = await request.post("/api/cards", { data: cardFile({ name: "Guinivere", description: "A queen of a quiet castle.", first_mes: "The castle is quiet." }) });
  expect(card.status(), await card.text()).toBe(201);
  const chat = await request.post("/api/chats", { data: { characters: [{ version_id: (await card.json()).version_id, character: "guinivere" }] } });
  expect(chat.status(), await chat.text()).toBe(201);
  const id = (await chat.json()).chat.id;
  provider.remembers(
    [
      "PRESENT: Guinivere, User",
      "FACTS:",
      "wanderer | role | Wanderer serves the council as its messenger. | personal | Guinivere | current",
      "guinivere | trust | Guinivere distrusts the council's eldest lord. | personal | Guinivere, User | open",
      "EVENTS:",
      "The council moved the hearing to noon | the eldest lord asked it | the queen waits | Guinivere | world",
    ].join("\n"),
  );
  for (let n = 2; n <= 19; n++) {
    expect((await request.post(`/api/chats/${id}/messages`, { data: { content: `Your Highness, word ${n} of the council.` } })).status()).toBe(201);
  }
  expect((await request.post(`/api/chats/${id}/generate`, { data: {} })).status()).toBe(202);
  await expect.poll(async () => (await (await request.get("/api/memories")).json()).length).toBe(3);
  provider.remembers(NOTHING);
});
test.afterAll(() => provider.close());

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    const named = (screen: string) => `${screen}-${width}-${theme}`;

    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("Knowledge › Memories: three memories of a chat, one pointed at", async ({ page }) => {
        await page.goto("/#/knowledge/memories");
        const rows = page.locator(".memory-row");
        await expect(rows).toHaveCount(3);
        await rows.nth(1).hover();
        await expect(rows.nth(1).locator(".reveal")).toHaveCSS("opacity", "1");
        await picture(page, named("memories"));
      });
    });
  }
}
