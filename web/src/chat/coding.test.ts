// What the coding team's screens say: the teams, a task's progress and its verdict.
import { expect, test, vi } from "vitest";
import { useLanguage } from "../language/language";
import { getTask } from "../api/client";
import type { CodingTeam } from "../api/generated/CodingTeam";
import type { Step } from "../api/generated/Step";
import type { Task } from "../api/generated/Task";
import type { StepWhat } from "../api/generated/StepWhat";
import type { Who } from "../api/generated/Who";
import { checkpointName, lineCounts, progressOf, SETTLE_MS, stepDetail, stepSays, taskCard, teamLabel, teamSays, verdictText } from "./coding";

vi.mock("../api/client", async (actual) => ({ ...(await actual<typeof import("../api/client")>()), getTask: vi.fn() }));

const planner: Who = { role: "planner" };
const worker = (number: number): Who => ({ role: "worker", number });
const work = (step: string): StepWhat => ({ code: "work", step });

const team: CodingTeam = {
  team: "balanced",
  planner_model: null,
  worker_model: null,
  auditor_model: null,
  workers: 7,
  audit: "never",
};

test("each team says what it is, Custom by its own count and auditor", () => {
  expect(teamSays(team, "quick")).toBe("Quick: one planner, one worker, without an auditor.");
  expect(teamSays(team, "balanced")).toBe("Balanced: one planner, two workers and an auditor who runs the tests.");
  expect(teamSays(team, "thorough")).toBe("Thorough: one planner, three workers and an auditor who checks every step and runs the tests.");
  expect(teamSays(team, "custom")).toBe("Custom: one planner, three workers, without an auditor.");
  expect(teamLabel("balanced", 2, "end")).toBe("Balanced · 2 workers, auditor");
  expect(teamLabel("quick", 1, "never")).toBe("Quick · 1 worker");
});

test("a verdict says its tests where they ran", () => {
  const verdict = { passed: false, tests_passed: 41, tests_total: 42, failures: [], notes: "" };
  expect(verdictText(verdict)).toBe("41 of 42 tests pass");
  expect(verdictText({ ...verdict, tests_passed: null, tests_total: null, passed: true })).toBe("Passed");
});

test("a running task says its step of the plan, and its bar the share done", () => {
  const step = (who: Who, what: StepWhat, state: Step["state"], checkpoint: Step["checkpoint"] = null): Step => ({ id: 0, who, what, detail: { code: "none" }, state, output: "", files: [], checkpoint, undone: false, started_at: 0 });
  const task = {
    state: "running",
    planned: 3,
    crew: { audit: "end" },
    steps: [step(planner, { code: "planned", steps: 3 }, "done"), step(worker(1), work("Write it"), "done", { code: "before_step", step: 1 }), step(worker(2), work("Test it"), "running", { code: "before_step", step: 2 })],
    verdict: null,
    error: null,
  } as unknown as Task;
  expect(progressOf(task)).toEqual({ share: 0.25, line: "Step 2 of 3 · Worker 2: Test it" });
  expect(progressOf({ ...task, steps: [step(planner, { code: "plan" }, "running")] }).line).toBe("Planner: Plans the steps");
  expect(progressOf({ ...task, state: "failed", error: { code: "model_answer", error: "the server's own words", details: { what: "no_plan" } } }).line).toBe("Failed: The planner made no plan.");
});

test("a checkpoint is named by the page", () => {
  expect(checkpointName({ code: "before_step", step: 3 })).toBe("Before step 3");
  expect(checkpointName({ code: "before_fix" })).toBe("Before the fix");
});

