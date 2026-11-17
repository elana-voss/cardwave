import { writeFileSync } from "node:fs";
import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { addresses, seed, taskRoute, type Seeded } from "../sweep";

// A measurement, not a test (runs only with MEASURE=1): every screen of web/src/main.ts, the start and sign-in
// screens and the sheets a phone meets, at 320 and 390 px wide (the skill ux, "Phones"): whether the page scrolls
// sideways, the outermost things past the right edge (not those a sideways scroller of their own holds), targets
// under 24 px (a small one with its reach), text fields under 16 px, and the viewport meta. The table goes to MEASURE_OUT, a line per screen
// and width (Compact too), and a picture of each screen at 390 px to MEASURE_SHOTS when set; the summary is printed.
test.skip(process.env.MEASURE !== "1", "a measurement, MEASURE=1");
test.describe.configure({ mode: "serial" });

let provider: FakeProvider;
let ids: Seeded;
const lines: string[] = [];
const ACCOUNTS = [
  { id: 1, name: "local", local: true, current: false, password: true },
  { id: 2, name: "Ada", local: false, current: false, password: true },
];

test.beforeAll(async ({ browser, request }) => {
  provider = await startFakeProvider();
  const page = await browser.newPage();
  ids = await seed(page, request, provider);
  await page.close();
});
test.afterAll(async () => {
  await provider.close();
  writeFileSync(`${process.env.MEASURE_OUT ?? "phones.txt"}`, `${lines.join("\n")}\n`);
  const bad = lines.filter((line) => !line.endsWith(": fits"));
  console.log(`${lines.length} screens measured, ${bad.length} with a finding`);
});

/** What does not fit a phone on the page as it is now. */
async function measure(page: Page, screen: string): Promise<void> {
  await page.waitForTimeout(500);
  const seen = await page.evaluate(() => {
    const W = innerWidth;
    const shown = (one: Element) => {
      const r = one.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && getComputedStyle(one).visibility !== "hidden";
    };
    const name = (one: Element) => {
      const cls = typeof one.className === "string" && one.className ? `.${one.className.trim().split(/\s+/).slice(0, 2).join(".")}` : "";
      const words = (one.getAttribute("aria-label") || one.textContent || "").trim().replace(/\s+/g, " ").slice(0, 20);
      return `${one.tagName.toLowerCase()}${cls}${words ? ` "${words}"` : ""}`;
    };
    /** Held by an ancestor that scrolls or clips sideways and itself ends inside the window. */
    const held = (one: Element) => {
      for (let up = one.parentElement; up && up !== document.body; up = up.parentElement) {
        const x = getComputedStyle(up).overflowX;
        if (x !== "visible") return up.getBoundingClientRect().right <= W + 1;
      }
      return false;
    };
    const past: Element[] = [];
    for (const one of document.querySelectorAll("body *")) {
      if (!shown(one) || one.getBoundingClientRect().right <= W + 1 || held(one)) continue;
      if (getComputedStyle(one).position === "fixed" && one.getBoundingClientRect().left >= W) continue;
      if (past.some((outer) => outer.contains(one))) continue;
      past.push(one);
    }
    const small: string[] = [];
    for (const one of document.querySelectorAll("button, a[href], input:not([type=hidden]), select, [role=button], [role=tab], [role=switch], summary")) {
      if (!shown(one)) continue;
      const r = one.getBoundingClientRect();
      // A control drawn small with a larger reach around it (cardwave.css's phone block, an absolute ::after) is as large as its reach.
      const reach = getComputedStyle(one, "::after");
      const wide = reach.content !== "none" && reach.position === "absolute" ? Math.max(r.width, parseFloat(reach.width) || 0) : r.width;
      const high = reach.content !== "none" && reach.position === "absolute" ? Math.max(r.height, parseFloat(reach.height) || 0) : r.height;
      if (wide < 24 || high < 24) small.push(`${name(one)} ${Math.round(r.width)}x${Math.round(r.height)}`);
    }
    const tiny: string[] = [];
    for (const one of document.querySelectorAll("input:not([type=checkbox]):not([type=radio]):not([type=range]):not([type=file]):not([type=hidden]), textarea, select, [contenteditable=true]")) {
      if (!shown(one)) continue;
      const size = parseFloat(getComputedStyle(one).fontSize);
      if (size < 16) tiny.push(`${name(one)} ${size}px`);
    }
    return {
      scroll: document.documentElement.scrollWidth > W ? document.documentElement.scrollWidth : 0,
      past: past.map((one) => `${name(one)} to ${Math.round(one.getBoundingClientRect().right)}`),
      small,
      tiny,
      meta: document.querySelector("meta[name=viewport]")?.getAttribute("content") ?? "none",
    };
  });
  const width = `${page.viewportSize()!.width}${await page.evaluate(() => (document.documentElement.dataset.density === "compact" ? " compact" : ""))}`;
  const found: string[] = [];
  if (seen.scroll) found.push(`page ${seen.scroll} wide`);
  if (seen.past.length) found.push(`past edge [${seen.past.join(" | ")}]`);
  if (seen.small.length) found.push(`targets <24 [${seen.small.join(" | ")}]`);
  if (seen.tiny.length) found.push(`fields <16 [${seen.tiny.join(" | ")}]`);
  if (!/width=device-width/.test(seen.meta) || /user-scalable=no/.test(seen.meta)) found.push(`meta "${seen.meta}"`);
  lines.push(`${screen} ${width}: ${found.length ? found.join("; ") : "fits"}`);
  const shots = process.env.MEASURE_SHOTS;
  if (shots && width === "390") await page.screenshot({ path: `${shots}/${screen.replace(/[^a-z0-9]+/gi, "-")}.png`, fullPage: true });
}

/** Compact set before the page's first script reads it (web/public/early.js), so every screen opens in it. */
const inCompact = (page: Page) => page.addInitScript(() => localStorage.setItem("density", "compact"));

for (const [width, compact] of [[320, false], [390, false], [320, true], [390, true]] as const) {
  const named = `${width} px${compact ? ", Compact" : ""}`;
  test(`every screen at ${named}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    if (compact) await inCompact(page);
    await taskRoute(page, ids.chat);
    for (const [screen, address] of Object.entries(addresses(ids))) {
      await page.goto("about:blank");
      await page.goto(address);
      await measure(page, screen);
    }
    // The sheets and panels a phone opens.
    await page.goto("about:blank");
    await page.goto("/#/library");
    await page.getByRole("button", { name: "Sort and filter" }).click();
    await measure(page, "library sort sheet");
    await page.goto("about:blank");
    await page.goto(`/#/chats/${ids.chat}`);
    await page.getByRole("button", { name: "Show side panel" }).click();
    await measure(page, "chat side panel");
  });

  test(`the start and sign-in screens at ${named}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    if (compact) await inCompact(page);
    await page.route("**/api/lock", (route) => route.fulfill({ json: { locked: true, password: true, name: "local" } }));
    await page.goto("/");
    await expect(page.getByLabel("Password")).toBeVisible();
    await measure(page, "start");
    await page.unroute("**/api/lock");
    await page.route("**/api/sign-in", (route) => route.fulfill({ json: { needed: true, remote: true, accounts: ACCOUNTS } }));
    await page.goto("about:blank");
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Choose your account" })).toBeVisible();
    await measure(page, "sign-in");
    await page.getByText("Ada").first().click();
    await measure(page, "sign-in password");
  });
}
