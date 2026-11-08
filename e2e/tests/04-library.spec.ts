import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile, ccv4File } from "../card";

// The library's list of characters: the search, Delete with its Undo, and a card's page opened from its
// title.
//
// One database for the file: the tests build on each other and look only at their own cards, found by search.
// The test of Delete builds on the test before it (`quillsWithout`) and fails alone.
test.describe.configure({ mode: "serial" });

const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const search = (page: Page) => page.getByLabel("Search characters");
const titles = (page: Page) => page.locator(".card-row .row-title");
const row = (page: Page, title: string) => page.locator(".card-row", { hasText: title });
const toast = (page: Page) => page.locator("#toast");
/** A part of the character page, by its heading. */
const part = (page: Page, name: string) => page.locator(".reading section", { has: page.getByRole("heading", { name, exact: true }) });

/** A card with two characters. */
const QUAY = `
spec = "ccv4:1.0.0"

[meta-info]
title = "The Quay"
tags = ["harbourside"]

[name.ada]
text = "Ada"

[name.ben]
text = "Ben"

[greeting.ada]
text = "Ada waves."

[greeting.ben]
text = "Ben nods."

[character.ada]
name-card = "Ada (harbour master)"
name-char = "name.ada"
greetings = ["greeting.ada"]
prompt = ["CHAT-HISTORY"]

[character.ben]
name-card = "Ben (ferryman)"
name-char = "name.ben"
greetings = ["greeting.ben"]
prompt = ["CHAT-HISTORY"]
`;

/** A card with all the texts its page shows, the description a long one. */
const NELL = {
  name: "Nell Quay",
  description: Array.from({ length: 30 }, (_, line) => `Line ${line + 1} of what {{char}} is like.`).join("\n"),
  personality: "Dry, patient.",
  mes_example: "<START>\n{{user}}: Tea?\n{{char}}: Black.",
  creator_notes: "Best with short replies.\n\nKeep the lamp in the story.",
  creator: "Erin",
  tags: ["quayside", "keeper"],
  first_mes: "Hello {{user}}, I am {{char}}.",
  alternate_greetings: ["Second greeting.", "Third greeting."],
};

const ids: Record<"zara" | "zeno" | "zelda" | "nell" | "quay" | "bare", number> = { zara: 0, zeno: 0, zelda: 0, nell: 0, quay: 0, bare: 0 };

async function add(request: APIRequestContext, file: Buffer): Promise<number> {
  const response = await request.post("/api/cards", { data: file });
  expect(response.status()).toBe(201);
  return (await response.json()).card_id;
}

test.beforeAll(async ({ request }) => {
  const quill = (name: string, tag: string, first_mes: string) => cardFile({ name, tags: ["quillfolk", tag], first_mes });
  ids.zara = await add(request, quill("Zara Quill", "sea", "*Zara looks up.* Hello {{user}}, I am {{char}}."));
  ids.zeno = await add(request, quill("Zeno Quill", "quillpeak", "Zeno nods."));
  ids.zelda = await add(request, quill("Zelda Quill", "reeds", "Zelda hums."));
  ids.nell = await add(request, cardFile(NELL));
  ids.quay = await add(request, ccv4File(QUAY));
  ids.bare = await add(request, ccv4File('spec = "ccv4:1.0.0"\n\n[meta-info]\ntitle = "Bare Quay"\n'));
});

/** Opens the library with the three Quill cards in the list. */
async function quills(page: Page): Promise<void> {
  await page.goto("/#/library");
  await search(page).fill("quillfolk");
  await expect(titles(page)).toHaveCount(3);
}

test("search finds cards by name and by tag, once typing pauses", async ({ page }) => {
  const asked: string[] = [];
  page.on("request", (request) => {
    const url = new URL(request.url());
    if (url.pathname === "/api/cards" && url.searchParams.has("q")) asked.push(url.searchParams.get("q")!);
  });
  await page.goto("/#/library");
  // Key by key, with less between two keys than the pause a search waits for.
  await search(page).pressSequentially("ZARA", { delay: 50 });
  await expect(titles(page)).toHaveText(["Zara Quill"]);
  expect(asked).toEqual(["ZARA"]);

  await search(page).fill("quillpeak");
  await expect(titles(page)).toHaveText(["Zeno Quill"]);
  await search(page).fill("quillfolk zel");
  await expect(titles(page)).toHaveText(["Zelda Quill"]);
  await search(page).fill("no-such-quill");
  await expect(page.getByText("No characters match “no-such-quill”.")).toBeVisible();
  await expect(titles(page)).toHaveCount(0);
});

