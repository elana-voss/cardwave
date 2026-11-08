import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";

// Personas: one made with "New persona", and the default one, which its row says and as which a new chat
// starts.
//
// One database for the file. Every test starts without personas and makes its own.
test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const toast = (page: Page) => page.locator("#toast");
const names = (page: Page) => page.locator(".card-row .row-title");
const row = (page: Page, name: string) => page.locator(".card-row", { hasText: name });
const more = (page: Page, name: string) => row(page, name).getByRole("button", { name: "More" });
/** Opens a row's menu with the mouse moved onto it first: a list read anew under the resting mouse (after
 *  "Set as default") takes no press until the mouse moves (library/list-screen.ts). */
async function menuOf(page: Page, name: string): Promise<void> {
  const box = (await more(page, name).boundingBox())!;
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await more(page, name).click();
}
const form = (page: Page) => page.locator(".rows-plain .persona-form");
/** The chat's persona field, and the line of it that is chosen. */
const field = (page: Page) => page.getByRole("complementary", { name: "Chat details" }).getByLabel("Persona", { exact: true });
const chosen = (page: Page) => field(page);

/** The card version the chats here are with. */
let pell = 0;

test.beforeAll(async ({ request }) => {
  const response = await request.post("/api/cards", { data: cardFile({ name: "Pell Marsh", first_mes: "Pell greets {{user}}." }) });
  expect(response.status()).toBe(201);
  pell = (await response.json()).version_id;
});

/** Deletes every persona for good, wherever it is. */
test.beforeEach(async ({ request }) => {
  const listed = async (path: string): Promise<{ id: number }[]> => (await request.get(path)).json();
  for (const { id } of await listed("/api/personas")) {
    expect((await request.patch(`/api/personas/${id}`, { data: { trashed: true } })).status()).toBe(200);
  }
  const trash: { items: { kind: string; id: number }[] } = await (await request.get("/api/trash")).json();
  for (const { kind, id } of trash.items) {
    if (kind === "persona") expect((await request.delete(`/api/personas/${id}`)).status()).toBe(204);
  }
});

/** Makes a persona past the page, with the changes named. Returns its id. */
async function add(request: APIRequestContext, name: string, description = "", change?: Record<string, boolean>): Promise<number> {
  const response = await request.post("/api/personas", { data: { name, description } });
  expect(response.status()).toBe(201);
  const { id } = await response.json();
  if (change) await alter(request, id, change);
  return id;
}

async function alter(request: APIRequestContext, id: number, change: Record<string, boolean>): Promise<void> {
  const response = await request.patch(`/api/personas/${id}`, { data: change });
  expect(response.status(), await response.text()).toBe(200);
}

/** Starts a chat with Pell past the page, as a persona if one is named. Returns the chat's id. */
async function chatAs(request: APIRequestContext, persona_id?: number): Promise<number> {
  const response = await request.post("/api/chats", { data: { characters: [{ version_id: pell, character: "pell-marsh" }], persona_id } });
  expect(response.status(), await response.text()).toBe(201);
  return (await response.json()).chat.id;
}

async function open(page: Page): Promise<void> {
  await page.goto("/#/library/personas");
  await expect(page.locator(".rows-plain > li").first()).toBeVisible();
}

/** Opens the form for a new persona, as "Create" in the rail does: the screen has no button for it. */
async function fresh(page: Page): Promise<void> {
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "New persona" }).click();
  await expect(form(page)).toBeVisible();
}

test("New persona opens a form on top of the list, and Save adds the persona", async ({ page, request }) => {
  await add(request, "Abel Marsh");
  await open(page);
  await fresh(page);
  await expect(page.locator(".rows-plain > li").first().locator(".persona-form")).toBeVisible();
  await expect(names(page)).toHaveText(["Abel Marsh"]);
  await expect(form(page).getByLabel("Name")).toBeFocused();
  // The description says who reads it and what goes in it.
  await expect(form(page).getByLabel("Description")).toHaveAttribute("placeholder", "What the characters know about you: looks, age, how you speak");
  // Cancel makes none.
  await form(page).getByLabel("Name").fill("Nobody");
  await form(page).getByRole("button", { name: "Cancel" }).click();
  await expect(form(page)).toHaveCount(0);
  await expect(names(page)).toHaveText(["Abel Marsh"]);

  // A name of spaces is refused in the server's words, and the form stays as it was filled in.
  await fresh(page);
  await expect(form(page).getByLabel("Name")).toHaveValue("");
  await form(page).getByLabel("Name").fill("   ");
  await form(page).getByLabel("Description").fill("A surveyor of the fen.");
  await form(page).getByRole("button", { name: "Save" }).click();
  await expect(page.getByRole("alert")).toHaveText("A persona needs a name.");
  await expect(form(page).getByLabel("Description")).toHaveValue("A surveyor of the fen.");

  await form(page).getByLabel("Name").fill(" Zoe Fenn ");
  await form(page).getByRole("button", { name: "Save" }).click();
  await expect(form(page)).toHaveCount(0);
  await expect(names(page)).toHaveText(["Abel Marsh", "Zoe Fenn"]);
  await expect(row(page, "Zoe Fenn").locator(".excerpt")).toHaveText("A surveyor of the fen.");
  await expect(row(page, "Abel Marsh").locator(".excerpt")).toHaveCount(0);
  await expect(toast(page)).toHaveText("“Zoe Fenn” added.");
  // What went wrong before is no longer said.
  await expect(page.getByRole("alert")).toHaveCount(0);
});

