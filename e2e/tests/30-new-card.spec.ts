import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { ccv4File } from "../card";

// "New card": the card's page empty, saved as it is written. The card is made at the first letter of its
// title, with what was written before; "New chat" waits for a title and a first message; "More texts" opens
// the others; while only the title is written, the card menu discards it. Every test makes a card under a
// title no other has. The account is called `local`, which a new card says it is by.
//
// `leave` takes the focus out of what is written, as a click elsewhere does, which saves it.

const button = (page: Page, name: string) => page.getByRole("button", { name, exact: true });
const field = (page: Page, name: string) => page.getByRole("textbox", { name, exact: true });
/** A text of the card on its page, by its name. */
const part = (page: Page, name: string) => page.locator(".reading section.tb", { has: page.getByRole("heading", { name, exact: true }) });
const shows = (page: Page, name: string) => part(page, name).locator(".tb-body");
const leave = (page: Page, name: string) => field(page, name).evaluate((node) => (node as HTMLElement).blur());
const headings = (page: Page) => page.locator(".reading h2.tb-name");
/** The cards of the library under `title`. */
const titled = async (page: Page, title: string) =>
  ((await (await page.request.get("/api/cards")).json()) as { id: number; title: string }[]).filter((card) => card.title === title);

/** Opens a new card: the title has the focus. */
async function open(page: Page): Promise<void> {
  await page.goto("/#/library/new");
  await expect(field(page, "Title")).toBeFocused();
}

test("a new card is the empty card page, made at the first letter of its title with what was written before", async ({ page, request }) => {
  await open(page);
  await expect(page.locator(".crumbs")).toHaveText("Characters/New character");
  await expect(field(page, "Title")).toHaveAttribute("placeholder", "Name the character");
  await expect(headings(page)).toHaveText(["First message", "Description", "Personality", "Scenario"]);
  await expect(shows(page, "Description")).toHaveText("Empty · who the character is: looks, past, situation");
  // No short rule and no Facts until it has texts, and no chat until it has a title and a first message.
  await expect(page.locator(".short-rule")).toBeHidden();
  await expect(page.locator(".side .facts")).toHaveCount(0);
  await expect(button(page, "New chat")).toBeDisabled();
  await expect(button(page, "New chat")).toHaveAttribute("title", "Write a name and a first message to start a chat");
  await expect(page.getByRole("button", { name: "Make a picture" }).first()).toHaveAttribute("title", "Name the character first");
  expect(await page.locator(".side > div:not(.facts) p").allInnerTexts()).toEqual(["Add tags", "Plays the title character\nby local"]);
  // The empty first message says what its stars do, and offers no second one before it has words.
  await expect(shows(page, "First message")).toHaveText("Empty · the first message; *stars* make the narration italic");
  await expect(part(page, "First message").locator(".tb-head .count, .tb-head button")).toHaveCount(0);

  let made = 0;
  page.on("request", (sent) => (made += Number(sent.url().endsWith("/api/cards/new"))));
  await shows(page, "Description").click();
  await field(page, "Description").fill("{{char}} keeps the light on Tern Rock.");
  await leave(page, "Description");
  expect(made).toBe(0);
  await expect(page.locator(".short-rule")).toBeVisible();

  await page.locator(".hero h1").click();
  await field(page, "Title").pressSequentially("Tern Rock: made");
  await field(page, "Title").press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await expect(page.locator(".crumbs")).toHaveText("Characters/Tern Rock: made");
  expect(made).toBe(1);
  await expect(page.locator(".pbar .saved")).toHaveText("Saved");
  const id = Number(page.url().split("/").pop());
  const form = async () => (await request.get(`/api/cards/${id}/edit`)).json();
  await expect.poll(async () => (await form()).title).toBe("Tern Rock: made");
  const kept = await form();
  expect([kept.characters[0].name, kept.characters[0].description[0].text, kept.creator]).toEqual(["Tern Rock: made", "{{char}} keeps the light on Tern Rock.", "local"]);

  // Its character's name, and the first message, which makes it ready for a chat.
  await page.locator(".side").getByText("Tern Rock: made", { exact: true }).click();
  await field(page, "Name in the chat").fill("Wren");
  await field(page, "Name in the chat").press("Enter");
  await expect(button(page, "New chat")).toBeDisabled();
  await shows(page, "First message").click();
  await field(page, "First message").fill("\"You are late,\" says {{char}}.");
  // Ready as soon as the first message has a letter, before it is left.
  await expect(button(page, "New chat")).toBeEnabled();
  await leave(page, "First message");
  await expect(part(page, "First message").locator(".tb-head .count")).toHaveText("1 / 1");
  await expect(button(page, "New chat")).toBeEnabled();
  await expect(page.locator(".side .facts p")).toHaveText(/^[\d,]+ tokens$/);

  // "More texts" opens the others in place.
  await button(page, "More texts").click();
  await expect(headings(page)).toHaveText(["First message", "Description", "Personality", "Scenario", "Example dialogue", "Instructions for the AI", "Instructions after the latest messages", "Creator notes", "How often they speak in a group chat"]);
  await expect(button(page, "More texts")).toHaveCount(0);

  await button(page, "New chat").click();
  await expect(page.locator(".message .text")).toHaveText(["\"You are late,\" says Wren."]);
  expect(await titled(page, "Tern Rock: made")).toHaveLength(1);
});

