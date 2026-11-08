import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { APIRequestContext } from "@playwright/test";
import { expect, test } from "../test";
import { startFakeProvider, type FakeProvider } from "../fake-provider";
import { NOW, picture, stopClock } from "../pictures";

// The coding team: Settings › Tools › "Coding team" sets the team, and the team goes by Settings › Tools; "+" ›
// "Start a coding task" in a chat starts one, whose card follows it there, asks before the worker writes ("Ask
// before writing" on), and says the auditor's verdict; its page shows the steps, the changed file and the checkpoints, and "Undo
// all" puts the folder back. The stand-in `api` is every role's model, which calls the roles' tools in the
// order they ask (`calls`): the plan, the worker's write and report, the auditor's verdict. The pictures (1440
// px, light) are of the settings page and of a task's page answered by `page.route`, as a task's moments are
// the server's.

let api: FakeProvider;
let folder: string;

test.beforeAll(async () => {
  api = await startFakeProvider();
  folder = mkdtempSync(join(tmpdir(), "cardwave-coding-"));
});
test.afterAll(async () => {
  await api.close();
  rmSync(folder, { recursive: true, force: true });
});

/** A chat with Mira, a roleplay, and one without a character: their numbers. */
async function chat(request: APIRequestContext): Promise<{ roleplay: number; plain: number }> {
  await request.put("/api/provider", { data: { base_url: api.url, model: "tide-1" } });
  const data = { title: "North Light", tags: [], creator: "", name: "Mira", greetings: ["You came in the storm."], description: "A lighthouse keeper.", personality: "", scenario: "", example_dialogue: "", creator_notes: "" };
  const made = await request.post("/api/cards/new", { data });
  expect(made.status(), await made.text()).toBe(201);
  const card = await (await request.get(`/api/cards/${(await made.json()).card_id}`)).json();
  const started = await request.post("/api/chats", { data: { characters: [{ version_id: card.card.version_id, character: card.characters[0].id }] } });
  expect(started.status(), await started.text()).toBe(201);
  const plain = await request.post("/api/chats", { data: { characters: [] } });
  expect(plain.status(), await plain.text()).toBe(201);
  return { roleplay: (await started.json()).chat.id, plain: (await plain.json()).chat.id };
}

test("a coding task is set up, started in a chat, allowed to write, and undone from its page", async ({ page, request }) => {
  const { roleplay, plain: id } = await chat(request);
  await page.goto("/#/settings");
  await page.getByRole("link", { name: /Coding team/ }).click();
  await expect(page.locator(".settings-group p.hint").first()).toHaveText("Balanced: one planner, two workers and an auditor who runs the tests.");
  // The team goes by Settings › Tools: Files on for the folder, asking before a write.
  const tools = await request.patch("/api/settings", { data: { tools: { folder, files: true, ask_writes: true } } });
  expect(tools.status(), await tools.text()).toBe(200);

  api.calls("plan", { steps: ["Write hello.txt"], test_command: "type hello.txt" });
  api.calls("write_file", { path: "hello.txt", content: "hi\n" });
  api.calls("report", { summary: "Wrote hello.txt." });
  api.calls("verdict", { passed: true, tests_passed: 1, tests_total: 1, failures: [], notes: "" });
  // A roleplay does not offer it; a chat without a character does.
  await page.goto(`/#/chats/${roleplay}`);
  await page.getByRole("button", { name: "Attach, or let the AI write" }).click();
  await expect(page.getByRole("menuitem", { name: "Make a picture" })).toBeVisible();
  await expect(page.getByRole("menuitem", { name: "Start a coding task" })).toHaveCount(0);
  await page.keyboard.press("Escape");
  await page.goto(`/#/chats/${id}`);
  await page.getByRole("button", { name: "Attach, or let the AI write" }).click();
  await page.getByRole("menuitem", { name: "Start a coding task" }).click();
  const dialog = page.getByRole("dialog", { name: "Start a coding task" });
  await dialog.getByLabel("Goal").fill("Say hi in hello.txt");
  await dialog.getByLabel("Folder").fill(folder);
  await expect(dialog.getByLabel("Team")).toContainText("Balanced");
  await dialog.getByRole("button", { name: "Start" }).click();

  const card = page.locator(".task-card");
  await expect(card.locator(".task-goal")).toHaveText("Say hi in hello.txt");
  const asking = card.locator(".tool-ask");
  await expect(asking.locator(":scope > span")).toHaveText("Worker 1 wants to write “hello.txt” in your folder:");
  await expect(asking.getByRole("switch")).toHaveCount(0);
  await asking.getByRole("button", { name: "Allow" }).click();
  await expect(card.locator(".task-state")).toHaveText("Done");
  await expect(card).toContainText("1 of 1 tests pass");
  expect(readFileSync(join(folder, "hello.txt"), "utf8")).toBe("hi\n");

  await card.getByRole("button", { name: "Open coding task" }).click();
  await expect(page.locator(".task-title h1")).toHaveText("Say hi in hello.txt");
  await expect(page.locator("button.task-step")).toHaveText([/Planner · Planned 1 step/, /Worker 1 · Wrote hello.txt/, /Auditor · Passed · 1 of 1 tests pass/]);
  await page.locator("button.task-file").click();
  await expect(page.locator(".task-diff pre")).toContainText("+hi");
  await page.getByRole("button", { name: "Undo all" }).click();
  await expect(page.locator(".task-side .question")).toHaveText("Put the folder back as it was before the task?");
  await page.locator(".task-side button.danger").click();
  await expect(page.locator(".task-side")).toContainText("None yet");
  expect(existsSync(join(folder, "hello.txt"))).toBe(false);
});

