import type { APIRequestContext } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// How a chat's replies are written: the side panel's box with Reply length and Code mode, kept for the chat and
// used from the next reply (Code mode offers the model `make_tool`, and greys Reply length, not sent then), and
// the model's thinking, shown while it thinks as one grey line with its newest sentence, Send being Stop meanwhile, and gone with the reply's first
// word, never kept with the reply. The stand-in `api` thinks in a `<think>` part, held after its first piece.

let api: FakeProvider;

test.beforeAll(async () => {
  api = await startFakeProvider();
});
test.afterAll(() => api.close());

/** A chat with Mira, and its number. */
async function chat(request: APIRequestContext): Promise<number> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.card.version_id, character: card.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

test("the side panel sets the chat's reply length and Let the AI write tools", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  // A slider of five named steps, a new chat at Medium; an arrow key moves one step.
  const length = page.getByRole("slider", { name: "Reply length" });
  const step = page.locator(".reply-steps .step-says");
  await expect(step).toHaveText("Medium · 350");
  await expect(length).toHaveAttribute("aria-valuetext", "Medium · 350");
  const kept = page.waitForResponse((answer) => answer.url().endsWith("/reply"));
  await length.press("ArrowRight");
  await kept;
  await expect(step).toHaveText("Long · 750");
  await expect.poll(async () => (await (await request.get(`/api/chats/${id}`)).json()).chat.reply_length).toBe(750);

  const code = page.getByRole("switch", { name: "Let the AI write tools" });
  const note = page.locator("label[for=chat-reply-length] .meta");
  await expect(note).toHaveText("Tokens per reply");
  await expect(code).not.toBeChecked();
  await code.click();
  await expect(code).toBeChecked();
  // A tool is on: the length is not sent, and its slider is greyed with its step kept.
  await expect(note).toHaveText("Not used while the AI uses tools");
  await expect(length).toBeDisabled();
  await expect(step).toHaveText("Long · 750");
  api.next(["Ready."]);
  await page.getByLabel("Message", { exact: true }).fill("Can you count words?");
  await page.getByRole("button", { name: "Send" }).click();
  await expect(page.locator("article.message").last()).toContainText("Ready.");
  const offered = api.asked.at(-1)!.body.tools.map((tool: { function: { name: string } }) => tool.function.name);
  expect(offered).toContain("make_tool");
});

test("while the model thinks, its newest sentence shows under the name until the reply begins", async ({ page, request }) => {
  const id = await chat(request);
  await page.goto(`/#/chats/${id}`);
  const held = api.hold(["<think>She weighs the storm. The lamp is", " low.</think>", "The tide turns tonight."]);
  await page.getByLabel("Message", { exact: true }).fill("Why tonight?");
  await page.getByRole("button", { name: "Send" }).click();
  const reply = page.locator("article.message").last();
  await expect(reply.locator(".think")).toHaveText("She weighs the storm.");
  await expect(reply.locator(".bubble")).toBeHidden();
  await expect(page.getByRole("button", { name: "Stop" })).toBeVisible();
  held.next();
  await expect(reply.locator(".think")).toHaveText("The lamp is low.");
  held.release();
  await expect(reply.locator(".text")).toHaveText("The tide turns tonight.");
  await expect(reply.locator(".think")).toHaveCount(0);
  const messages = (await (await request.get(`/api/chats/${id}`)).json()).messages;
  expect(messages.at(-1).content).toBe("The tide turns tonight.");
});
