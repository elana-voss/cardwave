import type { APIRequestContext } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { picture, stopClock } from "../pictures";

// Assistant and companion: the card's page shows the texts of the mode its switch picks, each text's tag sets the
// modes it is used in, and the card menu's "Add a way to chat…" and "Modes…" add, rename, make default and remove; a chat's pill says the mode
// the chat picked (the stand-in `api` picks it, `picks`) and sets one by hand; in Assistant the side panel has the
// character's personality, its tools as switches; and a reply that offers a coding task opens the dialog that
// starts it, filled in. The picture (1440 px, light) is of the chat with its pill's menu open and the personality
// in the side panel.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** A card of Gwen, with the modes `modes`: its number. */
async function card(request: APIRequestContext, modes: string[]): Promise<number> {
  const data = { title: "Gwen", tags: [], creator: "", name: "Gwen", greetings: ["Hello."], description: "Who she is, in every mode.", personality: "How she speaks in a scene.", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const id = (await made.json()).card_id;
  if (modes.length) {
    const edit = await (await request.get(`/api/cards/${id}/edit`)).json();
    const saved = await request.put(`/api/cards/${id}/edit`, { data: { ...edit, modes } });
    expect(saved.status(), await saved.text()).toBe(200);
  }
  return id;
}

/** A chat with the card `id`: its number. */
async function chat(request: APIRequestContext, id: number): Promise<number> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const shown = await (await request.get(`/api/cards/${id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: shown.card.version_id, character: shown.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

test("the card's page shows a mode's texts, a text's tag sets its modes, and the card menu adds and changes modes", async ({ page, request }) => {
  const id = await card(request, []);
  const form = async () => (await request.get(`/api/cards/${id}/edit`)).json();
  const named = (name: string) => page.locator("section.tb", { has: page.getByRole("heading", { name, exact: true }) }).locator(".tb-body");
  const menu = () => page.locator(".hero-acts").getByRole("button", { name: "Character menu" }).click();
  const modes = page.getByRole("group", { name: "Mode" });
  const tag = (name: string) => page.locator("section.tb", { has: page.getByRole("heading", { name, exact: true }) }).locator(".mtag");
  await page.goto(`/#/library/${id}`);
  // Without modes there is no bar and no tag; "Add a way to chat…" adds the first beside the card's own texts,
  // which stay its default way to chat, "Roleplay".
  await expect(named("Personality")).toHaveText("How she speaks in a scene.");
  await expect(modes).toHaveCount(0);
  await expect(page.locator(".mtag")).toHaveCount(0);
  await menu();
  await page.getByRole("menuitem", { name: "Add a way to chat…" }).click();
  await page.getByRole("textbox", { name: "Name" }).fill("Assistant");
  await page.getByRole("button", { name: "Add", exact: true }).click();
  await expect(modes.locator('[aria-pressed="true"]')).toHaveText("Roleplay");
  await expect(page.locator(".mode-bar")).toContainText("The texts below are the ones this mode uses.");
  await expect(tag("Personality")).toHaveText("Roleplay only");
  await expect(tag("Description")).toHaveText("Roleplay only");

  // "Modes…" lists both; a name the card has is refused.
  await menu();
  await page.getByRole("menuitem", { name: "Modes…" }).click();
  const dialog = page.getByRole("dialog", { name: "Modes" });
  await expect(dialog.locator(".modes-list .mode-name")).toHaveText(["Roleplay · default", "Assistant"]);
  await dialog.getByRole("button", { name: "Add a way to chat" }).click();
  await page.getByRole("textbox", { name: "Name" }).fill("roleplay");
  await page.getByRole("button", { name: "Add", exact: true }).click();
  await expect(page.getByRole("alert")).toHaveText("The character has a mode “roleplay” already.");
  await page.getByRole("textbox", { name: "Name" }).press("Escape");
  await dialog.press("Escape");

  // In Assistant the personality is an empty one to write, which is Assistant's.
  await modes.getByRole("button", { name: "Assistant" }).click();
  await expect(named("Personality")).toHaveText("Empty · how the character thinks, talks and acts");
  await named("Personality").click();
  await page.getByRole("textbox", { name: "Personality", exact: true }).fill("How she answers at work.");
  await page.getByRole("textbox", { name: "Personality", exact: true }).evaluate((node) => (node as HTMLElement).blur());
  await expect(tag("Personality")).toHaveText("Assistant only");
  await expect.poll(async () => (await form()).characters[0].personality.map((one: { text: string; modes?: string[] }) => [one.text, one.modes])).toEqual([
    ["How she speaks in a scene.", ["Roleplay"]],
    ["How she answers at work.", ["Assistant"]],
  ]);
  // The tag's menu takes a mode in: a text in every mode is in all modes.
  await modes.getByRole("button", { name: "Roleplay" }).click();
  await expect(named("Personality")).toHaveText("How she speaks in a scene.");
  await tag("Description").click();
  await page.getByRole("menuitemradio", { name: "Assistant only" }).click();
  await expect(tag("Description")).toHaveText("All modes");

  // Rename, Make default and Remove: a text left in no mode is in all modes.
  await menu();
  await page.getByRole("menuitem", { name: "Modes…" }).click();
  await dialog.locator("li", { hasText: "Assistant" }).getByRole("button", { name: "Rename" }).click();
  await page.getByRole("textbox", { name: "Name" }).fill("Work");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await dialog.locator("li", { hasText: "Work" }).getByRole("button", { name: "Make default" }).click();
  await expect(dialog.locator(".modes-list .mode-name")).toHaveText(["Work · default", "Roleplay"]);
  await dialog.locator("li", { hasText: "Roleplay" }).getByRole("button", { name: "Remove" }).click();
  await expect(dialog.locator(".modes-list .mode-name")).toHaveText(["Work · default"]);
  await expect.poll(async () => {
    const now = await form();
    return [now.modes, now.characters[0].personality.map((one: { modes?: string[] }) => one.modes ?? [])];
  }).toEqual([["Work"], [[], ["Work"]]]);
});

test("a chat picks its mode, the user sets one, and the assistant has its tools and offers a coding task", async ({ page, request }) => {
  const id = await chat(request, await card(request, ["Roleplay", "Assistant"]));
  await page.goto(`/#/chats/${id}`);
  const pill = page.locator(".mode-pill");
  await expect(pill).toHaveText("Roleplay · automatic");
  await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeHidden();

  // The chat picks Assistant: the side panel has the character's personality.
  api.picks("Assistant");
  await page.getByLabel("Message", { exact: true }).fill("Help me with my project.");
  await page.getByLabel("Message", { exact: true }).press("Enter");
  await expect(pill).toHaveText("Assistant · automatic");
  await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeVisible();
  // The reply's end draws the side panel anew, so the switches are used after it.
  await expect(page.getByText("Echo: Help me with my project.")).toBeVisible();
  const tools = page.getByRole("button", { name: /^Tools/ });
  await expect(tools).toContainText("Coding tasks");
  // A plain side line as wide as the panel, "Tools" on one line above what is on.
  const label = await tools.getByText("Tools", { exact: true }).boundingBox();
  const line = await tools.boundingBox();
  expect(label!.height).toBeLessThan(30);
  expect(await tools.evaluate((node) => getComputedStyle(node).backgroundColor)).toBe("rgba(0, 0, 0, 0)");
  expect(line!.width).toBeGreaterThan(200);
  await tools.click();
  await page.getByRole("switch", { name: "Coding tasks" }).click();
  await expect(tools).toContainText("None");
  await page.getByRole("switch", { name: "Coding tasks" }).click();
  await expect(tools).toContainText("Coding tasks");
  await expect(page.getByRole("switch", { name: "Memory" })).toBeChecked();

  // The assistant offers a coding task: the dialog to start it, with its goal.
  api.calls("start_coding_task", { goal: "Add a test for the export." });
  api.next(["I have set it up for you."]);
  await page.getByLabel("Message", { exact: true }).fill("Can your team add a test?");
  await page.getByLabel("Message", { exact: true }).press("Enter");
  const dialog = page.getByRole("dialog", { name: "Start a coding task" });
  await expect(dialog.getByLabel("Goal")).toHaveValue("Add a test for the export.");
  await dialog.getByRole("button", { name: "Cancel" }).click();

  // Set by hand, the mode holds and is no longer automatic.
  await pill.click();
  await page.getByRole("menuitemradio", { name: "Roleplay" }).click();
  await expect(pill).toHaveText("Roleplay");
  await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeHidden();
  api.picks("");
});

test.describe("at 1440 px, light", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
  test.beforeEach(({ page }) => stopClock(page));

  test("Chat, mode and assistant", async ({ page, request }) => {
    const id = await chat(request, await card(request, ["Roleplay", "Assistant", "Companion"]));
    expect((await request.put(`/api/chats/${id}/mode`, { data: { mode: "Assistant" } })).status()).toBe(200);
    await page.goto(`/#/chats/${id}`);
    await expect(page.getByRole("heading", { name: "Personality as an assistant" })).toBeVisible();
    await page.locator(".mode-pill").click();
    await expect(page.getByRole("menuitemradio", { name: "Automatic" })).toContainText("Picks one of the modes below from what you write");
    // The rail's two Gwen chats say their day and time, made on the real clock: masked, so the picture holds.
    await picture(page, "chat-mode-1440-light", [page.locator(".nav-chat", { hasText: "Gwen" })]);
  });
});
