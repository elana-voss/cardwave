import { readFileSync } from "node:fs";
import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";

// The password, from Profile, and the backup, from Settings › Data: a password switched on is asked for by the
// start screen when the app opens again (`restartServer`), and by "Lock" in the account's menu, and switched off
// with the current one; a backup saved,
// with a password asked for where none is on, is restored with it in the place of all the app holds, and the page
// starts anew with it.
//
// The file's tests run one after the other on its server, and each leaves it without a password.

test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const line = (page: Page, name: string) => page.locator(".item", { has: page.getByText(name, { exact: true }) });
const dialog = (page: Page) => page.getByRole("dialog");

const personas = async (request: APIRequestContext) => (await (await request.get("/api/personas")).json()).map((p: { name: string }) => p.name);

test("a password switched on is asked for when the app opens, and is switched off with it", async ({ page, restartServer }) => {
  await page.goto("/#/settings");
  await expect(line(page, "Backup")).toContainText("encrypted with a password you choose");
  // The password is the profile's alone (the owner, 2026-10-15).
  await expect(page.getByRole("button", { name: "Set a password" })).toHaveCount(0);
  await page.goto("/#/account/profile");
  await expect(line(page, "Password")).toContainText("Off · anyone at this computer can open Cardwave");
  await page.getByRole("button", { name: "Set a password" }).click();
  await expect(dialog(page)).toContainText("A forgotten password cannot be recovered,");
  await page.getByLabel("Password", { exact: true }).fill("harbour lights");
  await page.getByLabel("Repeat password").fill("harbor lights");
  await button(page, "Set password").click();
  await expect(dialog(page)).toContainText("The two passwords differ.");
  await page.getByLabel("Repeat password").fill("harbour lights");
  await button(page, "Set password").click();
  await expect(page.locator("#toast span")).toHaveText("Password set.");
  await expect(line(page, "Password")).toContainText("On · asked when the app opens");
  await page.goto("/#/settings");
  await expect(line(page, "Backup")).toContainText("encrypted with your password");

  await restartServer();
  await page.goto("about:blank");
  await page.goto("/#/account/profile");
  await expect(page.getByRole("heading", { name: "local" })).toBeVisible();
  await page.getByLabel("Password").fill("harbour light");
  await button(page, "Open").click();
  await expect(page.getByText("Wrong password.")).toBeVisible();
  await page.getByLabel("Password").fill("harbour lights");
  await button(page, "Open").click();
  await expect(line(page, "Password")).toContainText("On · asked when the app opens");
  await page.getByRole("button", { name: "Switch off the password" }).click();
  await page.getByLabel("Current password").fill("harbour lights");
  await button(page, "Switch off").click();
  await expect(page.locator("#toast span")).toHaveText("Password switched off.");
  await expect(line(page, "Password")).toContainText("Off · anyone at this computer can open Cardwave");
});

test("while a password is on, Lock in this computer's account menu shows the start screen, on every page, and nothing opens until the password is typed", async ({ page, request }) => {
  const account = page.locator("#rail").getByRole("button", { name: /^Account/ });
  const lock = page.getByRole("menuitem", { name: "Lock" });
  await page.goto("/#/chats");
  await account.click();
  await expect(page.getByRole("menuitem", { name: "Profile" })).toBeVisible();
  await expect(lock).toHaveCount(0);
  await page.keyboard.press("Escape");

  expect((await request.put("/api/password", { data: { password: "harbour lights" } })).status()).toBe(200);
  await page.reload();
  const other = await page.context().newPage();
  await other.goto("/#/chats");
  await expect(other.locator("#rail")).toBeVisible();
  await account.click();
  await lock.click();
  await expect(button(page, "Open")).toBeVisible();
  // Another page open on the app shows the start screen too.
  await expect(button(other, "Open")).toBeVisible();
  await other.close();
  await expect(page.locator("#rail")).toBeHidden();
  expect((await request.get("/api/personas")).status()).toBe(423);
  await page.goto("/#/library");
  await expect(button(page, "Open")).toBeVisible();
  await page.getByLabel("Password").fill("harbour lights");
  await button(page, "Open").click();
  await expect(page.locator("#rail")).toBeVisible();
  expect((await request.put("/api/password", { data: { current: "harbour lights" } })).status()).toBe(200);
});

test("a backup saved with the password asked for is restored with it in the place of all the app holds, and the page starts anew with it", async ({ page, request }) => {
  expect((await request.post("/api/personas", { data: { name: "Wanderer", description: "" } })).status()).toBe(201);
  await page.goto("/#/settings");
  // What the server refuses is said, and the page stays.
  await page.route("**/api/backup/save", (route) => route.fulfill({ status: 500, contentType: "application/json", body: JSON.stringify({ code: "internal", error: "The disk is full.", details: {} }) }), { times: 1 });
  await page.getByRole("button", { name: "Save a backup" }).click();
  await page.getByLabel("Password", { exact: true }).fill("harbour lights");
  await page.getByLabel("Repeat password").fill("harbour lights");
  await button(page, "Save backup").click();
  await expect(page.locator("#toast span")).toHaveText("Something went wrong in Cardwave. Try again.");
  await expect(line(page, "Backup")).toBeVisible();

  const saved = page.waitForEvent("download");
  await page.getByRole("button", { name: "Save a backup" }).click();
  await expect(dialog(page)).toContainText("A forgotten password cannot be recovered");
  await page.getByLabel("Password", { exact: true }).fill("harbour lights");
  await page.getByLabel("Repeat password").fill("harbour lights");
  await button(page, "Save backup").click();
  const download = await saved;
  expect(download.suggestedFilename()).toMatch(/^cardwave-backup-\d{4}-\d\d-\d\d\.cwbackup$/);
  await expect(page.locator("#toast span")).toHaveText("Saving the backup.");
  const file = readFileSync(await download.path());

  // Made after the backup, and gone once it is restored.
  expect((await request.post("/api/personas", { data: { name: "Stranger", description: "" } })).status()).toBe(201);
  await page.getByRole("button", { name: "Restore a backup" }).click();
  await dialog(page).locator("input[type=file]").setInputFiles({ name: "backup.cwbackup", mimeType: "application/octet-stream", buffer: file });
  await expect(dialog(page)).toContainText("backup.cwbackup");
  await button(page, "Restore backup").click();
  await expect(dialog(page)).toContainText("This backup needs its password.");
  await page.getByLabel("The backup’s password").fill("harbour lights");
  const anew = page.waitForEvent("load");
  await button(page, "Restore backup").click();
  await anew;
  await expect(line(page, "Backup")).toBeVisible();
  expect(await personas(request)).toEqual(["Wanderer"]);
});

test("a line's button grows with a longer language's words: German's restore button holds its label", async ({ page, request }) => {
  expect((await request.patch("/api/settings", { data: { app_language: "de" } })).status()).toBe(200);
  await page.goto("/#/settings");
  const restore = page.getByRole("button", { name: "Eine Sicherung wiederherstellen" });
  await expect(restore).toBeVisible();
  expect(await restore.evaluate((node) => node.scrollWidth <= node.clientWidth)).toBe(true);
  expect((await request.patch("/api/settings", { data: { app_language: null } })).status()).toBe(200);
});
