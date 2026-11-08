import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// The character generator: Create's "New character" page offers it; picks,
// Random and "Make the card" have the pretend model write the greeting and the examples, and the new card's page
// opens. While it writes the picks are greyed and Stop gives the page back; a failure stands in red over the
// button with the picks kept. A test holds the answer back, or fails it, with `page.route` on `/api/generator`.
test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const make = (page: Page) => button(page, "Make the character");

test.beforeAll(async ({ request }) => {
  const provider = await request.put("/api/provider", { data: { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" } });
  expect(provider.status()).toBe(200);
});

test("Create's \"New character\" offers the character generator, which opens it", async ({ page }) => {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New character" }).click();
  await page.getByRole("link", { name: /^Character generator/ }).click();
  await expect(page).toHaveURL(/#\/generator$/);
  await expect(page.locator("h1")).toHaveText("Character generator");
  // The closed Create menu stays in the rail's DOM, hidden, so the rail's text still holds its line.
  await expect(page.locator("#rail").getByRole("link", { name: "Character generator" })).toHaveCount(0);
});

test("picks and Random make a card whose page opens with the model's greeting", async ({ page, request }) => {
  await page.goto("/#/generator");
  // Each look's row starts at "Any"; a look left so is picked by the server.
  const looks = ["Gender", "Human or not", "Age", "Build", "Hair", "Hair colour"];
  for (const look of looks) await expect(page.getByRole("group", { name: look, exact: true }).getByRole("button", { name: "Any" })).toHaveAttribute("aria-pressed", "true");
  await button(page, "Man").click();
  await button(page, "Human").click();
  await expect(button(page, "Man")).toHaveAttribute("aria-pressed", "true");
  await expect(button(page, "Woman")).toHaveAttribute("aria-pressed", "false");
  await expect(page.getByRole("group", { name: "Gender" }).getByRole("button", { name: "Any" })).toHaveAttribute("aria-pressed", "false");
  await button(page, "Mentor").click();
  await page.getByRole("slider", { name: "Shy to Outgoing" }).fill("95");
  await button(page, "Random").click();
  const name = await page.getByRole("textbox", { name: "Name" }).inputValue();
  expect(name).toMatch(/^\S+ \S+$/);
  await make(page).click();
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await expect(page.getByText("This greeting is the pretend model's.")).toBeVisible();

  const cards = (await (await request.get("/api/cards")).json()) as { id: number; title: string }[];
  const card = cards.find((one) => one.title === name)!;
  const edit = await (await request.get(`/api/cards/${card.id}/edit`)).json();
  expect(edit.characters[0].description[0].text).toMatch(/^\{\{char\}\} is a man \(he\/him\) [a-z ]+, [a-z ]+, with [a-z]+ [a-z]+ hair\.$/);
  expect(edit.characters[0].personality[0].text).toBe("{{char}} is extremely outgoing.");
  expect(edit.characters[0].scenario[0].text).toContain("{{user}}'s mentor");
});

test("while the card is written the picks are greyed, and Stop gives the page back with no card", async ({ page, request }) => {
  let reached!: () => void;
  const asked = new Promise<void>((done) => (reached = done));
  await page.route("**/api/generator", async () => reached());
  await page.goto("/#/generator");
  await page.getByRole("textbox", { name: "Name" }).fill("Held Back");
  await make(page).click();
  await asked;
  await expect(button(page, "Writing the character…")).toBeDisabled();
  await expect(button(page, "Woman")).toBeDisabled();
  await expect(page.getByRole("textbox", { name: "Name" })).toBeDisabled();
  await button(page, "Stop").click();
  await expect(make(page)).toBeEnabled();
  await expect(button(page, "Stop")).toBeHidden();
  await expect(button(page, "Woman")).toBeEnabled();
  await expect(page.getByRole("textbox", { name: "Name" })).toHaveValue("Held Back");
  const cards = (await (await request.get("/api/cards")).json()) as { title: string }[];
  expect(cards.some((card) => card.title === "Held Back")).toBe(false);
});

test("a failure stands in red over the button with the picks kept, and pressing it again tries again", async ({ page }) => {
  let tries = 0;
  await page.route("**/api/generator", (route) =>
    ++tries === 1 ? route.fulfill({ status: 400, contentType: "application/json", body: JSON.stringify({ code: "model_answer", error: "the model wrote no greeting", details: { what: "no_greeting" } }) }) : route.fallback(),
  );
  await page.goto("/#/generator");
  await button(page, "Partner").click();
  await page.getByRole("textbox", { name: "Name" }).fill("Second Try");
  await make(page).click();
  await expect(page.getByRole("alert")).toHaveText("The AI wrote no greeting.");
  await expect(button(page, "Partner")).toHaveAttribute("aria-pressed", "true");
  await make(page).click();
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  expect(tries).toBe(2);
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the character generator", async ({ page }) => {
        await page.goto("/#/generator");
        await expect(make(page)).toBeVisible();
        await picture(page, `generator-${width}-${theme}`);
      });
    });
  }
}
