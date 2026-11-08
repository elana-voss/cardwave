import type { Page } from "@playwright/test";
import { deafen, expect, test } from "../test";
import { picture, SIZES, stopClock, THEMES } from "../pictures";

// The user's own CSS (milestone 71): Settings › Advanced's last box "Your own CSS", whose "Edit" opens the dialog
// whose field restyles the app as typed, Save keeping it and Escape taking it back; a second page hears of it,
// the companion's page also of a change made while its connection was down;
// and the page "Cardwave's CSS", which the dialog's link opens in a new tab: the variables with their light and
// dark values, found by name, the class names, and a snippet copied. The picture is `css-reference`. What the
// CSS does is told by the page's ground (`ground`), which `--page` colours.

/** The colour of the page's ground. */
const ground = (page: Page) => page.evaluate(() => getComputedStyle(document.body).backgroundColor);

/** Some CSS that colours the ground, as no theme does. */
const OWN = ":root { --page: rgb(1, 2, 3); }";

/** The line "Your own CSS" of Settings › Advanced: what it says of the CSS kept. */
const says = (page: Page) => page.locator(".item", { hasText: "Your own CSS" }).locator(".meta");

/** Opens the dialog "Your own CSS" and answers its field. */
async function edit(page: Page) {
  await page.getByRole("button", { name: "Edit your own CSS" }).click();
  const field = page.getByRole("dialog", { name: "Your own CSS" }).getByLabel("Your own CSS");
  await expect(field).toBeFocused();
  return field;
}

test("your own CSS restyles the app as typed: Escape takes it back, Save keeps it, also over a new start and in another page, and emptied the app looks its own", async ({ page }) => {
  await page.goto("/#/settings/advanced");
  await expect(says(page)).toHaveText("None · changes the app's look");
  const own = await ground(page);

  let field = await edit(page);
  await field.fill(OWN);
  await expect.poll(() => ground(page)).toBe("rgb(1, 2, 3)");
  await page.keyboard.press("Escape");
  await expect(page.locator("dialog")).toHaveCount(0);
  expect(await ground(page)).toBe(own);

  const other = await page.context().newPage();
  await other.goto("/#/chats");
  await expect(other.locator("#rail")).toBeVisible();
  field = await edit(page);
  await field.fill(`${OWN}\n.bubble { border-radius: 6px; }\n`);
  await page.getByRole("dialog").getByRole("button", { name: "Save" }).click();
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(says(page)).toHaveText("2 lines · changes the app's look");
  expect(await ground(page)).toBe("rgb(1, 2, 3)");
  await expect.poll(() => ground(other)).toBe("rgb(1, 2, 3)");
  await page.reload();
  await expect(says(page)).toHaveText(/^2 lines/);
  expect(await ground(page)).toBe("rgb(1, 2, 3)");

  field = await edit(page);
  await field.fill("");
  await page.getByRole("dialog").getByRole("button", { name: "Save" }).click();
  await expect(says(page)).toHaveText(/^None/);
  expect(await ground(page)).toBe(own);
});

test("the dialog's link opens Cardwave's CSS in a tab of its own: the variables with both values, found by name, the class names, and a snippet copied", async ({ page }) => {
  await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
  await page.goto("/#/settings/advanced");
  await edit(page);
  const [css] = await Promise.all([page.context().waitForEvent("page"), page.getByRole("button", { name: "Cardwave's CSS" }).click()]);
  await expect(css).toHaveURL(/#\/settings\/advanced\/css$/);
  // The dialog stays where it was.
  await expect(page.getByRole("dialog", { name: "Your own CSS" })).toBeVisible();

  const line = (name: string) => css.locator(".item", { has: css.getByText(name, { exact: true }) });
  await expect(line("--accent")).toContainText("#0083E9 · in the dark #3D95F5");
  await expect(css.getByText(/^\d+ variables in all\.$/)).toBeVisible();
  await css.getByPlaceholder("Find a variable").fill("fs-body");
  await expect(css.locator(".item .mono").filter({ hasText: /^--/ })).toHaveText(["--fs-body"]);
  await expect(line("--fs-body")).toContainText("14px");
  await css.getByPlaceholder("Find a variable").fill("nothing-so");
  await expect(css.getByText("No variable by that name.")).toBeVisible();
  await expect(line(".bubble")).toContainText("A message's bubble");

  await css.getByRole("button", { name: "Copy “A green accent”" }).click();
  await expect(css.locator("#toast span")).toHaveText("Copied.");
  expect(await css.evaluate(() => navigator.clipboard.readText())).toBe(":root { --accent: #2E7D32; --accent-hover: #1B5E20; }");
});

for (const [width, height] of SIZES) {
  for (const theme of THEMES) {
    test.describe(`at ${width} px, ${theme}`, () => {
      test.use({ viewport: { width, height }, colorScheme: theme });
      test.beforeEach(({ page }) => stopClock(page));

      test("the page Cardwave's CSS", async ({ page }) => {
        await page.goto("/#/settings/advanced/css");
        await expect(page.getByText("--accent", { exact: true })).toBeVisible();
        await picture(page, `css-reference-${width}-${theme}`);
      });
    });
  }
}

test("your own CSS still wins over a look of the theme menu", async ({ page }) => {
  await page.goto("/#/settings/advanced");
  await page.evaluate(() => localStorage.setItem("theme", "outrun"));
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "outrun");
  expect(await ground(page)).toBe("rgb(20, 8, 50)");
  const field = await edit(page);
  await field.fill("body { background: rgb(1, 2, 3); }"); // the look paints its ground itself, not by --page
  await expect.poll(() => ground(page)).toBe("rgb(1, 2, 3)");
});

test("the companion's page takes a CSS changed while its connection was down once it connects again", async ({ page, request }) => {
  const hear = await deafen(page);
  await page.goto("/companion.html");
  await expect(page.locator("canvas.companion-figure")).toBeVisible();
  const own = () => page.evaluate(() => [...document.querySelectorAll("style")].some((style) => style.textContent?.includes("rgb(1, 2, 3)")));
  expect((await request.patch("/api/settings", { data: { own_css: OWN } })).status()).toBe(200);
  await page.waitForTimeout(500); // unheard: the connection is down
  expect(await own()).toBe(false);
  await hear();
  await expect.poll(own).toBe(true);
});
