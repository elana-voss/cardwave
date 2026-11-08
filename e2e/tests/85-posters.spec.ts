import type { Locator, Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { cardFile, paintedCardFile, type Paint, type Size } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, stopClock } from "../pictures";

// The Characters page's view Posters. The tests run in turn on one database: its cards are first not described, then
// described by the stand-in `api`, two of each mood in turn, so that the design rule gives every design once. How a
// poster takes its colours and crop is tested in web/src/library/. The stored picture is `posters`, of all designs.

test.describe.configure({ mode: "serial" });

/** Calm above, and busy from the middle on. */
const busyBelow =
  (hue: [number, number, number]): Paint =>
  (x, y, _width, height) =>
    y < height / 2 || (x + y) % 8 < 4 ? hue : [240, 235, 225];
/** Busy down to the middle, and calm below. */
const busyAbove =
  (hue: [number, number, number]): Paint =>
  (x, y, _width, height) =>
    y >= height / 2 || (x + y) % 8 < 4 ? hue : [240, 235, 225];

/** Each card: title, tagline, mood, its picture's size and its paint. Two of a mood get its two designs, in turn. */
const CARDS: [title: string, tagline: string, mood: string, size: Size, paint: Paint][] = [
  ["The Hollow Tide", "It came back wrong.", "horror", [300, 450], busyBelow([40, 60, 70])],
  ["Saint Ember", "Nobody prays here twice.", "horror", [400, 300], busyAbove([80, 30, 30])],
  ["Calm Above", "The letters stopped in June.", "drama", [300, 450], busyBelow([120, 90, 70])],
  ["Busy Above Is Long Enough To Wrap Around", "You owe the house an answer.", "drama", [300, 450], busyAbove([60, 80, 100])],
  ["Amara", "One summer was never the plan.", "romance", [300, 300], busyBelow([200, 90, 110])],
  ["Hearts of Glass", "Careful with this one.", "romance", [300, 450], busyBelow([150, 60, 90])],
  ["Redline", "Last car out takes the blame.", "action", [300, 450], busyBelow([180, 60, 20])],
  ["Hard Stop", "She never reads the warnings.", "action", [240, 500], busyAbove([30, 30, 40])],
  ["Station Nine", "The signal knows your name.", "sci_fi", [300, 450], busyBelow([20, 60, 120])],
  ["Orbit", "Nobody ordered this planet.", "sci_fi", [500, 300], busyBelow([40, 30, 90])],
  ["Bad Neighbours", "They brought a casserole. Run.", "comedy", [300, 450], busyBelow([240, 190, 60])],
  ["Oops", "It was like that when you came.", "comedy", [300, 450], busyAbove([90, 180, 170])],
  ["The Ninth Crown", "The throne remembers who fell.", "fantasy", [300, 450], busyBelow([110, 80, 30])],
  ["Wyrmsong", "Ask it nicely, this once.", "fantasy", [300, 450], busyBelow([60, 110, 60])],
];
const DESIGNS = ["horror", "drama", "romance", "action", "sci_fi", "comedy", "fantasy"].flatMap((mood) => [`poster-${mood}-a`, `poster-${mood}-b`]);
const NO_PICTURE = "Bare Walls";
const NOT_DESCRIBED = "Not Told Yet";
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
const FIRST = { first_mes: "Come in, and shut the door." };

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const reply = (content: unknown) => [JSON.stringify(content)];
/** By the tile's name, where the title is whole: its lines on the page are separate blocks. */
const posterOf = (page: Page, title: string): Locator => page.locator(`.tile[aria-label^="${title}"]`).locator(".poster");

async function open(page: Page): Promise<void> {
  await page.goto("/#/library");
  await chooseView(page, "Posters (experimental)");
}

test("the fifth view, remembered; a card not described is Gallery's plain tile", async ({ page, request }) => {
  for (const [title, , , size, paint] of CARDS) {
    const made = await request.post("/api/cards", { data: paintedCardFile({ name: title, ...FIRST }, size, paint) });
    expect(made.status(), await made.text()).toBe(201);
  }
  for (const [title, size] of [[NO_PICTURE, [1, 1]], [NOT_DESCRIBED, [300, 450]]] as [string, Size][]) {
    expect((await request.post("/api/cards", { data: cardFile({ name: title, ...FIRST }, size) })).status()).toBe(201);
  }
  await page.goto("/#/library");
  await page.locator("button[aria-label=View]:visible").click();
  const fifth = page.locator("[role=menu][aria-label=View]:visible [role=menuitemradio]").nth(4);
  await expect(fifth).toHaveText("Posters (experimental)");
  await fifth.click();
  await page.reload();
  await expect(page.locator(".gallery .tile-title").first()).toBeVisible();
  await expect(page.locator(".poster")).toHaveCount(0);
});

