import type { Page } from "@playwright/test";
import { chooseView, expect, test } from "../test";
import { cardFile } from "../card";

// The phone layout (cardwave.css's block "phone", the boards Phone*): the start screen's and the sign-in's password
// stand above their button, the top bar at 320 px keeps the six of the board without scrolling sideways, and the
// message field stays over an open keyboard, the thread at its end. Safari on iOS cannot run here: its keyboard only shrinks
// window.visualViewport, which the keyboard test fakes, so it walks the code path iOS takes (shell/keyboard.ts).
// At 390 px in the longer languages a settings line keeps its words readable, its buttons going under them, and a
// switch group stays inside the window; that test sets the app's language and leaves it unset, as does the one of
// a page head's button at 320 px in German (dom.ts's headButton), whose words are cut so it stays inside the window.

test("the start screen's and the sign-in's password stand above their button, Back after the form", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.route("**/api/lock", (route) => route.fulfill({ json: { locked: true, password: true, name: "local" } }));
  await page.goto("/");
  const above = async (action: string) => {
    const field = (await page.getByLabel("Password").boundingBox())!;
    const button = (await page.getByRole("button", { name: action, exact: true }).boundingBox())!;
    expect(button.y).toBeGreaterThanOrEqual(field.y + field.height);
    expect(Math.round(button.width)).toBe(Math.round(field.width));
  };
  await above("Open");
  await page.unroute("**/api/lock");
  await page.route("**/api/sign-in", (route) =>
    route.fulfill({
      json: {
        needed: true,
        remote: true,
        accounts: [
          { id: 1, name: "local", local: true, current: false, password: true },
          { id: 2, name: "Ada", local: false, current: false, password: true },
        ],
      },
    }),
  );
  await page.goto("about:blank");
  await page.goto("/");
  await page.getByText("Ada").first().click();
  await above("Sign in");
  const signIn = (await page.getByRole("button", { name: "Sign in", exact: true }).boundingBox())!;
  const back = (await page.getByRole("button", { name: "Back", exact: true }).boundingBox())!;
  expect(back.y).toBeGreaterThan(signIn.y + signIn.height);
});

test("the top bar at 320 px holds the six of the board and the page does not scroll sideways", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await page.goto("/#/library");
  await expect(page.locator("#topbar")).toBeVisible();
  const shown = await page.evaluate(() =>
    [...document.querySelectorAll("#topbar > *")]
      .filter((one) => !one.classList.contains("f-grow") && one.getBoundingClientRect().width > 0)
      .map((one) => Math.round(one.getBoundingClientRect().right)),
  );
  expect(shown).toHaveLength(6);
  expect(Math.max(...shown)).toBeLessThanOrEqual(320);
  await expect(page.locator("#topbar").getByRole("button", { name: /account/i })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(320);
});

test("an open keyboard that only shrinks the visual viewport, as on iOS, keeps the message field over it and the thread at its end", async ({ page, request }) => {
  const added = await (await request.post("/api/cards", { data: cardFile({ name: "Mira", first_mes: Array.from({ length: 40 }, (_, at) => `Mira waves, line ${at}.`).join("\n\n") }) })).json();
  const chat = await (await request.post("/api/chats", { data: { characters: [{ version_id: added.version_id, character: "mira" }] } })).json();
  await page.setViewportSize({ width: 390, height: 844 });
  await page.addInitScript(() => {
    const seen = Object.assign(new EventTarget(), { height: innerHeight, width: innerWidth, scale: 1, offsetTop: 0, offsetLeft: 0 });
    Object.defineProperty(window, "visualViewport", { value: seen, configurable: true });
    (window as unknown as { keyboard: (height: number) => void }).keyboard = (height) => {
      seen.height = innerHeight - height;
      seen.dispatchEvent(new Event("resize"));
    };
  });
  await page.goto(`/#/chats/${chat.chat.id}`);
  await expect(page.getByText("Mira waves, line 39.")).toBeVisible();
  const composer = page.locator(".composer").first();
  await expect(composer).toBeVisible();
  await page.evaluate(() => (window as unknown as { keyboard: (height: number) => void }).keyboard(300));
  await expect.poll(async () => (await composer.boundingBox())!.y + (await composer.boundingBox())!.height).toBeLessThanOrEqual(544);
  const end = () => page.locator(".chat-scroller").evaluate((one) => one.scrollHeight - one.scrollTop - one.clientHeight);
  await expect.poll(end).toBeLessThan(40);
  await page.evaluate(() => (window as unknown as { keyboard: (height: number) => void }).keyboard(0));
  await expect.poll(async () => (await composer.boundingBox())!.y + (await composer.boundingBox())!.height).toBeGreaterThan(544);
});

