import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Page } from "@playwright/test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { setProvider } from "../stored";
import { button, composer, expect, test } from "../test";

// Run-through "tools and coding": a user's path through them by clicks and typing alone, each story going on from
// the one before (`serial`). The start, made through `request`: the stand-in `api` every model (`calls` of
// ../fake-provider.ts) and a temporary folder. A chat without a character (the only kind that offers it) given
// "Let the AI write tools" in its panel, whose model writes a tool, allowed and called, then listed in Settings › Advanced › "Tools the AI wrote";
// the folder chosen in Tools for the AI and Files switched on, the coding team's page, a coding task started in a
// chat without a character, allowed to write, done, and its page with its steps, file and Undo all.
// Run with RUN_THROUGHS=1 only (playwright.config.ts). Details are their own specs' (50, 52, 53).

test.describe.configure({ mode: "serial" });

let api: FakeProvider;
let folder = "";

const line = (page: Page, name: string) => page.locator(".settings-group .item", { has: page.locator(".item-label", { hasText: new RegExp(`^${name}$`) }) });
/** Opens a new chat without a character from the rail's Create menu. */
async function plainChat(page: Page) {
  await page.goto("/#/chats");
  await page.locator("#rail").getByRole("button", { name: "Create" }).click();
  await page.getByRole("menuitem", { name: "Chat without a character" }).click();
  await expect(page).toHaveURL(/#\/chats\/\d+$/);
}
const CODE = "export default function word_count({ text }) {\n  return text.trim().split(/\\s+/).filter(Boolean).length;\n}";

test.beforeAll(async ({ request }) => {
  api = await startFakeProvider();
  folder = mkdtempSync(join(tmpdir(), "cardwave-run-through-"));
  api.models(["tide-1"]);
  expect((await setProvider(request, { base_url: api.url, model: "tide-1", api_key: "sk-run-through" })).status()).toBe(200);
});
test.afterAll(async () => {
  await api.close();
  rmSync(folder, { recursive: true, force: true });
});

test("a tool the AI writes in a chat is allowed, called, and listed under Tools the AI wrote", async ({ page }) => {
  await plainChat(page);
  // The switch shows the change once the server has it (panel.ts), so it is clicked, not `check`ed.
  const code = page.getByRole("switch", { name: "Let the AI write tools" });
  await code.click();
  await expect(code).toBeChecked();
  api.calls("make_tool", { name: "word_count", description: "Counts the words of a text.", parameters: { type: "object", properties: { text: { type: "string" } } }, code: CODE });
  api.calls("word_count", { text: "the lamp is lit" });
  api.next(["It has four words."]);
  await composer(page).fill("How many words are in “the lamp is lit”?");
  await composer(page).press("Enter");
  const asking = page.locator(".tool-ask");
  await expect(asking.locator(":scope > span")).toHaveText(/ wants to use a new tool: Word count$/);
  await asking.getByRole("button", { name: "Allow" }).click();
  await expect(page.locator("article.message").last()).toContainText("It has four words.");

  await page.goto("/#/settings/advanced");
  await page.getByRole("link", { name: /Tools the AI wrote/ }).click();
  await page.locator(".written-row").getByRole("button", { name: "Word count" }).click();
  const panel = page.getByRole("dialog", { name: "Word count" });
  await expect(panel.locator("pre")).toHaveText(CODE);
  await expect(panel).toContainText("used once");
});

test("the folder chosen and Files on, the coding team's page opens with its team", async ({ page }) => {
  await page.goto("/#/settings/advanced");
  await button(page, "Change folder").click();
  const chooser = page.getByRole("dialog", { name: "Folder" });
  await chooser.getByLabel("Folder on this computer").fill(folder);
  await chooser.getByRole("button", { name: "Save" }).click();
  await expect(line(page, "Folder").locator(".meta")).toHaveText(folder);
  await line(page, "Files").getByRole("switch").check();
  await expect(line(page, "Ask before writing").getByRole("switch")).toBeChecked();
  await page.getByRole("link", { name: /Coding team/ }).click();
  await expect(page.locator(".settings-group p.hint").first()).toHaveText("Balanced: one planner, two workers and an auditor who runs the tests.");
});

test("a coding task started in a chat writes after it is allowed, and its page shows its steps and undoes them", async ({ page }) => {
  await plainChat(page);
  api.calls("plan", { steps: ["Write hello.txt"], test_command: "type hello.txt" });
  api.calls("write_file", { path: "hello.txt", content: "hi\n" });
  api.calls("report", { summary: "Wrote hello.txt." });
  api.calls("verdict", { passed: true, tests_passed: 1, tests_total: 1, failures: [], notes: "" });
  await button(page, "Attach, or let the AI write").click();
  await page.getByRole("menuitem", { name: "Start a coding task" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Goal").fill("Say hi in hello.txt");
  await dialog.getByLabel("Folder").fill(folder);
  await dialog.getByRole("button", { name: "Start" }).click();
  const card = page.locator(".task-card");
  await card.locator(".tool-ask").getByRole("button", { name: "Allow" }).click();
  await expect(card.locator(".task-state")).toHaveText("Done");
  expect(readFileSync(join(folder, "hello.txt"), "utf8")).toBe("hi\n");

  await card.getByRole("button", { name: "Open coding task" }).click();
  await expect(page.locator(".task-title h1")).toHaveText("Say hi in hello.txt");
  await expect(page.locator("button.task-step")).toHaveText([/Planner · Planned 1 step/, /Worker 1 · Wrote hello.txt/, /Auditor · Passed · 1 of 1 tests pass/]);
  await page.getByRole("button", { name: "Undo all" }).click();
  await page.locator(".task-side button.danger").click();
  await expect(page.locator(".task-side")).toContainText("None yet");
  expect(existsSync(join(folder, "hello.txt"))).toBe(false);
});
