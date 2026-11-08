import type { APIRequestContext, Page } from "@playwright/test";
import { expect, test } from "../test";

// The tabs in the title bar (boards "Tabs · the tab bar" and "Tabs · all tabs"): each keeps its page, scroll and
// unsent words; a link is opened in a new tab by Ctrl+click and a middle-click, never twice; "+", ×, a
// middle-click on a tab, dragging, "All tabs", the desktop app's keys (the page told it is the desktop app's,
// `asDesktop`) and the tabs restored at the next start. A tab is asked for by its title (`tab`), the bar's
// tabs in order by `titles`; Settings is the page that scrolls (`scrolled`).

/** Makes a card with the character Mira, and a chat with her: the chat's number. */
async function chatWithMira(request: APIRequestContext): Promise<number> {
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: (await made.json()).version_id, character: "mira" }] } });
  expect(started.status(), await started.text()).toBe(201);
  return (await started.json()).chat.id;
}

const bar = (page: Page) => page.locator("#titlebar");
const tab = (page: Page, title: string) => bar(page).locator(".wtab", { has: page.locator(".tt", { hasText: new RegExp(`^${title}$`) }) });
const titles = (page: Page) => bar(page).locator(".wtab .tt");
const railLink = (page: Page, name: string) => page.locator("#rail").getByRole("link", { name, exact: true });
/** How far the page in view is scrolled; `to` scrolls it first. */
const scrolled = (page: Page, to?: number) => page.locator(".main").evaluate((node, to) => (to === undefined ? node.scrollTop : (node.scrollTop = to)), to);
/** The page believes it is in the desktop app's window, from its start on. */
const asDesktop = (page: Page) => page.addInitScript(() => void (window.cardwaveDesktop = { downloads: "", logs: "" }));

