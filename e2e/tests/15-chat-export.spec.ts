import { readFileSync } from "node:fs";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";

// A chat's export from its own menu: the chat is saved as a file for SillyTavern, and goes on.
//
// One database for the file: every test makes a chat of its own, under a name no other has. `saved` does what
// starts a download and reads the chat file's lines.

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const item = (page: Page, name: string) => page.getByRole("menuitem", { name, exact: true });
const said = (page: Page) => page.locator("#toast span");

/** A file's name as a chat started now or a moment ago is given: the chat's name and when it was started. */
const named = (name: string) => new RegExp(`^${name} - \\d{4}-\\d\\d-\\d\\d@\\d\\dh\\d\\dm\\d\\ds\\.jsonl$`);

/** A card of its own with one character, and a chat with it, called as the card is, in which the user, under no persona, has written. Returns the chat's id. */
async function chatWith(request: APIRequestContext, name: string, change?: Record<string, boolean>): Promise<number> {
  const imported = await request.post("/api/cards", { data: cardFile({ name, first_mes: `${name} says hello.` }) });
  expect(imported.status(), await imported.text()).toBe(201);
  const characters = [{ version_id: (await imported.json()).version_id, character: name.toLowerCase().replaceAll(" ", "-") }];
  const started = await request.post("/api/chats", { data: { characters } });
  expect(started.status(), await started.text()).toBe(201);
  const { id } = (await started.json()).chat;
  expect((await request.post(`/api/chats/${id}/messages`, { data: { content: "Is anyone there?" } })).status()).toBe(201);
  if (change) expect((await request.patch(`/api/chats/${id}`, { data: change })).status()).toBe(200);
  return id;
}

/** Does what starts a download, and returns the file's name and its lines, each read as what it holds. */
async function saved(page: Page, start: () => Promise<void>): Promise<{ name: string; lines: any[] }> {
  const [download] = await Promise.all([page.waitForEvent("download"), start()]);
  const lines = readFileSync(await download.path(), "utf8").split("\n");
  return { name: download.suggestedFilename(), lines: lines.map((line) => JSON.parse(line)) };
}

/** Opens a chat, and its own menu. */
async function chatMenu(page: Page, chat: number): Promise<void> {
  await page.goto(`/#/chats/${chat}`);
  await button(page, "Chat options").click();
}

/** That the lines are the file of the chat with the character `name` these tests start. */
function isChatOf(lines: any[], name: string): void {
  expect(lines[0]).toEqual({ chat_metadata: {}, user_name: "Guest", character_name: name });
  expect(lines.slice(1).map((line) => [line.name, line.is_user, line.mes])).toEqual([
    [name, false, `${name} says hello.`],
    ["Guest", true, "Is anyone there?"],
  ]);
}

test("Export in the chat's own menu saves the chat, and the chat goes on", async ({ page, request }) => {
  const chat = await chatWith(request, "Hesper Vane");
  await chatMenu(page, chat);
  await expect(page.getByRole("menuitem")).toHaveText(["Rename", "Add a lorebook", "New chat with Hesper Vane", "Add to Favourites", "Export", "Archive", "Move to Trash"]);
  const file = await saved(page, () => item(page, "Export").click());
  expect(file.name).toMatch(named("Hesper Vane"));
  isChatOf(file.lines, "Hesper Vane");
  await expect(said(page)).toHaveText("Chat exported.");
  // Nothing is held up by it: the chat's menu does what it did, and an archived chat has the line too.
  // The chat is made a favourite where it is, as its star in the list does.
  await button(page, "Chat options").click();
  await item(page, "Add to Favourites").click();
  await button(page, "Chat options").click();
  await item(page, "Archive").click();
  await expect(said(page)).toHaveText("Chat archived.");
  await button(page, "Chat options").click();
  await expect(page.getByRole("menuitem")).toHaveText(["Rename", "Add a lorebook", "New chat with Hesper Vane", "Remove from Favourites", "Export", "Unarchive", "Move to Trash"]);
  isChatOf((await saved(page, () => item(page, "Export").click())).lines, "Hesper Vane");
  await expect(said(page)).toHaveText("Chat exported.");
});
