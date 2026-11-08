import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { PICTURE, startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider, setImages } from "../stored";

// Images: the image model set up from the settings' line "Images" and its picker of the kind, which offers the
// models of every provider (a stand-in does not say its models' kinds, so all of them), and a picture made in a chat from "+" › "Make a picture", which comes as the character's
// message, made again of words changed by its menu's "Edit description"; a picture and a document attached to a
// message, as tiles over the field and then over the message. The stand-in `api` is the provider, the worker model's words (`next`) and the image model's picture
// (`PICTURE`, noted in `pictured`) both; no test asks a provider or a ComfyUI.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

const line = (page: Page) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: /^Images$/ }) });
const picker = (page: Page, title = "Image model") => page.getByRole("dialog", { name: title });

/** A chat with Mira, and its number. */
async function chat(request: APIRequestContext): Promise<number> {
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["*She looks up from the lamp.* You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.card.version_id, character: card.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

test("the image model is picked from the provider's image models, and a picture of the scene comes into the chat", async ({ page, request }) => {
  const stored = await setProvider(request, { base_url: api.url, model: "tide-1" });
  expect(stored.status(), await stored.text()).toBe(200);
  api.models(["tide-1", "gpt-image-1", "dall-e-3"]);

  await page.goto("/#/settings");
  await expect(line(page).locator(".meta")).toHaveText("Not set up");
  await page.getByRole("button", { name: "Set up the image model" }).click();
  const kind = picker(page, "Images model");
  await expect(kind.getByRole("option").locator(".opt-id")).toHaveText(["dall-e-3", "gpt-image-1", "tide-1"]);
  await kind.getByRole("option", { name: "gpt-image-1" }).click();
  await kind.getByRole("button", { name: "Use this model" }).click();
  await expect(line(page).locator(".meta")).toHaveText("gpt-image-1 · A program on this computer");

  await page.goto(`/#/chats/${await chat(request)}`);
  api.next(["lighthouse, storm, 1 woman"]);
  await page.getByRole("button", { name: "Attach, or let the AI write", exact: true }).click();
  await page.getByRole("menuitem", { name: /^Make a picture/ }).click();
  const picture = page.locator("article.message").last().locator("img.picture");
  await expect(picture).toHaveAttribute("alt", "lighthouse, storm, 1 woman");
  await expect.poll(() => picture.evaluate((shown: HTMLImageElement) => shown.naturalWidth)).toBe(1);
  expect(api.pictured).toEqual([{ model: "gpt-image-1", prompt: "lighthouse, storm, 1 woman", n: 1 }]);

  // Edit description: the words under the picture, dimmed, and "Make again" makes another version of them.
  await picture.hover();
  await page.getByRole("button", { name: "Picture options" }).click();
  await page.getByRole("menuitem", { name: "Edit description", exact: true }).click();
  await expect(page.locator(".repicture img.dimmed")).toBeVisible();
  // The words changed go through the worker model, so the character keeps their looks; the message keeps them as typed.
  api.next(["lighthouse, dawn, 1 woman"]);
  await page.locator(".repicture").getByLabel("Description", { exact: true }).fill("lighthouse, dawn");
  await page.getByRole("button", { name: "Make again", exact: true }).click();
  await expect(page.locator("article.message").last().locator("img.picture")).toHaveAttribute("alt", "lighthouse, dawn");
  await expect(page.locator(".repicture")).toHaveCount(0);
  expect(api.pictured.at(-1)).toEqual({ model: "gpt-image-1", prompt: "lighthouse, dawn, 1 woman", n: 1 });
});

test("a picture and a document attached wait as tiles over the field, and stand over the message sent", async ({ page, request }) => {
  const stored = await setProvider(request, { base_url: api.url, model: "tide-1" });
  expect(stored.status(), await stored.text()).toBe(200);
  await page.goto(`/#/chats/${await chat(request)}`);
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("button", { name: "Attach, or let the AI write", exact: true }).click();
  await page.getByRole("menuitem", { name: "Attach picture or document", exact: true }).click();
  await (await chooser).setFiles([
    { name: "lamp.png", mimeType: "image/png", buffer: Buffer.from(PICTURE, "base64") },
    { name: "notes.txt", mimeType: "text/plain", buffer: Buffer.from("The tide turns at nine.") },
  ]);
  const waiting = page.locator(".waiting-attachments");
  await expect(waiting.locator("img.attached-picture")).toHaveAttribute("alt", "lamp.png");
  await expect(waiting.locator(".attached-file")).toContainText("notes.txt");
  // Its × takes one off again.
  await waiting.locator(".waiting-tile").last().getByRole("button", { name: "Remove" }).click();
  await expect(waiting.locator(".waiting-tile")).toHaveCount(1);
  // A message of the picture alone is sent, without a bubble.
  await page.getByRole("button", { name: "Send", exact: true }).click();
  const mine = page.locator("article.message.user");
  await expect(mine.locator("img.attached-picture")).toHaveAttribute("alt", "lamp.png");
  await expect(mine.locator(".bubble")).toHaveCount(0);
  await expect(waiting).toBeHidden();
});

test("first run holds the image model taken until “Continue” stores it", async ({ page, request }) => {
  const stored = await setProvider(request, { base_url: api.url, model: "tide-1" });
  expect(stored.status(), await stored.text()).toBe(200);
  await setImages(request, { model: "gpt-image-1" });
  api.models(["tide-1", "dall-e-3"]);
  await page.goto("/#/setup");
  await page.getByRole("button", { name: "Change the image model" }).click();
  await picker(page).getByLabel("Model").fill("dall-e-3");
  await picker(page).getByRole("button", { name: "Use this model" }).click();
  const images = page.locator(".setup .item", { has: page.locator(".item-label", { hasText: /^Images$/ }) });
  // By its readable name, as the design of first run step 2 has it.
  await expect(images.locator(".meta")).toHaveText("Dall E 3");
  expect((await (await request.get("/api/images")).json()).model).toBe("gpt-image-1");
  await page.getByRole("button", { name: "Continue", exact: true }).click();
  await expect.poll(async () => (await (await request.get("/api/images")).json()).model).toBe("dall-e-3");
});