test("a tab keeps its page, its scroll and the words not sent; Ctrl+click opens a link in a new tab, never a second one", async ({ page, request }) => {
  const chat = await chatWithMira(request);
  await page.goto(`/#/chats/${chat}`);
  await expect(titles(page)).toHaveText(["Mira"]);
  await page.locator("#composer").fill("Half a thought");

  await railLink(page, "Settings").click({ modifiers: ["Control"] });
  await expect(titles(page)).toHaveText(["Mira", "Settings"]);
  await expect(tab(page, "Settings")).toHaveAttribute("aria-selected", "true");
  await expect(page).toHaveURL(/#\/settings$/);
  await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible();
  await scrolled(page, 300);

  await tab(page, "Mira").click();
  await expect(page.locator("#composer")).toHaveValue("Half a thought");
  await tab(page, "Settings").click();
  expect(await scrolled(page)).toBe(300);

  // Back goes to the tab before; a tab is shown from the keyboard too.
  await page.goBack();
  await expect(tab(page, "Mira")).toHaveAttribute("aria-selected", "true");
  await tab(page, "Settings").focus();
  await page.keyboard.press("Enter");
  await expect(tab(page, "Settings")).toHaveAttribute("aria-selected", "true");

  // The chat's line in the rail shows the tab that holds the chat; a middle-click on a link holds to that too.
  await page.locator("#rail .nav-chat").first().click();
  await expect(tab(page, "Mira")).toHaveAttribute("aria-selected", "true");
  await railLink(page, "Settings").click({ button: "middle" });
  await expect(tab(page, "Settings")).toHaveAttribute("aria-selected", "true");
  await expect(titles(page)).toHaveCount(2);

  // A plain click changes the tab in view.
  await railLink(page, "Personas").click();
  await expect(titles(page)).toHaveText(["Mira", "Personas"]);
});

test("\"+\" opens the start view; × and a middle-click close a tab, and closing the last leaves one on the start view", async ({ page }) => {
  await page.goto("/#/settings");
  await bar(page).getByRole("button", { name: "New tab" }).click();
  await expect(titles(page)).toHaveText(["Settings", "Chats"]);
  await expect(page).toHaveURL(/#\/chats$/);
  await tab(page, "Settings").click({ button: "middle" });
  await expect(titles(page)).toHaveText(["Chats"]);
  await railLink(page, "Lorebooks").click();
  await tab(page, "Lorebooks").getByRole("button", { name: "Close tab" }).click();
  await expect(titles(page)).toHaveText(["Chats"]);
  await expect(page).toHaveURL(/#\/chats$/);
});

test("the tabs come back when the app opens again, the one in view with its scroll", async ({ page }) => {
  await page.goto("/#/library/personas");
  await railLink(page, "Settings").click({ modifiers: ["Control"] });
  await expect(page.getByRole("heading", { name: "Settings" })).toBeVisible();
  await scrolled(page, 250);
  // A scroll is kept a moment after it stops.
  await page.waitForTimeout(500);
  await page.reload();
  await expect(titles(page)).toHaveText(["Personas", "Settings"]);
  await expect(page).toHaveURL(/#\/settings$/);
  await expect.poll(() => scrolled(page)).toBe(250);
});

test("\"All tabs\" lists every tab, those hidden too, and the one taken from it shows in the bar's last place", async ({ page }) => {
  await page.setViewportSize({ width: 800, height: 800 });
  await page.goto("/#/chats");
  for (const name of ["Characters", "Lorebooks", "Personas", "Memories", "Documents", "Settings"]) await railLink(page, name).click({ modifiers: ["Control"] });
  const shown = await titles(page).count();
  expect(shown).toBeLessThan(7);
  // The last tab shown ends before "+".
  const lastRight = await bar(page).locator(".wtab").last().evaluate((node) => node.getBoundingClientRect().right);
  const plusLeft = await bar(page).getByRole("button", { name: "New tab" }).evaluate((node) => node.getBoundingClientRect().left);
  expect(lastRight).toBeLessThanOrEqual(plusLeft);
  await bar(page).getByRole("button", { name: "All tabs" }).click();
  const lines = bar(page).getByRole("menuitem");
  // The tab in view moved to the last place shown each time; every tab is there.
  await expect(lines).toHaveCount(7);
  for (const name of ["Chats", "Characters", "Lorebooks", "Personas", "Memories", "Documents", "Settings"]) await expect(lines.filter({ hasText: new RegExp(`^${name}`) })).toHaveCount(1);
  await expect(lines.filter({ hasText: "Settings" })).toHaveAttribute("aria-current", "true");
  // A tab the bar does not show, taken from the menu, shows in the bar's last place.
  const inBar = await titles(page).allTextContents();
  const hidden = ["Characters", "Lorebooks", "Personas", "Memories", "Documents"].find((name) => !inBar.includes(name))!;
  await lines.filter({ hasText: new RegExp(`^${hidden}`) }).click();
  await expect(bar(page).getByRole("menu")).toBeHidden();
  await expect(titles(page).last()).toHaveText(hidden);
  await expect(tab(page, hidden)).toHaveAttribute("aria-selected", "true");
  await expect(titles(page)).toHaveCount(shown);
});

test("a tab is dragged to another place", async ({ page }) => {
  await page.goto("/#/library/personas");
  await railLink(page, "Memories").click({ modifiers: ["Control"] });
  await railLink(page, "Documents").click({ modifiers: ["Control"] });
  const from = (await tab(page, "Documents").boundingBox())!;
  const to = (await tab(page, "Personas").boundingBox())!;
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
  await page.mouse.down();
  await page.mouse.move(to.x + 10, to.y + to.height / 2, { steps: 8 });
  await page.mouse.up();
  await expect(titles(page)).toHaveText(["Documents", "Personas", "Memories"]);
  await expect(tab(page, "Documents")).toHaveAttribute("aria-selected", "true");
});

test("in the desktop app Ctrl+T, Ctrl+Tab, Ctrl+Shift+Tab and Ctrl+W are the tabs'", async ({ page }) => {
  await asDesktop(page);
  await page.goto("/#/library/personas");
  await expect(bar(page).getByRole("button", { name: "Minimize" })).toBeVisible();
  await page.keyboard.press("Control+t");
  await expect(titles(page)).toHaveText(["Personas", "Chats"]);
  await page.keyboard.press("Control+Tab");
  await expect(tab(page, "Personas")).toHaveAttribute("aria-selected", "true");
  await page.keyboard.press("Control+Shift+Tab");
  await expect(tab(page, "Chats")).toHaveAttribute("aria-selected", "true");
  await page.keyboard.press("Control+w");
  await expect(titles(page)).toHaveText(["Personas"]);
  await expect(page).toHaveURL(/#\/library\/personas$/);
});

test("at 600 px there is no tab bar", async ({ page }) => {
  await page.setViewportSize({ width: 600, height: 900 });
  await page.goto("/#/settings");
  await expect(page.locator("#topbar")).toBeVisible();
  await expect(bar(page)).toBeHidden();
});
