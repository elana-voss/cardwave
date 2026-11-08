import type { Locator, Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";

// An import of several files: the panel at the window's foot says how far it is, with a line per file, and
// the cards are in the list as they come.
//
// The test imports cards of its own, called "Kittiwake …"; `hold` holds the page's imports back from one of
// them on.

/** A card file of one character, called as told. */
const card = (file: string, title: string) => ({ name: file, mimeType: "image/png", buffer: cardFile({ name: title, first_mes: "Kittiwakes wheel over the stack." }) });
/** A file that is no card. */
const broken = (file: string) => ({ name: file, mimeType: "image/png", buffer: Buffer.from("not a card") });

const importing = (page: Page) => page.getByRole("status", { name: "Import" });
const heading = (page: Page) => importing(page).getByRole("heading");
const lines = (page: Page) => importing(page).locator(".import-line");
const line = (page: Page, name: string) => lines(page).filter({ hasText: name });
const listed = (page: Page, title: string) => page.locator(".card-row", { hasText: title });
const pick = (page: Page, files: Parameters<Locator["setInputFiles"]>[0]) => page.locator("input[type=file]").setInputFiles(files);

/** A name no other run of this spec has used. */
const fresh = (name: string) => `Kittiwake ${name} ${Date.now()}`;

/** Opens a section of the library. */
async function library(page: Page, section = ""): Promise<void> {
  await page.goto(`/#/library${section}`);
  await expect(page.locator(".rows-plain > li").first()).toBeVisible();
}

/**
 * Holds back the imports the page sends to `path`, from the one numbered
 * `from` on (the first is 1), until the answer is called.
 */
async function hold(page: Page, path: string, from = 1): Promise<() => void> {
  let release = () => {};
  const held = new Promise<void>((go) => (release = go));
  let sent = 0;
  await page.route(path, async (route) => {
    if (route.request().method() !== "POST") return route.fallback();
    sent += 1;
    if (sent >= from) await held;
    await route.fallback();
  });
  return release;
}

test("several files have a panel that says how far the import is, with a line per file, and the cards are in the list as they come", async ({ page }) => {
  const [one, two, three] = [fresh("One"), fresh("Two"), fresh("Three")];
  await library(page);
  const release = await hold(page, "**/api/cards?name=*", 3);
  await pick(page, [card("one.png", one), broken("notes.png"), card("two.png", two), card("three.png", three)]);

  // The first is done, the second failed, the third is on its way, the last waits. A file that failed is one the import is through with.
  await expect(heading(page)).toHaveText("Importing 4 cards");
  await expect(importing(page).getByText("2 of 4 · 1 failed", { exact: true })).toBeVisible();
  const bar = importing(page).getByRole("progressbar");
  await expect(bar).toHaveAttribute("aria-valuenow", "2");
  await expect(bar).toHaveAttribute("aria-valuemax", "4");
  await expect(lines(page).locator(".import-name")).toHaveText([one, "notes.png", "two.png", "three.png"]);
  await expect(lines(page).locator(".meta")).toHaveText(["Imported", "Not a PNG file.", "Importing…", "Waiting"]);
  await expect(lines(page).locator(".import-mark")).toHaveClass([/\bdone\b/, /\bfailed\b/, /\bimporting\b/, /\bwaiting\b/]);
  const filled = async () => bar.locator("div").evaluate((node) => node.getBoundingClientRect().width / node.parentElement!.getBoundingClientRect().width);
  expect(await filled()).toBeCloseTo(0.5, 2);
  // The card that has come is in the list already; the one on its way is not.
  await expect(listed(page, one)).toHaveCount(1);
  await expect(listed(page, two)).toHaveCount(0);

  // Done, the head says what it came to, and nothing is left to count.
  release();
  await expect(heading(page)).toHaveText("3 cards imported · 1 failed");
  await expect(importing(page).locator(".import-progress")).toBeHidden();
  await expect(lines(page).locator(".import-name")).toHaveText([one, "notes.png", two, three]);
  await expect(lines(page).locator(".import-mark")).toHaveClass([/\bdone\b/, /\bfailed\b/, /\bdone\b/, /\bdone\b/]);
  await expect(line(page, "notes.png").locator(".meta")).toHaveText("Not a PNG file.");
  await expect(line(page, "notes.png").getByRole("button", { name: "Why?" })).toBeVisible();
  for (const title of [one, two, three]) await expect(listed(page, title)).toHaveCount(1);
  // The file field is empty again: the same files picked once more are imported once more.
  expect(await page.locator("input[type=file]").evaluate((field: HTMLInputElement) => field.files?.length)).toBe(0);
});