test("each design once, title and tagline on the picture and nothing else", async ({ page, request }) => {
  const stored = await request.put("/api/provider", { data: { base_url: api.url, model: "small-1" } });
  expect(stored.status(), await stored.text()).toBe(200);
  for (const [title, tagline, mood] of CARDS) {
    api.next(reply(classified));
    api.next(reply({ title, logline: `${title} waits.`, summary: `${title} waits. It is quiet.`, tagline, mood }));
  }
  api.next(reply(classified));
  api.next(reply({ title: NO_PICTURE, logline: "It waits.", summary: "It waits. It is quiet.", tagline: "Nothing to see here.", mood: "drama" }));
  api.next(reply(classified));
  api.next(reply({ title: NOT_DESCRIBED, logline: "It waits.", summary: "It waits. It is quiet." }));
  for (let at = 0; at < CARDS.length + 2; at++) api.next(reply({ verdict: "classified", reject_reason: "", needs: [] }));
  expect((await request.post("/api/describe", { data: {} })).status()).toBe(200);
  await expect
    .poll(async () => (await (await request.get("/api/cards?posters=true")).json()).filter((card: { poster: { design: string | null } }) => card.poster.design).length)
    .toBe(CARDS.length + 1);
  await open(page);
  await expect(page.locator(".poster.poster-drawn")).toHaveCount(CARDS.length + 1);
  const classes = await page.locator(".poster").evaluateAll((all) => all.map((one) => [...one.classList].find((name) => /^poster-.+-[ab]$/.test(name))));
  expect(new Set(classes)).toEqual(new Set(DESIGNS));
  const told = page.locator('.tile[aria-label^="Redline"]');
  await expect(told.locator(".poster-tagline")).toHaveText("Last car out takes the blame.");
  await expect(told.locator(".tile-title, .tile-sub, .fav, .tile-hover")).toHaveCount(0);
  await expect(told).toHaveAttribute("aria-label", "Redline. Last car out takes the blame.");
  // The one not told a tagline and mood is the plain tile.
  await expect(page.locator(".gallery .tile-title")).toHaveText([NOT_DESCRIBED]);
  // No picture: the ground and words the rule names.
  const bare = posterOf(page, NO_PICTURE);
  await expect(bare.locator("img")).toHaveCount(0);
  await expect(bare).toHaveCSS("background-color", "rgb(17, 17, 17)");
  await expect(bare.locator(".poster-title")).toHaveCSS("color", "rgb(255, 255, 255)");
  await expect(bare.locator(".poster-tagline")).toHaveCSS("color", "rgb(156, 156, 156)");
});

test("the title leaves its home end where that is much the busier; a picture's colours reach the text", async ({ page }) => {
  await open(page);
  // Both are designs whose title's home is the top: the first drama card is calm there, the second not.
  await expect(posterOf(page, "Calm Above").locator(".poster-top .poster-title")).toHaveCount(1);
  const flipped = posterOf(page, "Busy Above");
  await expect(flipped.locator(".poster-foot .poster-title")).toHaveCount(1);
  await expect(flipped.locator(".poster-line").first()).toBeVisible();
  const ground = await posterOf(page, "Calm Above").evaluate((node) => (node as HTMLElement).style.getPropertyValue("--dk"));
  expect(ground).not.toBe("17 17 17");
});

test("a title longer than its lines stays within them and within the poster", async ({ page }) => {
  await open(page);
  const long = posterOf(page, "Busy Above");
  await expect(long.locator(".poster-line").first()).toBeVisible();
  const lines = await long.locator(".poster-line").count();
  expect(lines).toBeLessThanOrEqual(3);
  const [title, whole] = await Promise.all([long.locator(".poster-title").boundingBox(), long.boundingBox()]);
  expect(title!.x + title!.width).toBeLessThanOrEqual(whole!.x + whole!.width + 1);
});

test("a picture of another shape shows its most detailed part", async ({ page }) => {
  await open(page);
  // Taller than a poster and busy down to its middle: its top is shown, not its centre.
  const shown = posterOf(page, "Hard Stop").locator("img");
  await expect(posterOf(page, "Hard Stop")).toHaveClass(/poster-drawn/);
  const position = await shown.evaluate((node) => getComputedStyle(node).objectPosition);
  expect(parseFloat(position.split(" ")[1])).toBeLessThan(25);
});

test("a face stays clear where the picture's pixels cannot be read", async ({ page }) => {
  await page.addInitScript(() => {
    CanvasRenderingContext2D.prototype.getImageData = () => {
      throw new Error("not readable");
    };
  });
  await page.route(/\/api\/cards(\?|$)/, async (route) => {
    const answer = await route.fetch();
    const cards = await answer.json();
    for (const card of cards) if (card.title === "Calm Above" && card.poster) card.poster.faces = [{ left: 0.3, top: 0.05, width: 0.4, height: 0.2 }];
    await route.fulfill({ response: answer, json: cards });
  });
  await open(page);
  await expect(posterOf(page, "Calm Above").locator(".poster-foot .poster-title")).toHaveCount(1);
  await page.unroute(/\/api\/cards(\?|$)/);
});

test("a face where the text would stand sends the text to the other end", async ({ page }) => {
  await page.route(/\/api\/cards(\?|$)/, async (route) => {
    const answer = await route.fetch();
    const cards = await answer.json();
    for (const card of cards) if (card.title === "Calm Above" && card.poster) card.poster.faces = [{ left: 0.3, top: 0.05, width: 0.4, height: 0.2 }];
    await route.fulfill({ response: answer, json: cards });
  });
  await open(page);
  await expect(posterOf(page, "Calm Above").locator(".poster-foot .poster-title")).toHaveCount(1);
  await page.unroute(/\/api\/cards(\?|$)/);
});

test("the stored picture", async ({ page }) => {
  await stopClock(page);
  // Tall enough for every design.
  await page.setViewportSize({ width: 1440, height: 1760 });
  await open(page);
  await expect(page.locator(".poster.poster-drawn").first()).toBeVisible();
  await page.mouse.move(1438, 2);
  await picture(page, "posters-1440-light");
});
