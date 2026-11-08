import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { NOTHING, startFakeProvider, type FakeProvider } from "../fake-provider";

// A chat's memory: what the memory read of a block of 20 messages shows in the side panel's "Used in last reply"
// ("Saved to memory") of the reply that completed it, and Knowledge › Memories lists it, changes its text and who
// knows it, and deletes it, with the notice's Undo. What the helper finds is the stand-in's (`remembers` of
// ../fake-provider.ts), which the test sets before the reply and takes back after it; the first 17 messages
// after the greeting are sent through the API.

let provider: FakeProvider;
test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  const set = await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } });
  expect(set.status()).toBe(200);
  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", description: "Keeper of the lighthouse.", first_mes: "The lamp is lit." }) });
  expect(made.status(), await made.text()).toBe(201);
});
test.afterAll(() => provider.close());

const row = (page: Page) => page.locator(".memory-row");
const menuOf = async (page: Page, line: string) => {
  await row(page).hover();
  await row(page).getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: line, exact: true }).click();
};

test("what a block of messages leaves to remember shows in the side panel's part of the reply, and Knowledge › Memories changes and deletes it", async ({ page, request }) => {
  await page.goto("/#/library");
  await page.getByRole("link", { name: "Mira", exact: true }).click();
  await page.getByRole("button", { name: "Start a chat with this message", exact: true }).click();
  await expect(page.locator(".message .text")).toHaveText(["The lamp is lit."]);
  const chat = page.url().split("#/chats/")[1];
  for (let n = 2; n <= 18; n++) {
    expect((await request.post(`/api/chats/${chat}/messages`, { data: { content: `Message ${n}.` } })).status()).toBe(201);
  }
  await page.reload();
  await expect(page.locator(".message .text")).toHaveCount(18);
  provider.remembers("PRESENT: Mira, User\nFACTS:\nuser | sister | The user's sister is called Ana. | personal | Mira | current\nEVENTS:");
  await page.getByLabel("Message", { exact: true }).fill("My sister Ana comes tonight.");
  await page.getByLabel("Message", { exact: true }).press("Enter");
  const used = page.locator(".chat-panel .panel-part", { has: page.getByText("Used in last reply", { exact: true }) });
  await expect(used.locator(".item", { hasText: "Saved to memory" })).toHaveText("Saved to memoryThe user's sister is called Ana.");
  provider.remembers(NOTHING);

  await page.locator("#rail").getByRole("link", { name: "Memories" }).click();
  await expect(page.locator("#rail [aria-current]")).toHaveText("Memories");
  await expect(row(page).locator(".medium")).toHaveText("The user's sister is called Ana.");
  await expect(row(page).locator(".meta")).toContainText("Known by Mira");
  await expect(row(page).getByRole("link")).toHaveText("Mira");

  // Edit: its text, and who knows it.
  await menuOf(page, "Edit");
  const dialog = page.getByRole("dialog", { name: "Edit memory" });
  await dialog.getByLabel("Text").fill("Ana, the user's sister, arrives tonight.");
  await dialog.getByRole("button", { name: "Mira" }).click();
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(row(page).locator(".medium")).toHaveText("Ana, the user's sister, arrives tonight.");
  await expect(row(page).locator(".meta")).toContainText("Known by nobody");

  // The search narrows the list.
  await page.getByRole("searchbox").fill("pirates");
  await expect(row(page)).toHaveCount(0);
  await expect(page.getByText("No memory found.")).toBeVisible();
  await page.getByRole("searchbox").fill("ana");
  await expect(row(page)).toHaveCount(1);

  // Delete, and Undo.
  await menuOf(page, "Delete");
  await expect(row(page)).toHaveCount(0);
  await expect(page.locator("#toast span")).toHaveText("Memory deleted.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(row(page).locator(".medium")).toHaveText("Ana, the user's sister, arrives tonight.");
});
