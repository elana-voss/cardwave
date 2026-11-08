import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { pictureFile } from "../card";

// Accounts, from Account › Server: the home network switched on there is reached by another device (in the
// tests on this computer alone, at an address of its own: `CARDWAVE_NETWORK_LOOPBACK` in server.mjs), which
// signs in to an account added there, in a browser of its own (`browser.newContext`, which shares no cookie
// with the page); on this computer the account is switched to from "Switch account", and back; and the
// profile's picture stands in the account's round.
//
// The file's tests run one after the other on its server: the first adds "Ada", whom the second switches to.

test.describe.configure({ mode: "serial" });

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const line = (page: Page, name: string) => page.locator(".item", { has: page.getByText(name, { exact: true }) });
const dialog = (page: Page) => page.getByRole("dialog");
const account = (page: Page) => page.locator("#rail").getByRole("button", { name: /^Account/ });

test("an account added in Server signs in on another device, which reaches the app once Server lets it", async ({ page, browser }) => {
  await page.goto("/#/account/server");
  // The switch asks first (the owner, 2026-10-15).
  await page.getByRole("switch", { name: "Reachable in the home network" }).click();
  await expect(dialog(page)).toContainText("Phones and other computers on this network can then open Cardwave. Each account signs in with its password.");
  await button(page, "Switch on").click();
  await expect(page.getByRole("switch", { name: "Reachable in the home network" })).toBeChecked();
  const address = line(page, "Address").locator(".meta");
  await expect(address).toHaveText(/^http:\/\/127\.0\.0\.1:\d+\/$/);
  await page.getByRole("button", { name: "Add account" }).click();
  await dialog(page).getByLabel("Name").fill("Ada");
  await dialog(page).getByLabel("Password").fill("tide pool");
  await button(page, "Add").click();
  await expect(page.locator("#toast span")).toHaveText("Account “Ada” added.");
  // Of an account but this computer's nothing is said under its name.
  await expect(line(page, "Ada").locator(".item-text")).toHaveText("Ada");
  await expect(line(page, "local")).toContainText("This computer · can add and remove accounts");
  // Delete account asks on its own line under the account's, whose name stays whole; Cancel gives the menu back.
  await line(page, "Ada").getByRole("button", { name: /^More/ }).click();
  await page.getByRole("menuitem", { name: "Delete account" }).click();
  await expect(line(page, "Ada").locator("+ .confirm")).toContainText("Delete this account with its characters");
  await expect(line(page, "Ada").locator(".confirm")).toHaveCount(0);
  await button(page, "Cancel").click();
  await expect(line(page, "Ada").getByRole("button", { name: /^More/ })).toBeFocused();

  const elsewhere = await browser.newContext();
  const phone = await elsewhere.newPage();
  await phone.goto((await address.textContent())!);
  // Ada is the one account that can sign in there, as this computer's has no password.
  await expect(phone.getByRole("heading", { name: "Ada" })).toBeVisible();
  await phone.getByLabel("Password").fill("tide");
  await button(phone, "Sign in").click();
  await expect(phone.getByText("Wrong password.")).toBeVisible();
  await phone.getByLabel("Password").fill("tide pool");
  await button(phone, "Sign in").click();
  // Ada has no model yet: her app starts with first run.
  await expect(phone.getByRole("heading", { name: "Provider" })).toBeVisible();
  await phone.goto(`${await address.textContent()}#/settings`);
  await expect(account(phone)).toHaveAccessibleName("Account: Ada");
  await expect(phone.getByRole("link", { name: "Sharing" })).toBeHidden();
  await elsewhere.close();
});

test("on this computer an account is switched to from Switch account, and back", async ({ page }) => {
  await page.goto("/#/settings");
  await page.getByRole("button", { name: "Switch account" }).click();
  await page.getByRole("menuitemradio", { name: "Ada" }).click();
  await dialog(page).getByLabel("Password").fill("tide pool");
  await button(page, "Switch").click();
  await expect(page.getByRole("heading", { name: "Provider" })).toBeVisible();
  await page.goto("/#/settings");
  await expect(account(page)).toHaveAccessibleName("Account: Ada");
  // Back to this computer's account, which asks no password while none is on; from the rail's menu.
  await account(page).click();
  await page.getByRole("menuitemradio", { name: "local" }).click();
  // The page starts anew as that account, without an address: first run, as this file stores no model.
  await expect(page.getByRole("heading", { name: "Provider" })).toBeVisible();
  await page.goto("/#/settings");
  await expect(account(page)).toHaveAccessibleName("Account: local");
});

test("a picture taken in the profile stands in the account's round, until it is removed", async ({ page }) => {
  await page.goto("/#/account/profile");
  await expect(line(page, "Picture")).toContainText("No picture: your initial L is shown");
  await line(page, "Picture").locator("input[type=file]").setInputFiles({ name: "me.png", mimeType: "image/png", buffer: pictureFile([300, 200]) });
  await expect(page.locator("#toast span")).toHaveText("Picture changed.");
  await expect(account(page).locator(".initial img")).toBeVisible();
  await expect(page.locator(".profile-head .initial img")).toBeVisible();
  await page.getByRole("button", { name: "Remove the picture" }).click();
  await expect(page.locator("#toast span")).toHaveText("Picture removed.");
  await expect(account(page).locator(".initial")).toHaveText("L");
});
