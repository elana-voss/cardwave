import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";

// The account's profile: "Change" puts a field in the name's place, and "Save" renames the account wherever
// its name shows: the profile itself, the rail, a narrow window's bar, and the round beside the user's
// messages in a chat.
//
// The account is called `local` before each test (`beforeEach`, past the page), as the file's tests run on
// one server. The app asks the account's name once while it runs, so a test that answers `/api/account`
// itself opens its page from an empty one (`open`). The rail's button and the bar's have one name, "Account:
// …", and `getByRole` finds the one of the two that shows.

const rename = async (request: APIRequestContext, name: string) => expect((await request.put("/api/account", { data: { name } })).status()).toBe(200);
const called = async (request: APIRequestContext) => (await (await request.get("/api/account")).json()).name;

test.beforeEach(({ request }) => rename(request, "local"));

/** Opens a screen from an empty page, so that the app starts anew, and waits until it hears the server. */
async function open(page: Page, address = "/#/account/profile"): Promise<void> {
  await page.goto("about:blank");
  const heard = page.waitForEvent("websocket").then((socket) => socket.waitForEvent("framereceived"));
  await page.goto(address);
  await heard;
}

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const account = (page: Page) => page.getByRole("button", { name: /^Account/ });
const head = (page: Page) => page.locator(".profile-head");
/** The group "Account": its line "Name", what that says, and the field the name is changed in. */
const group = (page: Page) => page.locator(".settings-group", { has: page.getByRole("heading", { name: "Account", exact: true }) });
/** What the line "Name" says, the group's first line; the line "Password" follows it. */
const says = (page: Page) => group(page).locator(".item:visible .item-text > .meta").first();
const field = (page: Page) => page.getByLabel("Name", { exact: true });

test("“Change” puts a field in the name's place, and “Save” renames the account wherever its name shows", async ({ page, request }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  // The app asks what the account is called once, at its start: not again when it hears the server's first word.
  const asked: string[] = [];
  page.on("request", (sent) => {
    if (sent.url().endsWith("/api/account")) asked.push(sent.method());
  });
  await open(page);
  await button(page, "Change the name").click();
  // The field has the name, marked, so that what is typed takes its place; the line it stood in is gone.
  await expect(field(page)).toBeFocused();
  await expect(field(page)).toHaveValue("local");
  expect(await field(page).evaluate((input: HTMLInputElement) => [input.selectionStart, input.selectionEnd])).toEqual([0, 5]);
  await expect(button(page, "Change the name")).toBeHidden();
  await expect(group(page).locator(".renaming").getByRole("button")).toHaveText(["Save", "Cancel"]);

  await field(page).fill("  Rowan Vale ");
  await button(page, "Save").click();
  // The line is back with the new name, as the server keeps it, and the button that changed it has the focus.
  await expect(says(page)).toHaveText("Rowan Vale");
  await expect(button(page, "Change the name")).toBeFocused();
  await expect(field(page)).toBeHidden();
  await expect(head(page).locator(".profile-name")).toHaveText("Rowan Vale");
  await expect(head(page).locator(".initial")).toHaveText("R");
  expect(await called(request)).toBe("Rowan Vale");
  // The rail has it at once, without asking for it again.
  await expect(account(page)).toHaveAccessibleName("Account: Rowan Vale");
  await expect(account(page)).toHaveText("RRowan Vale");
  expect(asked).toEqual(["GET", "PUT"]);
  // And a narrow window's bar.
  await page.setViewportSize({ width: 600, height: 900 });
  await expect(account(page)).toHaveAccessibleName("Account: Rowan Vale");
  await expect(account(page)).toHaveText("R");

  // Enter in the field saves too.
  await button(page, "Change the name").click();
  await field(page).fill("Wren");
  await field(page).press("Enter");
  await expect(says(page)).toHaveText("Wren");
  expect(await called(request)).toBe("Wren");
  // A screen opened afterwards has the new name from the app, which is not asked again: a new card's creator.
  await page.goto("/#/library/new");
  await expect(page.locator(".side")).toContainText("by Wren");
  expect(asked).toEqual(["GET", "PUT", "PUT"]);
});