test("a prompt written before the card is made is the made card's prompt", async ({ page, request }) => {
  await open(page);
  await button(page, "More texts").click();
  await shows(page, "Instructions for the AI").click();
  await field(page, "Instructions for the AI").fill("Speak plainly.");
  await leave(page, "Instructions for the AI");
  await page.locator(".hero h1").click();
  await field(page, "Title").pressSequentially("Tern Rock: prompted");
  await field(page, "Title").press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  const id = Number(page.url().split("/").pop());
  await expect.poll(async () => (await (await request.get(`/api/cards/${id}/edit`)).json()).characters[0].system_prompt.map((one: { text: string }) => one.text)).toEqual(["Speak plainly."]);
  await expect(shows(page, "Instructions for the AI")).toHaveText("Speak plainly.");
});

test("while only its title is written, the card menu discards the card for good", async ({ page }) => {
  await open(page);
  // Before anything is written, there is nothing to discard but the page.
  await button(page, "Character menu").click();
  await expect(page.getByRole("menuitem")).toHaveText(["Discard character"]);
  await page.keyboard.press("Escape");
  await page.locator(".hero h1").click();
  await field(page, "Title").pressSequentially("Tern Rock: discarded");
  await field(page, "Title").press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await expect.poll(() => titled(page, "Tern Rock: discarded")).toHaveLength(1);
  await button(page, "Character menu").click();
  await expect(page.getByRole("menuitem", { name: "Move to Trash" })).toHaveCount(0);
  await page.getByRole("menuitem", { name: "Discard character" }).click();
  await expect(page).toHaveURL(/#\/library$/);
  expect(await titled(page, "Tern Rock: discarded")).toHaveLength(0);
  expect(JSON.stringify(await (await page.request.get("/api/trash")).json())).not.toContain("Tern Rock: discarded");

  // With a text written it is a card like any other: Delete moves it to the Trash.
  await open(page);
  await field(page, "Title").pressSequentially("Tern Rock: kept");
  await field(page, "Title").press("Enter");
  await expect(page).toHaveURL(/#\/library\/\d+$/);
  await shows(page, "Scenario").click();
  await field(page, "Scenario").fill("The boat is late.");
  await leave(page, "Scenario");
  await expect(page.locator(".short-rule")).toBeVisible();
  await button(page, "Character menu").click();
  await expect(page.getByRole("menuitem", { name: "Discard character" })).toHaveCount(0);
  await expect(page.getByRole("menuitem", { name: "Move to Trash" })).toBeVisible();
});

test("a card opened from the library with no text written is moved to the Trash, not discarded", async ({ page, request }) => {
  const made = await request.post("/api/cards", { data: ccv4File(`spec = "ccv4:1.0.0"

[meta-info]
title = "Tern Rock: bare"
tags = ["harbour"]
`) });
  expect(made.status(), await made.text()).toBe(201);
  await page.goto(`/#/library/${(await made.json()).card_id}`);
  await button(page, "Character menu").click();
  await expect(page.getByRole("menuitem", { name: "Move to Trash" })).toBeVisible();
  await expect(page.getByRole("menuitem", { name: "Discard character" })).toHaveCount(0);
});
