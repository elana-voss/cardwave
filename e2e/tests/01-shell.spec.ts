import { expect, test } from "../test";

// The shell: the page hears the server over its socket, and a start without an address leads to first run
// while no model is set up.

test("the page connects to the server, and the rail has no line that says so", async ({ page }) => {
  const heard: string[] = [];
  page.on("websocket", (socket) => socket.on("framereceived", (frame) => heard.push(String(frame.payload))));
  await page.goto("/#/chats");
  await expect.poll(() => heard.map((frame) => JSON.parse(frame).type)).toContain("hello");
  // The rail is the ways to the screens, "Create" and the account: nothing about the connection.
  await expect(page.locator("#rail")).toBeVisible();
  await expect(page.locator("#rail")).not.toContainText(/connect/i);
  await expect(page.locator("#status")).toHaveCount(0);
});

test("a start without an address leads to first run while no model is set up, and an address asked for is shown as it is", async ({ page }) => {
  // A spec file's server starts without a provider. Until it has said so, nothing is shown, not the rail
  // either, which first run does not have.
  let release = () => {};
  const held = new Promise<void>((go) => (release = go));
  await page.route("**/api/provider", async (route) => {
    await held;
    await route.fallback();
  });
  const asked = page.waitForRequest("**/api/provider");
  await page.goto("/");
  await asked;
  await expect(page.locator("#view")).toBeEmpty();
  await expect(page.locator("#rail")).toBeHidden();
  expect(new URL(page.url()).hash).toBe("");
  release();
  await expect(page).toHaveURL(/\/#\/setup$/);
  await page.unroute("**/api/provider");
  await expect(page.getByRole("heading", { name: "Provider" })).toBeVisible();
  await expect(page.locator("#rail")).toBeHidden();
  // First run took the start's place: the way back does not lead through it again.
  expect(await page.evaluate(() => history.length)).toBe(2);

  for (const [address, link] of [
    ["/#/chats", /^Chats$/],
    ["/#/library", /^Characters$/],
    // The account's button is called after the account too.
    ["/#/settings", /^Account/],
  ] as const) {
    await page.goto("about:blank");
    await page.goto(address);
    await expect(page.locator("#rail [aria-current]")).toHaveCount(1);
    await expect(page.locator("#rail [aria-current]")).toHaveAccessibleName(link);
    await expect(page.locator("#rail")).toBeVisible();
    await expect(page.locator(".setup")).toHaveCount(0);
    expect(page.url().endsWith(address)).toBe(true);
  }

  // An address that names no screen is none.
  await page.goto("about:blank");
  await page.goto("/#/");
  await expect(page).toHaveURL(/\/#\/setup$/);

  // A server that does not say whether a model is set up: the app starts on its chats, as before.
  await page.route("**/api/provider", (route) => route.fulfill({ status: 500, json: { code: "internal", error: "the server failed to handle the request", details: {} } }));
  await page.goto("about:blank");
  await page.goto("/");
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"]);
  await expect(page.locator("#rail")).toBeVisible();
  // The tab in view holds the start view, at its address.
  expect(new URL(page.url()).hash).toBe("#/chats");

  // Nor does the window stay empty for a server that takes the question and does not answer: after 3 s the chats
  // are shown, and an answer that comes then leads nowhere.
  await page.unroute("**/api/provider");
  let answer = () => {};
  const unanswered = new Promise<void>((go) => (answer = go));
  await page.route("**/api/provider", async (route) => {
    await unanswered;
    await route.fulfill({ json: null });
  });
  await page.goto("about:blank");
  const started = Date.now();
  await page.goto("/");
  await expect(page.locator("#view")).toBeEmpty();
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"], { timeout: 10_000 });
  expect(Date.now() - started).toBeGreaterThanOrEqual(3000);
  const late = page.waitForResponse((told) => told.url().endsWith("/api/provider"));
  answer();
  await late;
  await page.evaluate(() => new Promise(requestAnimationFrame));
  await expect(page.locator("#rail [aria-current]")).toHaveText(["Chats"]);
  await expect(page.locator(".setup")).toHaveCount(0);
  expect(new URL(page.url()).hash).toBe("#/chats");
});