test("a step that changed no file and a fix still count where the plan is", () => {
  const step = (who: Who, what: StepWhat, state: Step["state"]): Step => ({ id: 0, who, what, detail: { code: "none" }, state, output: "", files: [], checkpoint: null, undone: false, started_at: 0 });
  const task = {
    state: "running",
    planned: 3,
    crew: { audit: "never" },
    steps: [step(planner, { code: "planned", steps: 3 }, "done"), step(worker(1), work("Read it"), "done"), step(worker(2), work("Run it"), "done"), step(worker(1), { code: "fix" }, "done"), step(worker(3), work("Check it"), "running")],
    verdict: null,
    error: null,
  } as unknown as Task;
  expect(progressOf(task).line).toBe("Step 3 of 3 · Worker 3: Check it");
  // The fix is told by its code, whatever the UI's language.
  useLanguage("xx", "coding-fixes-what-the-auditor = Behebt\ncoding-step-doing = Schritt { $begun } von { $planned }");
  const fixing = { ...task, steps: [step(worker(1), work("Read it"), "done"), step(worker(1), { code: "fix" }, "done"), step(worker(2), work("Run it"), "running")] } as Task;
  expect(progressOf(fixing).line).toBe("Schritt 2 von 3");
  useLanguage("en");
});

test("a card reads its task once for a burst of events", async () => {
  vi.useFakeTimers();
  vi.mocked(getTask).mockReturnValue(new Promise(() => {}));
  const card = taskCard(5, () => {});
  for (let at = 0; at < 6; at++) card.refresh();
  expect(vi.mocked(getTask)).toHaveBeenCalledTimes(1);
  await vi.advanceTimersByTimeAsync(SETTLE_MS);
  expect(vi.mocked(getTask)).toHaveBeenCalledTimes(2);
  vi.useRealTimers();
});

test("a worker's step says its known first verb as it runs and once done, else as planned", () => {
  const step = (what: string, state: Step["state"]) => stepSays({ who: worker(1), what: work(what), state });
  expect(step("Write the tests", "running")).toBe("Writes the tests");
  expect(step("Write src/export/markdown.ts", "done")).toBe("Wrote src/export/markdown.ts");
  expect(step("Fix the parser", "running")).toBe("Fixes the parser");
  expect(step("Add a test", "done")).toBe("Added a test");
  expect(step("Update the docs", "done")).toBe("Updated the docs");
  expect(step("Write the tests", "failed")).toBe("Write the tests");
  expect(step("Tests for the export", "done")).toBe("Tests for the export");
});

test("a step's other lines and its grey line are worded from their codes", () => {
  const says = (what: StepWhat) => stepSays({ who: { role: "auditor" }, what, state: "done" });
  expect(says({ code: "planned", steps: 2 })).toBe("Planned 2 steps");
  expect(says({ code: "plan" })).toBe("Plans the steps");
  expect(says({ code: "fix" })).toBe("Fixes what the auditor found");
  expect(says({ code: "check_step", step: 3 })).toBe("Checks step 3");
  expect(says({ code: "check_all" })).toBe("Checks every step and runs the tests");
  expect(says({ code: "verdict", passed: true, tests_passed: 1, tests_total: 1 })).toBe("Passed · 1 of 1 tests pass");
  expect(says({ code: "verdict", passed: false, tests_passed: null, tests_total: null })).toBe("Found problems");
  expect(stepDetail({ code: "tool", tool: "web_search", target: "lamps" })).toBe("Searching the web: lamps");
  expect(stepDetail({ code: "tool", tool: "list_files", target: "" })).toBe("Looking at the folder");
  expect(stepDetail({ code: "changed", added: 124, removed: 0, files: 1 })).toBe("+124 · 1 file");
  expect(stepDetail({ code: "changed", added: 4, removed: 4, files: 2 })).toBe("+4 −4 · 2 files");
  expect(stepDetail({ code: "changed", added: 0, removed: 0, files: 1 })).toBe("1 file");
  expect(stepDetail({ code: "changed", added: 0, removed: 0, files: 0 })).toBe("No files changed");
  expect(stepDetail({ code: "show_plan" })).toBe("Show the plan");
  expect(stepDetail({ code: "none" })).toBe("");
});

test("a file's lines say only the side that is not nought", () => {
  expect(lineCounts(124, 0)).toBe("+124");
  expect(lineCounts(0, 4)).toBe("−4");
  expect(lineCounts(4, 4)).toBe("+4 −4");
});
