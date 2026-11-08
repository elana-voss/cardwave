import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// Cards described by the worker model: "Describe characters" and the switch for each card imported, in Settings ›
// Advanced's group Library, and what a description brings to the library's row and the card's page. The stand-in `api` is
// told each answer in turn (`answers`): the classifier's, then the writer's, then, where the test waits for all of a card, the needs'; no test asks a provider.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const CLASSIFIED = {
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
  mechanism: "brings you soup",
};
const LOGLINE = "Your grumpy neighbor brings soup whether you want it or not.";
const SUMMARY = "Pell lives next door. The marsh floods every spring. It is gentle and dry.";

/** The classifier's answer, then the writer's, titled `title`. */
const answers = (title: string) => {
  api.next([JSON.stringify(CLASSIFIED)]);
  api.next([JSON.stringify({ title, logline: LOGLINE, summary: SUMMARY })]);
};

async function setUp(request: APIRequestContext): Promise<void> {
  const stored = await request.put("/api/provider", { data: { base_url: api.url, model: "small-1" } });
  expect(stored.status(), await stored.text()).toBe(200);
}

async function importCard(request: APIRequestContext, name: string): Promise<number> {
  const file = cardFile({ name, first_mes: "Oh. It's you, {{user}}.", mes_example: "<START>\n{{char}}: Soup." });
  const response = await request.post("/api/cards", { data: file });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).card_id;
}

const line = (page: Page, name: string) => page.locator(".item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });

test("Describe characters describes every character not described yet, for the library and the card's page", async ({ page, request }) => {
  await setUp(request);
  const id = await importCard(request, "Pell Marsh");
  await page.goto("/#/settings/advanced");
  const described = line(page, "Characters described");
  await expect(described.locator(".meta").first()).toHaveText("1 character not described yet");

  answers("The Marsh Neighbor");
  api.next([JSON.stringify({ verdict: "classified", needs: [{ need: "keep_company", quote: "", level: 0 }] })]);
  await page.getByRole("button", { name: "Describe characters" }).click();
  await expect(described.locator(".meta").first()).toHaveText("Every character is described");
  await expect(page.getByRole("button", { name: "Describe characters" })).toBeDisabled();

  // The row: the title written, the classifier's terms as tags, the logline in place of the greeting.
  await page.goto("/#/library");
  const row = page.locator(".card-row", { hasText: "The Marsh Neighbor" });
  await expect(row.locator(".tags")).toHaveText("neighbor · comfort · grump · sfw");
  await expect(row.locator(".excerpt")).toHaveText(LOGLINE);

  // The page: the summary, the content level as a chip, the tags without it, and the facts.
  await page.goto(`/#/library/${id}`);
  await expect(page.locator(".hero-text .logline")).toHaveText(SUMMARY);
  await expect(page.locator(".pills .pill")).toHaveText(["For everyone"]);
  const side = page.locator(".side");
  expect(await side.locator("div", { has: page.getByRole("heading", { name: "Tags" }) }).locator("p").innerText()).toBe("neighbor\ncomfort\ngrump");
  await expect(side.locator(".facts p")).toHaveText(/^[\d,]+ tokens$/);

  // The summary is written in place, and stays.
  await page.locator(".hero-text .logline").click();
  await page.getByRole("textbox", { name: "One-line summary for the library", exact: true }).fill("  A neighbor who grumbles and stays.  ");
  await page.getByRole("textbox", { name: "One-line summary for the library", exact: true }).evaluate((node) => (node as HTMLElement).blur());
  await expect(page.locator(".hero-text .logline")).toHaveText("A neighbor who grumbles and stays.");
  await expect.poll(async () => (await (await request.get(`/api/cards/${id}`)).json()).summary).toBe("A neighbor who grumbles and stays.");
  // The page drawn anew, as for a greeting added, has it too.
  await page.getByRole("button", { name: "Add a first message" }).click();
  await expect(page.locator(".hero-text .logline")).toHaveText("A neighbor who grumbles and stays.");
});

test("a card put into the Trash while a text of it is written says so when the page is read again", async ({ page, request }) => {
  await setUp(request);
  const id = await importCard(request, "Ash Fen");
  await importCard(request, "Rook Fen");
  await page.goto(`/#/library/${id}`);
  await page.locator("section.tb", { has: page.getByRole("heading", { name: "Personality", exact: true }) }).locator(".tb-body").click();
  await expect(page.getByRole("textbox", { name: "Personality", exact: true })).toBeFocused();
  expect((await request.patch(`/api/cards/${id}`, { data: { trashed: true } })).status()).toBe(200);
  // Describing the other card has every page of a card read again.
  answers("Rook of the Fen");
  expect((await request.post("/api/describe", { data: {} })).status()).toBe(200);
  await expect(page.getByText("This character is in the Trash.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Character menu" })).toHaveCount(0);
});

test("with the switch on, each card imported says Describing… until it is described", async ({ page, request }) => {
  await setUp(request);
  await page.goto("/#/settings/advanced");
  const toggle = page.getByRole("switch", { name: "Describe imported characters" });
  await expect(toggle).not.toBeChecked();
  // While the change is on its way the switch cannot be pressed again.
  let letGo = () => {};
  const held = new Promise<void>((go) => (letGo = go));
  await page.route("**/api/settings", async (route) => {
    if (route.request().method() === "PATCH") await held;
    await route.fallback();
  });
  await toggle.click();
  await expect(toggle).toBeDisabled();
  letGo();
  await expect(toggle).toBeEnabled();
  await expect(toggle).toBeChecked();
  await expect.poll(async () => (await (await request.get("/api/settings")).json()).describe_imported).toBe(true);

  await page.goto("/#/library");
  const reply = api.hold([JSON.stringify(CLASSIFIED).slice(0, 10), JSON.stringify(CLASSIFIED).slice(10)]);
  api.next([JSON.stringify({ title: "Second Neighbor", logline: LOGLINE, summary: SUMMARY })]);
  await importCard(request, "Odo Fenn");
  const row = page.locator(".card-row", { hasText: "Odo Fenn" });
  await expect(row.getByText("The AI is describing the character…")).toBeVisible();
  reply.release();
  const done = page.locator(".card-row", { hasText: "Second Neighbor" });
  await expect(done.locator(".excerpt")).toHaveText(LOGLINE);
  await expect(done.getByText("The AI is describing the character…")).toHaveCount(0);
});
