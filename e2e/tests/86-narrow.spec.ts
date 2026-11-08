import type { Page } from "@playwright/test";
import { expect, test } from "../test";

// A phone's width (390 px) in the longer languages: a settings line keeps its words readable, its buttons
// going under them, and a switch group stays inside the window. Each test sets the app's language and leaves it unset.

test.describe.configure({ mode: "serial" });

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
