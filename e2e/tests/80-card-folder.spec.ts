import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Page } from "@playwright/test";
import { cardFile } from "../card";
import { expect, test } from "../test";

// Settings › Data's folder of cards (milestone 90c): "Cards folder" picked in a browser through the dialog
// "Cards folder" ("Use this folder"), shown cut in the middle with the whole path as its tooltip, stored and its cards imported with the import panel; then its switches. The folder is the spec's own
// in the system's temporary folder (`cards`, two cards the spec writes), never another (the owner: his own cards
// could be deleted). The Recycle Bin switch is only looked at, never switched on, so no file is ever moved.

let cards: string;

test.beforeAll(() => {
  cards = mkdtempSync(join(tmpdir(), "cardwave-card-folder-"));
  writeFileSync(join(cards, "wren.png"), cardFile({ name: "Wren Hollow", first_mes: "The kettle sings." }));
  writeFileSync(join(cards, "moss.png"), cardFile({ name: "Moss Ferrow", first_mes: "Mind the step." }));
});
test.afterAll(() => rmSync(cards, { recursive: true, force: true }));

/** A line of the group Data, by its name. */
const line = (page: Page, name: string) => page.locator(".item:visible", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });
const says = (page: Page, name: string) => line(page, name).locator(".item-text > .meta");
const settings = async (page: Page) => (await (await page.request.get("/api/settings")).json()).card_folder;

test("Settings › Data's cards folder is picked, stored and imported; its switches show once it is set", async ({ page }) => {
  const { recycle_bin } = await (await page.request.get("/api/status")).json();
  await page.goto("/#/settings");
  // Without a folder: what it is for, and no switches.
  await expect(says(page, "Cards folder")).toHaveText("Card files in a folder and its subfolders, imported into your library");
  await expect(page.getByRole("switch", { name: "Import new cards automatically" })).toBeHidden();
  await expect(page.getByRole("switch", { name: "Move imported files to the Recycle Bin" })).toBeHidden();

  await line(page, "Cards folder").getByRole("button", { name: "Choose folder" }).click();
  const dialog = page.getByRole("dialog", { name: "Folder" });
  await dialog.getByLabel("Folder on this computer").fill(cards);
  await dialog.getByRole("button", { name: "Use this folder" }).click();
  // Stored at once, its cards imported with the panel.
  await expect(says(page, "Cards folder")).toHaveAttribute("title", cards);
  await expect(page.getByRole("status", { name: "Import" }).getByRole("heading")).toHaveText("2 cards imported");
  expect((await settings(page)).folder).toBe(cards);
  expect((await (await page.request.get("/api/cards")).json()).length).toBe(2);

  // The watch, on at first, is switched off and on; the Recycle Bin's switch, where there is one, is off.
  const watch = page.getByRole("switch", { name: "Import new cards automatically" });
  await expect(watch).toBeChecked();
  await watch.click();
  await expect(watch).not.toBeChecked();
  await expect(watch).toBeEnabled();
  expect((await settings(page)).watch).toBe(false);
  await watch.click();
  await expect(watch).toBeChecked();
  await expect(watch).toBeEnabled();
  expect((await settings(page)).watch).toBe(true);
  const recycle = page.getByRole("switch", { name: "Move imported files to the Recycle Bin" });
  if (recycle_bin) await expect(recycle).not.toBeChecked();
  else await expect(recycle).toBeHidden();
  expect((await settings(page)).recycle).toBe(false);

  // Changed: "Change" opens the dialog with the folder in it.
  await line(page, "Cards folder").getByRole("button", { name: "Change the cards folder" }).click();
  await expect(dialog.getByLabel("Folder on this computer")).toHaveValue(cards);
});
