import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";

// The pretend model (crates/cw-provider/src/pretend.rs): a key that begins `sk-cardwave-fake-` is taken for it in
// first run, and a chat then gets its one reply, streamed, without a provider and without a stand-in.

const KEY = "sk-cardwave-fake-0123456789";
/** What the pretend model answers every chat with (`REPLY`). */
const REPLY = "This is Cardwave's pretend model. It gives every message this same reply, so the app can be tried without a provider.";

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const says = (page: Page, name: string) =>
  page.locator(".setup .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) }).locator(".item-text > .meta");

test("a pretend key sets up the pretend model in first run, and a chat gets its reply", async ({ page, request }) => {
  await page.goto("/#/setup");
  await page.getByLabel("API key", { exact: true }).fill(KEY);
  await expect(page.getByRole("status")).toContainText("Recognised: Pretend model");
  await button(page, "Continue").click();
  await expect(page.locator(".setup h1")).toHaveText("Models");
  // Picked from the pretend model's list, and tested.
  await expect(says(page, "Chat")).toHaveText("Pretend Chat · works");
  await expect(says(page, "Helper model")).toHaveText("Pretend Chat Mini · works");
  await page.getByRole("button", { name: "Continue", exact: true }).click();
  await expect(page.locator(".setup h1")).toHaveText("Cards");
  await button(page, "Skip").click();
  // The downloads of step 4 are not this spec's: the chat is opened by its address.
  await expect(page.locator(".setup h1")).toHaveText("Downloads");

  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", first_mes: "The lamp is lit." }) });
  expect(made.status(), await made.text()).toBe(201);
  const [card] = await (await request.get("/api/cards?q=Mira")).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.version_id, character: "mira" }] } });
  expect(started.status(), await started.text()).toBe(201);
  await page.goto(`/#/chats/${(await started.json()).chat.id}`);
  const composer = page.getByLabel("Message", { exact: true });
  await composer.fill("Hello there.");
  await composer.press("Enter");
  await expect(page.locator(".message .text").last()).toHaveText(REPLY);
});
