import type { Page } from "@playwright/test";
import { expect, linesOf, test } from "../test";
import { cardFile } from "../card";

// Documents: "Attach picture or document" in the "+" of a chat's message field and "Add a document" in a card's "…"
// give a file to the chat or the card, and Knowledge › Documents lists them and deletes one, with the notice's Undo. No search model is set
// up here, so the list says once "The AI finds the right parts by meaning once Search is set up."; what a reply is given of one is the server's tests'.

test.beforeAll(async ({ request }) => {
  const made = await request.post("/api/cards", { data: cardFile({ name: "Mira", description: "Keeper of the lighthouse.", first_mes: "The lamp is lit." }) });
  expect(made.status(), await made.text()).toBe(201);
});

const row = (page: Page) => page.locator(".document-row");

/** Picks `line` of a menu opened by `opener`, and gives the file field it opens a text file `name`. */
async function give(page: Page, opener: () => Promise<void>, name: string, text: string, line = "Add a document"): Promise<void> {
  const chooser = page.waitForEvent("filechooser");
  await opener();
  await page.getByRole("menuitem", { name: line, exact: true }).click();
  await (await chooser).setFiles({ name, mimeType: "text/plain", buffer: Buffer.from(text) });
}

test("Documents empty says how one is added and offers Add document under its words", async ({ page }) => {
  await page.goto("/#/knowledge/documents");
  await expect(page.locator(".empty")).toContainText("No documents yet. Add one here, or attach one in a chat.");
  const chooser = page.waitForEvent("filechooser");
  await page.locator(".empty").getByRole("button", { name: "Add a document", exact: true }).click();
  await chooser;
});

test("a document is added to a chat and to a character, and Knowledge › Documents lists and deletes it", async ({ page }) => {
  await page.goto("/#/library");
  await page.getByRole("link", { name: "Mira", exact: true }).click();
  await page.getByRole("button", { name: "Start a chat with this message", exact: true }).click();
  await expect(page.locator(".message .text")).toHaveText(["The lamp is lit."]);
  const attach = "Attach picture or document";
  await give(page, () => page.getByRole("button", { name: "Attach, or let the AI write" }).click(), "Coast notes.txt", "The tide turns at nine.", attach);
  await expect(page.locator(".waiting-attachments .attached-file")).toContainText("Coast notes.txt");
  // A file of another kind is refused, with the reason.
  await give(page, () => page.getByRole("button", { name: "Attach, or let the AI write" }).click(), "lamp.gif", "not a document", attach);
  await expect(page.getByText("A document is a .txt, .md, .pdf or .docx file")).toBeVisible();

  await page.goto("/#/library");
  await page.locator(".card-row").hover();
  await give(page, () => page.locator(".card-row").getByRole("button", { name: "More" }).click(), "Saltmere.md", "# Saltmere\nA town by the sea.");
  await expect(page.locator("#toast span")).toHaveText("“Saltmere.md” added to Mira.");

  await page.locator("#rail").getByRole("link", { name: "Documents" }).click();
  await expect(page.locator("#rail [aria-current]")).toHaveText("Documents");
  await expect(row(page).locator(".medium")).toHaveText(["Saltmere", "Coast notes"]);
  await expect(row(page).first().locator(".meta")).toHaveText("Markdown · 7 words · For the character Mira");
  await expect(page.getByText("The AI finds the right parts by meaning once Search is set up.")).toHaveCount(1);
  await expect(row(page).first().getByRole("link")).toHaveText("Mira");
  await expect(row(page).last().getByRole("link")).toHaveAttribute("href", /#\/chats\/\d+/);

  // Delete, and Undo.
  await row(page).first().hover();
  await row(page).first().getByRole("button", { name: "More" }).click();
  await page.getByRole("menuitem", { name: "Delete", exact: true }).click();
  await expect(row(page)).toHaveCount(1);
  await expect(page.locator("#toast span")).toHaveText("Document deleted.");
  await page.locator("#toast").getByRole("button", { name: "Undo" }).click();
  await expect(row(page)).toHaveCount(2);
});

test("“Add a document” of Knowledge › Documents asks for a file, then for the chat or character it is for", async ({ page }) => {
  await page.goto("/#/knowledge/documents");
  const chooser = page.waitForEvent("filechooser");
  await page.getByRole("button", { name: "Add a document", exact: true }).click();
  await (await chooser).setFiles({ name: "Harbour.txt", mimeType: "text/plain", buffer: Buffer.from("Boats come in at dawn.") });
  const dialog = page.getByRole("dialog", { name: "Add a document" });
  // A chat may be called as its character is: the character is the last "Mira", in the group Characters.
  const owner = dialog.getByLabel("For");
  await owner.click();
  await linesOf(owner).filter({ hasText: /^Mira$/ }).last().click();
  await dialog.getByRole("button", { name: "Add", exact: true }).click();
  await expect(page.locator("#toast span")).toHaveText("“Harbour.txt” added to Mira.");
  await expect(row(page).filter({ hasText: "Harbour" })).toContainText("For the character Mira");
});