test("a persona is given a picture in its form, which its row shows", async ({ page, request }) => {
  await add(request, "Ines Vale");
  await open(page);
  await row(page, "Ines Vale").hover();
  await row(page, "Ines Vale").getByRole("button", { name: "Edit" }).click();
  const chooser = page.waitForEvent("filechooser");
  await form(page).getByRole("button", { name: "Add picture" }).click();
  // A one-pixel PNG.
  const png = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", "base64");
  await (await chooser).setFiles({ name: "ines.png", mimeType: "image/png", buffer: png });
  await expect(form(page).getByRole("button", { name: "Remove the picture" })).toBeVisible();
  await button(page, "Save").click();
  await expect(row(page, "Ines Vale").locator(".initial img")).toHaveAttribute("src", /^\/api\/personas\/\d+\/picture\?at=/);
});

test("one persona is the default: its row says it is used for new chats, and a new chat starts as it; no Favourites or Archived", async ({ page, request }) => {
  await add(request, "Abel Marsh");
  await add(request, "Zoe Fenn");
  await open(page);
  // Personas have no star and no All / Favourites / Archived switch; the search says what it finds.
  await expect(page.getByRole("button", { name: "Archived" })).toHaveCount(0);
  await expect(page.locator(".star")).toHaveCount(0);
  await expect(page.getByPlaceholder("Find a persona")).toBeVisible();
  await menuOf(page, "Abel Marsh");
  await expect(page.getByRole("menuitem")).toHaveText(["Set as default", "Move to Trash"]);
  await item(page, "Set as default").click();
  await expect(toast(page)).toHaveText("New chats start as “Abel Marsh”.");
  await expect(row(page, "Abel Marsh").getByText("Used for new chats", { exact: true })).toBeVisible();
  await expect(page.getByText("Used for new chats", { exact: true })).toHaveCount(1);
  await menuOf(page, "Abel Marsh");
  await expect(page.getByRole("menuitem")).toHaveText(["Remove as default", "Move to Trash"]);
  await page.keyboard.press("Escape");

  // Another one takes its place.
  await menuOf(page, "Zoe Fenn");
  await item(page, "Set as default").click();
  await expect(toast(page)).toHaveText("New chats start as “Zoe Fenn”.");
  await expect(row(page, "Zoe Fenn").getByText("Used for new chats", { exact: true })).toBeVisible();
  await expect(page.getByText("Used for new chats", { exact: true })).toHaveCount(1);

  // A chat started from here on is as the default, greeting and all.
  const started = await chatAs(request);
  await page.goto(`/#/chats/${started}`);
  await expect(page.locator(".message .text")).toHaveText(["Pell greets Zoe Fenn."]);
  // The field names it alone; its menu says it is the one for new chats, in grey under its name.
  await expect(chosen(page)).toHaveText("Zoe Fenn");
  await chosen(page).click();
  await expect(page.getByRole("menuitemradio", { name: /^Zoe Fenn/ }).locator(".sub")).toHaveText("Used for new chats");
  await page.keyboard.press("Escape");
  // The user's round is the persona's, its initial while it has no picture.
  await page.getByPlaceholder(/^Message/).fill("Hello.");
  await page.getByRole("button", { name: "Send" }).click();
  await expect(page.locator(".message.user .avatar.own")).toHaveText("Z");

  await open(page);
  await menuOf(page, "Zoe Fenn");
  await item(page, "Remove as default").click();
  await expect(toast(page)).toHaveText("New chats start without a persona.");
  await expect(page.getByText("Used for new chats", { exact: true })).toHaveCount(0);
  await page.goto(`/#/chats/${await chatAs(request)}`);
  await expect(page.locator(".message .text")).toHaveText(["Pell greets User."]);
  await expect(chosen(page)).toHaveText("User");
});
