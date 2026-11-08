import type { APIRequestContext, Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { cardFile, type Size } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// The Characters page's view "By need": the row "I need…" over Gallery's tiles. The tests run in turn on one
// database: its cards are first not read at all, then being read, then read with the needs in `CARDS`. The stand-in
// `api` is told each answer in turn: for every card the classifier's and the writer's, then for every card its needs,
// whose quote must stand in the card or the need counts for nothing. No test asks a provider.
//
// The stored picture is `by-need`, with two needs picked as the board has them.

test.describe.configure({ mode: "serial" });

/** Each card's title, art, tags and needs with their levels. Some needs are there for the row to wrap. */
const CARDS: [title: string, art: Size, tags: string[], needs: [string, number][]][] = [
  [
    "The Royal Protector",
    [300, 450],
    ["comfort"],
    ["listen", "accepted", "looked_after", "safe", "belong", "forgiven", "grieve", "admired", "believed_in", "pushed", "get_better", "in_control", "decide", "purpose", "elsewhere"].map((need) => [need, 3]),
  ],
  ["Captain Vale", [450, 300], ["mystery"], [["keep_company", 3]]],
  ["Isolde", [300, 300], ["comfort"], [["keep_company", 2], ["sex", 3]]],
  ["Tern Rock", [1, 1], ["comfort"], []],
  ["Wren Halloway", [300, 450], ["comfort"], [["sex", 2]]],
];
const QUOTE = "Come in, and shut the door.";

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const reply = (content: unknown) => [JSON.stringify(content)];
const classified = {
  verdict: "classified",
  characters: [{ name: "Mira", gender: "female", age: "adult" }],
  pairing: "unspecified",
  engine: "comfort",
  multi_mode: false,
  per_greeting: [],
  frame: "neighbor",
  frame_display: "neighbor",
  rating: "sfw",
  content_flags: [],
  archetype: ["grump"],
  mechanism: "keeps the door",
};

const tiles = (page: Page) => page.locator(".gallery .tile-title");
const pill = (page: Page, words: string) => page.getByRole("button", { name: words, exact: true });
const row = (page: Page) => page.locator(".need-row");

/** The page in the view By need, as the eye's menu chooses it. */
async function open(page: Page): Promise<void> {
  await page.goto("/#/library");
  await chooseView(page, "By need");
  await expect(tiles(page)).toHaveCount(CARDS.length);
}

async function read(request: APIRequestContext): Promise<number[]> {
  const asked = await request.get("/api/needs");
  const { read: done, of } = await asked.json();
  return [done, of];
}

test("no card read yet: a grey line in place of the pills, and every card below", async ({ page, request }) => {
  for (const [title, art] of CARDS) {
    const made = await request.post("/api/cards", { data: cardFile({ name: title, first_mes: `"${QUOTE}"` }, art) });
    expect(made.status(), await made.text()).toBe(201);
  }
  await open(page);
  await expect(row(page)).toContainText("I need…");
  await expect(row(page)).toContainText("The AI reads your characters to sort them by what you may need. They show here once it has.");
  await expect(row(page).locator(".pill")).toHaveCount(0);
});

test("while the cards are read the line says how far, and every card shows; the first need read brings the pills", async ({ page, request }) => {
  const stored = await request.put("/api/provider", { data: { base_url: api.url, model: "small-1" } });
  expect(stored.status(), await stored.text()).toBe(200);
  // A card's tags from here on are the classifier's terms: its own goes in as the engine, whose words the server checks.
  const terms = (tags: string[]) => ({ ...classified, engine: tags[0] });
  const held = JSON.stringify(terms(CARDS[0][2]));
  const first = api.hold([held.slice(0, 8), held.slice(8)]);
  for (const [at, [title, , tags]] of CARDS.entries()) {
    if (at) api.next(reply(terms(tags)));
    api.next(reply({ title, logline: `${title} waits.`, summary: `${title} waits. It is quiet.` }));
  }
  for (const [, , , needs] of CARDS) {
    api.next(reply({ verdict: "classified", reject_reason: "", needs: needs.map(([need, level]) => ({ need, quote: QUOTE, level })) }));
  }
  await open(page);
  expect((await request.post("/api/describe", { data: {} })).status()).toBe(200);
  await expect(row(page)).toContainText(`The AI is reading your characters · 0 of ${CARDS.length}`);
  await expect(tiles(page)).toHaveCount(CARDS.length);
  first.release();
  await expect(row(page).locator(".pill").first()).toBeVisible();
  await expect.poll(() => read(request)).toEqual([CARDS.length, CARDS.length]);
});

test("the pills read as the lines finish, on most cards first, of as many in the list's order; a need no card has does not show", async ({ page }) => {
  await open(page);
  await expect(row(page).locator(".pill")).toHaveText([
    "someone to keep me company",
    "sex",
    "someone to listen to me",
    "to be accepted as I am",
    "to be looked after",
    "to feel safe",
    "to belong somewhere",
    "to be forgiven",
    "to grieve someone",
    "to be admired",
    "to be believed in",
    "to be pushed to do more",
    "to get better at something",
    "to be in control",
    "to decide what to do",
    "to have a purpose",
    "to be somewhere else for a while",
  ]);
});

test("pointed at, a tile shows its needs, strongest first, where Gallery shows the tags", async ({ page }) => {
  await open(page);
  const isolde = page.locator(".tile", { hasText: "Isolde" });
  await isolde.hover();
  await expect(isolde.locator(".tile-tags")).toHaveText("someone to keep me company · sex");
  await expect(isolde.locator(".tile-tags")).toBeVisible();
});

test("picking and unpicking: at once, the best matches first, no number; none picked is every card, zero needs too", async ({ page }) => {
  await open(page);
  await pill(page, "someone to keep me company").click();
  await expect(tiles(page)).toHaveText(["Captain Vale", "Isolde"]);
  await expect(pill(page, "someone to keep me company")).toHaveAttribute("aria-pressed", "true");
  // The list read anew leaves the keyboard's place on the pill.
  await expect(pill(page, "someone to keep me company")).toBeFocused();
  await pill(page, "sex").click();
  await expect(tiles(page)).toHaveText(["Isolde", "Captain Vale", "Wren Halloway"]);
  await expect(page.locator(".gallery")).not.toContainText(/\d/);
  await pill(page, "someone to keep me company").click();
  await expect(tiles(page)).toHaveText(["Isolde", "Wren Halloway"]);
  await expect(pill(page, "someone to keep me company")).toHaveAttribute("aria-pressed", "false");
  await pill(page, "sex").click();
  await expect(tiles(page)).toHaveCount(CARDS.length);
  await expect(page.locator(".tile", { hasText: "Tern Rock" })).toBeVisible();
});

test("the picks go with the search, the Show switch and the tags, and only in this view", async ({ page }) => {
  await open(page);
  await pill(page, "sex").click();
  await expect(tiles(page)).toHaveText(["Isolde", "Wren Halloway"]);

  await page.getByRole("searchbox").fill("Wren");
  await expect(tiles(page)).toHaveText(["Wren Halloway"]);
  await page.getByRole("searchbox").fill("Vale");
  await expect(page.locator(".gallery .empty")).toContainText("for the needs you picked");
  await page.getByRole("searchbox").fill("");
  await expect(tiles(page)).toHaveCount(2);

  // As with a search, the panel lists the tags of the cards the picks leave.
  await page.getByRole("button", { name: /^Sort and filter/ }).click();
  await expect(page.getByRole("button", { name: /^comfort/ })).toBeEnabled();
  await expect(page.getByRole("button", { name: /^mystery/ })).toHaveCount(0);
  await page.keyboard.press("Escape");

  // The other views list every card; coming back the pick stands.
  await chooseView(page, "Gallery");
  await expect(tiles(page)).toHaveCount(CARDS.length);
  await expect(row(page)).toHaveCount(0);
  await chooseView(page, "By need");
  await expect(tiles(page)).toHaveText(["Isolde", "Wren Halloway"]);
  await expect(pill(page, "sex")).toHaveAttribute("aria-pressed", "true");
  await pill(page, "sex").click();
  await expect(tiles(page)).toHaveCount(CARDS.length);
});

test("the view stays chosen for the next start", async ({ page }) => {
  await open(page);
  await page.reload();
  await expect(row(page)).toBeVisible();
  await expect(tiles(page)).toHaveCount(CARDS.length);
});

test("the view says its name and how to pick, Clear unpicks all, a pill keeps its width, and the Sort waits", async ({ page }) => {
  await open(page);
  await expect(page.getByRole("heading", { level: 1 })).toContainText("By need");
  await expect(row(page)).toContainText("Pick one or more. Characters with any of them show.");
  const clear = row(page).getByRole("button", { name: "Clear", exact: true });
  await expect(clear).toBeHidden();
  const sex = pill(page, "sex");
  const before = (await sex.boundingBox())!.width;
  await sex.click();
  await expect(sex).toHaveAttribute("aria-pressed", "true");
  expect((await sex.boundingBox())!.width).toBe(before);
  await pill(page, "someone to keep me company").click();
  await clear.click();
  await expect(tiles(page)).toHaveCount(CARDS.length);
  await expect(row(page).locator("[aria-pressed=true]")).toHaveCount(0);
  await expect(clear).toBeHidden();

  // The order is the needs' here: the panel's Sort cannot be pressed, and says why.
  await page.getByRole("button", { name: /^Sort and filter/ }).click();
  await expect(page.getByRole("button", { name: "Name", exact: true })).toBeDisabled();
  await expect(page.getByRole("dialog")).toContainText("By need orders the characters by how well they fit.");
  await page.keyboard.press("Escape");
});

for (const [width] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height: 900 }, colorScheme: theme });
      test("two needs picked", async ({ page }) => {
        await stopClock(page);
        await open(page);
        await pill(page, "someone to keep me company").click();
        await pill(page, "sex").click();
        await expect(tiles(page)).toHaveText(["Isolde", "Captain Vale", "Wren Halloway"]);
        await page.mouse.move(width - 2, 2);
        await picture(page, `by-need-${width}-${theme}`);
      });
    });
  }
}

test("a pick no card has any more goes, and with it the narrowing", async ({ page, request }) => {
  await open(page);
  await pill(page, "to be pushed to do more").click();
  await expect(tiles(page)).toHaveText(["The Royal Protector"]);
  const { id } = (await (await request.get("/api/cards?q=Protector")).json())[0];
  expect((await request.patch(`/api/cards/${id}`, { data: { trashed: true } })).status()).toBe(200);
  await expect(pill(page, "to be pushed to do more")).toHaveCount(0);
  await expect(tiles(page)).toHaveCount(CARDS.length - 1);
});