test("a list read anew under a resting pointer: the row that stays there takes the click, one moved there not until the pointer moves", async ({ page }) => {
  await quills(page);
  const first = page.locator(".card-row").first();
  const box = (await first.boundingBox())!;
  const x = box.x + box.width / 3;
  const y = box.y + box.height / 2;
  const id = Number((await first.locator(".row-link").getAttribute("href"))!.split("/").pop());
  await page.mouse.move(x, y);
  // Another window moves the card under the pointer to the trash: the next row comes up under the resting pointer.
  await page.request.patch(`/api/cards/${id}`, { data: { trashed: true } });
  await expect(titles(page)).toHaveCount(2);
  await page.mouse.down();
  await page.mouse.up();
  await expect(page).not.toHaveURL(/#\/library\/\d/);
  await page.request.patch(`/api/cards/${id}`, { data: { trashed: false } });
  await expect(titles(page)).toHaveCount(3);
  // Another window changes the card under the pointer: it stays where it was, and a click in place opens it.
  await page.mouse.move(x + 2, y);
  await page.request.patch(`/api/cards/${id}`, { data: { favorite: true } });
  await expect(first.locator(".star")).toHaveAttribute("aria-pressed", "true");
  await page.mouse.down();
  await page.mouse.up();
  await expect(page).toHaveURL(new RegExp(`#/library/${id}$`));
  await page.request.patch(`/api/cards/${id}`, { data: { favorite: false } });
});

test("Move to Trash moves a card to the trash and Undo brings it back", async ({ page }) => {
  await quills(page);
  const zelda = row(page, "Zelda Quill");
  const remove = async () => {
    await zelda.getByRole("button", { name: "More" }).click();
    await item(page, "Move to Trash").click();
    await expect(toast(page)).toContainText("“Zelda Quill” moved to Trash.");
    await expect(zelda).toHaveCount(0);
  };
  await remove();
  expect((await (await page.request.get(`/api/cards/${ids.zelda}`)).json()).card.trashed).toBe(true);
  await toast(page).getByRole("button", { name: "Undo" }).click();
  await expect(zelda).toHaveCount(1);
  await expect(toast(page)).toBeHidden();
  expect((await (await page.request.get(`/api/cards/${ids.zelda}`)).json()).card.trashed).toBe(false);

  // The notice goes when the screen does.
  await remove();
  await page.getByRole("link", { name: "Chats", exact: true }).click();
  await expect(page).toHaveURL(/#\/chats$/);
  await expect(toast(page)).toBeHidden();
  // A search does not find what is in the trash.
  await quillsWithout(page);
});


/** The library with the Quill cards that are left once Zelda is in the trash. */
async function quillsWithout(page: Page): Promise<void> {
  await page.goto("/#/library");
  await search(page).fill("quillfolk");
  await expect(titles(page)).toHaveCount(2);
  await expect(row(page, "Zelda Quill")).toHaveCount(0);
}

// The character page.

test("a card's title in the list opens its page, with its tags, facts and texts", async ({ page }) => {
  await page.goto("/#/library");
  await page.getByRole("link", { name: "Nell Quay", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`#/library/${ids.nell}$`));
  await expect(page.getByRole("heading", { name: "Nell Quay", level: 1 })).toBeVisible();
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Characters"]);

  const side = page.locator(".side");
  // One tag to a line, then what the card says of itself; the facts of its character are spec 39's.
  expect(await side.locator("div:not(.facts) p").allInnerTexts()).toEqual(["quayside\nkeeper", "Plays Nell Quay\nby Erin"]);

  // The page's head is the path alone, without tabs: the rail has the library's sections.
  const path = page.getByRole("navigation", { name: "Where you are" });
  await expect(page.locator(".pbar .tabs")).toHaveCount(0);
  await expect(path).toHaveText("Characters/Nell Quay");
  await expect(path.locator("span")).toHaveCSS("font-weight", "400");
  const [bar, right] = [(await page.locator(".pbar").boundingBox())!, (await path.boundingBox())!];
  expect(right.x).toBeCloseTo(bar.x, 0);
  // The page's one name is the card's.
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(["Nell Quay"]);
  // A title too long for the path is cut there: the head stays one line, and the page as wide as it was.
  await path.locator("span").evaluate((node) => (node.textContent = "A title that goes on and on. ".repeat(12)));
  const cut = (await path.boundingBox())!;
  expect(cut.height).toBeLessThan(30);
  expect(await page.locator(".main").evaluate((node) => node.scrollWidth <= node.clientWidth)).toBe(true);

  // The texts rendered, their macros read as the names, "User" without a persona.
  await expect(part(page, "First message").locator(".md")).toHaveText("Hello User, I am Nell Quay.");
  await expect(part(page, "Description")).toContainText("Line 1 of what Nell Quay is like.");
  await expect(part(page, "Personality").locator(".md")).toHaveText("Dry, patient.");
  await expect(part(page, "Example dialogue")).toContainText("User: Tea?Nell Quay: Black.");
  // An empty line starts a new paragraph.
  await expect(part(page, "Creator notes").locator(".md p")).toHaveText(["Best with short replies.", "Keep the lamp in the story."]);
  // A text the card lacks asks for its words.
  await expect(part(page, "Scenario").locator(".tb-body")).toHaveText("Empty · where and when the chat begins");
  await expect(page.getByRole("heading", { name: "Chats", exact: true })).toHaveCount(0);

  // The path leads back to the characters, whose page is called so.
  await path.getByRole("link", { name: "Characters" }).click();
  await expect(page).toHaveURL(/#\/library$/);
  await expect(page.getByRole("heading", { name: "Characters", level: 1 })).toBeVisible();
});