test("on a phone Reply length's knob stays on its track, and a card's text written in place is 16 px at least, Compact too", async ({ page, request }) => {
  const added = await (await request.post("/api/cards", { data: cardFile({ name: "Mira", description: "Mira keeps the light.", personality: "Calm." }) })).json();
  const chat = await (await request.post("/api/chats", { data: { characters: [{ version_id: added.version_id, character: "mira" }] } })).json();
  await page.addInitScript(() => localStorage.setItem("density", "compact"));
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`/#/chats/${chat.chat.id}`);
  await page.getByRole("button", { name: "Show side panel" }).click();
  const centre = (box: { y: number; height: number } | null) => Math.round(box!.y + box!.height / 2);
  const slider = page.getByRole("slider", { name: "Reply length" });
  expect(centre(await slider.boundingBox())).toBe(centre(await page.locator(".steps .trk").first().boundingBox()));
  const written = async () => {
    await page.locator(".tb-body").first().click();
    const size = await page.locator(".tb-body .in-place").first().evaluate((one) => parseFloat(getComputedStyle(one).fontSize));
    expect(size).toBeGreaterThanOrEqual(16);
    await page.keyboard.press("Escape");
  };
  await page.goto(`/#/library/${added.card_id}`);
  await written();
  await chooseView(page, "Details");
  await expect(page.locator(".cdv")).toBeVisible();
  await written();
});

/** Each line of a box with two buttons or more whose words are narrower than half the line, by its label. */
const squeezed = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>(".group > .item")]
      .filter((item) => [...item.querySelectorAll(":scope > .btn")].filter((b) => !(b as HTMLElement).hidden).length >= 2)
      .filter((item) => (item.querySelector(".item-text")?.getBoundingClientRect().width ?? 0) < item.getBoundingClientRect().width / 2)
      .map((item) => item.querySelector(".item-label")?.textContent ?? "?"),
  );

/** Each switch group's buttons that end past the window's right edge, by their words. */
const cut = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>(".seg .btn")].filter((b) => b.getBoundingClientRect().right > window.innerWidth).map((b) => b.textContent),
  );

test("at 390 px a line with two buttons keeps its words across the line, and the Team choice fits, in Korean and Spanish", async ({ page, request }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  expect((await request.patch("/api/settings", { data: { app_language: "ko" } })).status()).toBe(200);
  await page.goto("/#/settings/advanced");
  await expect(page.getByRole("button", { name: "모두 다시 설명하기" })).toBeVisible();
  expect(await squeezed(page)).toEqual([]);
  for (const language of ["es", "de", "ko"]) {
    expect((await request.patch("/api/settings", { data: { app_language: language } })).status()).toBe(200);
    await page.goto("about:blank");
    await page.goto("/#/settings/tools/coding");
    await expect(page.locator(".seg .btn").last()).toBeVisible();
    expect(await cut(page)).toEqual([]);
  }
  expect((await request.patch("/api/settings", { data: { app_language: null } })).status()).toBe(200);
});

test("at 320 px in German a page head's button stays inside the window, its words cut at their end, its icon whole", async ({ page, request }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  const added = await (await request.post("/api/cards", { data: cardFile({ name: "Mira" }) })).json();
  expect((await request.patch(`/api/cards/${added.card_id}`, { data: { trashed: true } })).status()).toBe(200);
  expect((await request.patch("/api/settings", { data: { app_language: "de" } })).status()).toBe(200);
  await page.goto("/#/settings/trash");
  const button = page.locator(".page-head").getByRole("button", { name: "Papierkorb leeren" });
  await expect(button).toBeVisible();
  const box = (await button.boundingBox())!;
  expect(box.x + box.width).toBeLessThanOrEqual(320);
  const label = button.locator(".btn-label");
  expect(await label.evaluate((node) => node.scrollWidth > node.clientWidth && getComputedStyle(node).textOverflow === "ellipsis")).toBe(true);
  expect((await request.patch("/api/settings", { data: { app_language: null } })).status()).toBe(200);
});