test.describe("at 1440 px, light", () => {
  test.use({ viewport: { width: 1440, height: 900 }, colorScheme: "light" });
  test.beforeEach(({ page }) => stopClock(page));

  const at = NOW.getTime();
  const verdict = { passed: false, tests_passed: 41, tests_total: 42, failures: [{ name: "export › keeps the asterisks", output: "Expected: *waves*\nReceived: waves" }], notes: "One test fails." };

  test("Coding team: the Balanced team, its roles, permissions and recent tasks", async ({ page, request }) => {
    await request.put("/api/provider", { data: { base_url: "http://127.0.0.1:1/v1", model: "tide-1", worker_model: "tide-mini" } });
    // The team as it is at first, whatever a test before changed.
    const permissions = { read: "allow", write: "allow", commands: "ask", install: "ask", web: "never" };
    const coding = { team: "balanced", planner_model: null, worker_model: null, auditor_model: null, workers: 2, audit: "end", permissions };
    expect((await request.patch("/api/settings", { data: { coding } })).status()).toBe(200);
    const tasks = [
      { id: 2, chat_id: 1, goal: "Add an export of chats as Markdown", folder: "C:\\Projects\\cardwave", state: "done", verdict, started_at: at },
      { id: 1, chat_id: 1, goal: "Fix the dates in the list", folder: "C:\\Projects\\cardwave", state: "running", verdict: null, started_at: at },
    ];
    await page.route("**/api/coding/tasks", (route) => route.fulfill({ json: tasks }));
    await page.goto("/#/settings/tools/coding");
    await expect(page.getByRole("link", { name: /Fix the dates/ })).toBeVisible();
    await picture(page, "coding-team-1440-light");
  });

  test("A coding task's page: steps, the verdict, checkpoints and changed files", async ({ page }) => {
    const step = (id: number, who: object, what: object, detail: object, state: string, checkpoint: object | null) => ({ id, who, what, detail, state, output: "", files: [], checkpoint, undone: false, started_at: at });
    const task = {
      id: 7,
      chat_id: 1,
      chat_title: "North Light",
      message_id: 3,
      goal: "Add an export of chats as Markdown",
      folder: "C:\\Projects\\cardwave",
      crew: { team: "balanced", workers: 2, audit: "end", planner_model: "tide-1", worker_model: "tide-mini", auditor_model: "tide-1", permissions: { read: "allow", write: "allow", commands: "ask", install: "ask", web: "never" } },
      state: "done",
      planned: 2,
      verdict,
      error: null,
      started_at: at,
      ended_at: at,
      steps: [
        step(1, { role: "planner" }, { code: "planned", steps: 2 }, { code: "show_plan" }, "done", null),
        step(2, { role: "worker", number: 1 }, { code: "work", step: "Write src/export/markdown.ts" }, { code: "changed", added: 124, removed: 0, files: 1 }, "done", { code: "before_step", step: 1 }),
        step(3, { role: "worker", number: 2 }, { code: "work", step: "Write the tests" }, { code: "changed", added: 4, removed: 4, files: 1 }, "done", { code: "before_step", step: 2 }),
        step(4, { role: "auditor" }, { code: "verdict", passed: false, tests_passed: 41, tests_total: 42 }, { code: "none" }, "done", null),
      ],
      files: [
        { path: "src/export/markdown.ts", added: 124, removed: 0, diff: "" },
        { path: "src/views/chat.ts", added: 4, removed: 4, diff: "" },
      ],
      ask: null,
    };
    await page.route("**/api/coding/tasks/7", (route) => route.fulfill({ json: task }));
    await page.goto("/#/chats/1/tasks/7");
    await expect(page.locator(".task-verdict")).toContainText("41 of 42 tests pass");
    await picture(page, "coding-task-1440-light");
  });
});
