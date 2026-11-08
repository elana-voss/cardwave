import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// "Describe all again", on the line "Characters described" in Settings › Advanced's group Library: its cost, how far it has
// come, Stop, and a failure. The tests build on each other's cards in this order, as a spec's server is one (the first
// needs it empty). The stand-in `api` is told each answer in turn, a character's three calls: classify, write, needs;
// no test asks a provider.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const NEEDS = JSON.stringify({ verdict: "classified", needs: [{ need: "keep_company", quote: "Pell", level: 3 }] });
const CLASSIFIED = JSON.stringify({
  verdict: "classified",
  characters: [{ name: "Pell", gender: "male", age: "adult" }],
  pairing: "unspecified",
  engine: "comfort",
  multi_mode: false,
  per_greeting: [],
  frame: "neighbor",
  frame_display: "neighbor",
  rating: "sfw",
  content_flags: [],
  archetype: ["grump"],
});
const WRITTEN = JSON.stringify({ title: "The Marsh Neighbor", logline: "A neighbor at the marsh.", summary: "Pell keeps to himself. He lives by the marsh. He comes round." });

/** The first call of a character held until the test says, and the two after it answered. */
function holdCharacter() {
  const reply = api.hold([CLASSIFIED.slice(0, 10), CLASSIFIED.slice(10)]);
  api.next([WRITTEN]);
  api.next([NEEDS]);
  return reply;
}

async function importCard(request: APIRequestContext, name: string): Promise<number> {
  const response = await request.post("/api/cards", { data: cardFile({ name, first_mes: "Oh. It's you, {{user}}." }) });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).card_id;
}

const line = (page: Page) => page.locator(".item", { has: page.locator(".item-label", { hasText: /^Characters described$/ }) });
const says = (page: Page) => line(page).locator(".meta").first();
const press = (page: Page) => line(page).getByRole("button", { name: "Describe all again" });

let first = 0;

test("with no characters there is nothing to describe; one that could not be described says so in the line, and why", async ({ page, request }) => {
  const stored = await request.put("/api/provider", { data: { base_url: api.url, model: "small-1" } });
  expect(stored.status(), await stored.text()).toBe(200);
  await page.goto("/#/settings/advanced");
  await expect(says(page)).toHaveText("No characters to describe");
  await expect(press(page)).toBeDisabled();
  await expect(line(page).getByRole("button", { name: "Describe characters" })).toBeDisabled();

  first = await importCard(request, "Pell Marsh");
  await page.reload();
  await expect(line(page).locator(".meta").last()).toContainText("about 11,000 to 12,000 tokens each");
  api.fail(500, "no");
  api.next([NEEDS]);
  await press(page).click();
  await expect(line(page).locator(".item-wrong:not(:empty)")).toContainText("1 failed and stays as it was: ");
});

test("it says how far it has come, and Stop ends it after the character being read", async ({ page, request }) => {
  const ids = [first, await importCard(request, "Odo Fenn")];
  await page.goto("/#/settings/advanced");
  await expect(press(page)).toBeEnabled();

  const reply = holdCharacter();
  await press(page).click();
  await expect(says(page)).toHaveText("0 of 2 described again");
  await line(page).getByRole("button", { name: "Stop" }).click();
  await expect(press(page)).toBeEnabled();
  await expect(says(page)).not.toContainText("described again");
  reply.release();

  // The character in hand gets its new needs; the other was never asked.
  const states = async () => Promise.all(ids.map(async (id) => (await (await request.get(`/api/cards/${id}`)).json()).needs.state));
  await expect.poll(async () => (await states()).filter((state) => state === "found").length).toBe(1);
});

test("a reading sent before the press and answered after it does not undo the press", async ({ page, request }) => {
  await page.goto("/#/settings/advanced");
  await expect(press(page)).toBeEnabled();

  // The first reading after this point is fetched as it is sent and handed over only when `late` says; the readings
  // after it wait until the test has looked, as when the worker is busy and no newer reading comes.
  let sent = false;
  let handOver = () => {};
  const late = new Promise<void>((resolve) => (handOver = resolve));
  let held = () => {};
  const asked = new Promise<void>((resolve) => (held = resolve));
  let answered = () => {};
  const given = new Promise<void>((resolve) => (answered = resolve));
  let looked = () => {};
  const seen = new Promise<void>((resolve) => (looked = resolve));
  await page.route("**/api/describe/again", async (route) => {
    if (route.request().method() !== "GET") return route.continue();
    if (sent) {
      await seen;
      return route.continue();
    }
    sent = true;
    const old = await route.fetch();
    held();
    await late;
    await route.fulfill({ response: old });
    answered();
  });
  await request.delete("/api/describe/again"); // says "descriptions" to the page, which reads anew
  await asked;

  const reply = holdCharacter();
  await press(page).click();
  await expect(says(page)).toHaveText("0 of 2 described again");
  handOver();
  await given;
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(done)));
  await expect(says(page)).toHaveText("0 of 2 described again");
  await expect(line(page).getByRole("button", { name: "Stop" })).toBeVisible();
  looked();

  await line(page).getByRole("button", { name: "Stop" }).click();
  await expect(press(page)).toBeEnabled();
  reply.release();
  await page.unroute("**/api/describe/again");
});

test("why a press was refused stays when the page reads anew", async ({ page, request }) => {
  await page.route("**/api/describe", async (route) => {
    if (route.request().method() === "POST") return route.fulfill({ status: 424, contentType: "application/json", body: "{}" });
    const real = await route.fetch();
    await route.fulfill({ json: { ...(await real.json()), left: 1, waiting: 0 } });
  });
  await page.goto("/#/settings/advanced");
  await line(page).getByRole("button", { name: "Describe characters" }).click();
  await expect(line(page).locator(".item-wrong:not(:empty)")).toContainText("That could not be done.");
  await expect(press(page)).toBeEnabled();
  await page.route("**/api/describe/again", (route) =>
    route.request().method() === "POST"
      ? route.fulfill({ status: 424, contentType: "application/json", body: "{}" })
      : route.continue(),
  );
  await press(page).click();
  await expect(line(page).locator(".item-wrong:not(:empty)")).toContainText("That could not be done.");

  const read = page.waitForResponse((answer) => answer.url().endsWith("/api/describe/again") && answer.request().method() === "GET");
  await request.delete("/api/describe/again"); // says "descriptions" to the page, which reads anew
  await read;
  await page.evaluate(() => new Promise((done) => requestAnimationFrame(done)));
  await expect(line(page).locator(".item-wrong:not(:empty)")).toContainText("That could not be done.");
});
