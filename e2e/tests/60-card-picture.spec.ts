import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile, pictureFile } from "../card";
import { setProvider, setImages } from "../stored";

// The card's picture (boards "Card's picture", "Make a picture", "Earlier pictures"): a file chosen or dropped
// replaces it, with Undo; "Make a picture" has the pretend model write what it shows and draw it; "Earlier
// pictures" brings any earlier one back; a new card takes a picture before it is made. The pictures are told
// apart by their width: the card's own 300, the files 200 and 120, the pretend model's 256.

/** What the pretend model writes that a picture shows (`PICTURE_WORDS`). */
const WORDS = "a pretend picture, soft colours";

/** The width of the card's picture as shown, once it is there. */
const shownWidth = (page: Page) =>
  expect.poll(() => page.locator(".hero-picture img").evaluate((image: HTMLImageElement) => (image.complete ? image.naturalWidth : 0)));

/** Picks `file` by a click on the picture. */
async function pick(page: Page, file: Buffer): Promise<void> {
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("button", { name: "Character picture: click to choose a picture, or drop one here" }).click();
  await (await chooser).setFiles({ name: "picture.png", mimeType: "image/png", buffer: file });
}

test("a picture chosen, dropped, made or brought back from the earlier ones becomes the card's, with Undo", async ({ page, request }) => {
  const provider = await setProvider(request, { base_url: "https://pretend.cardwave.invalid/v1", model: "pretend-chat", api_key: "sk-cardwave-fake-0000" });
  expect(provider.status(), await provider.text()).toBe(200);
  expect((await setImages(request, { model: "pretend-image" })).status()).toBe(200);
  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", first_mes: "The lamp is lit." }, [300, 450]) });
  expect(made.status(), await made.text()).toBe(201);
  await page.goto(`/#/library/${(await made.json()).card_id}`);
  await shownWidth(page).toBe(300);

  // Pointed at, the picture offers its two buttons; a click elsewhere on it picks a file.
  await page.locator(".hero-picture").hover();
  await expect(page.getByRole("button", { name: "Earlier pictures" })).toBeVisible();
  await pick(page, pictureFile([200, 300], 0x40));
  await expect(page.locator("#toast")).toContainText("Picture changed.");
  await shownWidth(page).toBe(200);
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await shownWidth(page).toBe(300);

  // A file dropped on the page, of no type its system names, which the server reads.
  const dropped = pictureFile([120, 180], 0x20).toString("base64");
  await page.locator(".hero-text").evaluate((place, base64) => {
    const bytes = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
    const files = new DataTransfer();
    files.items.add(new File([bytes], "dropped"));
    place.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: files }));
    place.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: files }));
  }, dropped);
  await shownWidth(page).toBe(120);

  // "Make a picture": the words the model wrote, a picture of them, another, and the one in view used.
  await page.locator(".hero-picture").hover();
  await page.getByRole("button", { name: "Make a picture" }).click();
  const making = page.getByRole("dialog", { name: "Make a picture" });
  await expect(making.getByLabel("What the picture shows")).toHaveValue(WORDS);
  await expect(making.locator(".hint")).toHaveText(/^Drawn by Pretend model\./);
  await expect(making.getByRole("img", { name: "The new picture" })).toBeVisible();
  await making.getByRole("button", { name: "Draw again from these words" }).click();
  await expect(making.getByText("2 of 2")).toBeVisible();
  await making.getByRole("button", { name: "Use this picture" }).click();
  await expect(making).toBeHidden();
  await shownWidth(page).toBe(256);

  // Every picture is kept: the one in use first, then the newest first; the card's own brought back.
  await page.locator(".hero-picture").hover();
  await page.getByRole("button", { name: "Earlier pictures" }).click();
  const earlier = page.getByRole("dialog", { name: "Earlier pictures" });
  await expect(earlier.locator(".thumb .meta")).toHaveText(["In use · Today", "From a file · Today", "From a file · Today", "Imported · Today"]);
  await earlier.locator(".thumb").last().click();
  await earlier.getByRole("button", { name: "Use this picture" }).click();
  await shownWidth(page).toBe(300);
});

test("a new card takes a picture before it is made, and is made with it", async ({ page }) => {
  await page.goto("/#/library/new");
  const empty = page.locator(".hero-picture.empty");
  await expect(empty).toContainText("Click to choose a picture, or drop one here");
  await expect(empty.getByRole("button", { name: "Make a picture" })).toBeDisabled();
  await pick(page, pictureFile([200, 300], 0x40));
  await shownWidth(page).toBe(200);
  await expect(page.getByRole("button", { name: "Earlier pictures" })).toHaveCount(0);
  // The title, left for the picture, is written again by a click on it.
  await page.getByRole("heading", { name: "Name the character" }).click();
  await page.getByRole("textbox", { name: "Title", exact: true }).fill("The Lighthouse Keeper");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await page.reload();
  await shownWidth(page).toBe(200);
});
