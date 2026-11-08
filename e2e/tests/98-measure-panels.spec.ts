import { writeFileSync } from "node:fs";
import type { Page } from "@playwright/test";
import { expect, test } from "../test";
import { cardFile } from "../card";
import { startFakeProvider, type FakeProvider } from "../fake-provider";

// A measurement, not a test (runs only with MEASURE=1): every screen with a side panel or a layout like it (the
// list is `.checklists/panels-list.py`'s), at 960 and 800 px wide, the panel opened: which of the screen's
// controls it covers, whether its Close is the topmost thing where it is drawn, and whether Escape closes it.
// The table goes to `.checklists/panels.txt` (E2E_PORT=9300 beside other runs); a line per screen and width.
test.skip(process.env.MEASURE !== "1", "a measurement, MEASURE=1");
test.describe.configure({ mode: "serial" });

let provider: FakeProvider;
const ids = { chat: 0, plain: 0, lorebook: 0, entry: "", card: 0, bare: 0 };
const lines: string[] = [];

test.beforeAll(async ({ request }) => {
  provider = await startFakeProvider();
  expect((await request.put("/api/provider", { data: { base_url: provider.url, model: "test-model", api_key: "sk-test", sampling: {} } })).status()).toBe(200);
  const add = async (data: Buffer) => (await (await request.post("/api/cards", { data })).json()) as { version_id: number; card_id: number };
  const mira = await add(cardFile({ name: "Mira", first_mes: "Mira waves." }));
  ids.card = mira.card_id;
  const chat = await request.post("/api/chats", { data: { characters: [{ version_id: mira.version_id, character: "mira" }] } });
  ids.chat = (await chat.json()).chat.id;
  const plain = await request.post("/api/chats", { data: { characters: [] } });
  ids.plain = plain.ok() ? (await plain.json()).chat.id : 0;
  const book = await request.post("/api/lorebooks/new", { data: { name: "Harbour Lore" } });
  ids.lorebook = (await book.json()).id;
  const entry = await request.post(`/api/lorebooks/${ids.lorebook}/entries`, { data: { name: "Gulls", keywords: ["birds"], content: "They steal chips." } });
  ids.entry = (await entry.json()).reference;
});
test.afterAll(async () => {
  await provider.close();
  writeFileSync(`${process.env.MEASURE_OUT ?? "panels.txt"}`, `${lines.join("\n")}\n`);
});

/** What the open panel covers, whether its Close is on top, and whether Escape closes it. */
async function measure(page: Page, screen: string, panel: string): Promise<void> {
  await page.waitForTimeout(400);
  const seen = await page.evaluate((selector) => {
    const box = document.querySelector<HTMLElement>(selector);
    if (!box || box.hidden || !box.getClientRects().length) return null;
    const r = box.getBoundingClientRect();
    const name = (one: Element) => one.getAttribute("aria-label") || one.textContent?.trim().slice(0, 24) || one.tagName;
    const covered: string[] = [];
    for (const one of document.querySelectorAll<HTMLElement>("#view button, #view input, #view textarea, #view [role=button], #titlebar button")) {
      if (box.contains(one) || !one.getClientRects().length) continue;
      const c = one.getBoundingClientRect();
      const x = c.left + c.width / 2;
      const y = c.top + c.height / 2;
      if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
      const top = document.elementFromPoint(x, y);
      if (top && box.contains(top)) covered.push(name(one));
    }
    const hidden: string[] = [];
    for (const one of box.querySelectorAll<HTMLElement>("button, input, textarea, [role=button]")) {
      if (!one.getClientRects().length) continue;
      const c = one.getBoundingClientRect();
      const top = document.elementFromPoint(c.left + c.width / 2, c.top + c.height / 2);
      if (c.left + c.width / 2 > innerWidth || (top && !one.contains(top) && !box.contains(top))) hidden.push(name(one));
    }
    const close = box.querySelector<HTMLElement>("button[aria-label=Close], .panel-close button, .sheet-head button");
    let closeOk = "none";
    if (close?.getClientRects().length) {
      const c = close.getBoundingClientRect();
      const top = document.elementFromPoint(c.left + c.width / 2, c.top + c.height / 2);
      closeOk = top && close.contains(top) ? "yes" : `under ${top?.className || top?.tagName}`;
    }
    return { rect: `${Math.round(r.left)},${Math.round(r.top)} ${Math.round(r.width)}x${Math.round(r.height)} in ${innerWidth}`, covered, hidden, closeOk };
  }, panel);
  if (!seen) {
    lines.push(`${screen}: panel not shown`);
    return;
  }
  await page.keyboard.press("Escape");
  const escaped = await page.evaluate((selector) => {
    const box = document.querySelector<HTMLElement>(selector);
    return !box || box.hidden || !box.getClientRects().length || getComputedStyle(box).visibility === "hidden";
  }, panel);
  lines.push(`${screen}: at ${seen.rect}; covers [${seen.covered.join(" | ")}]; own hidden [${seen.hidden.join(" | ")}]; close ${seen.closeOk}; escape ${escaped ? "closes" : "no"}`);
}

for (const width of [960, 800]) {
  test(`panels at ${width} px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 700 });
    await page.goto(`/#/chats/${ids.chat}`);
    await page.getByRole("button", { name: "Show side panel" }).click();
    await measure(page, `chat ${width}`, ".side-panel");
    if (ids.plain) {
      await page.goto(`/#/chats/${ids.plain}`);
      await page.getByRole("button", { name: "Show side panel" }).click();
      await measure(page, `chat without character ${width}`, ".side-panel");
    }
    await page.goto(`/#/library/lorebooks/${ids.lorebook}`);
    await page.waitForSelector(".lore-entries");
    await measure(page, `lorebook list ${width}`, ".lore-entries");
    await page.goto(`/#/library/lorebooks/${ids.lorebook}/${ids.entry}`);
    await page.waitForTimeout(500);
    await measure(page, `lorebook entry ${width}`, ".lore-entries");
    await page.goto(`/#/library/${ids.card}`);
    await page.waitForSelector(".side");
    const first = await page.evaluate(() => {
      const name = document.querySelector(".hero-name, h1");
      const r = name?.getBoundingClientRect();
      return r ? `name at y ${Math.round(r.top)} of ${innerHeight}` : "no name";
    });
    lines.push(`character page ${width}: ${first}`);
    await measure(page, `character page side ${width}`, ".side");
    await page.goto("/#/library");
    await page.getByRole("button", { name: "Sort and filter" }).click();
    await measure(page, `library sort sheet ${width}`, "dialog.sheet");
    const task = { id: 7, chat_id: ids.chat, chat_title: "Mira", message_id: 1, goal: "Add an export", folder: "C:\\p", crew: { team: "balanced", workers: 2, audit: "end", planner_model: "m", worker_model: "m", auditor_model: "m", permissions: { read: "allow", write: "allow", commands: "ask", install: "ask", web: "never" } }, state: "done", planned: 0, verdict: null, error: null, started_at: 0, ended_at: 0, steps: [], files: [], ask: null };
    await page.route("**/api/coding/tasks/7", (route) => route.fulfill({ json: task }));
    await page.goto(`/#/chats/${ids.chat}/tasks/7`);
    await page.waitForTimeout(800);
    await measure(page, `coding task side ${width}`, ".task-side");
  });
}
