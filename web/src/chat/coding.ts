// The coding team in the chat and what its pages share: the teams and what they say (`teamSays`, `teamLabel`),
// how far a task is (`progressOf`) and what its auditor found (`verdictText`); a task's card, the message of
// the chat that the task lives in (`taskCard`: its state, folder, goal, progress, the current step, a call
// that waits, "Open task" and Stop, and when it has ended the verdict and "Undo all"); and the dialog "Start a
// coding task" (`startDialog`), whose folder and team begin as the settings have them; in the desktop app its
// "Change" opens the system's folder picker, in a browser the folder is typed. A step's who, what and grey line come
// as codes and fields (cw-coding shown.rs) and are worded here (`whoName`, `stepSays`, `stepDetail`).
//
// A card reads its task when it is made and, `SETTLE_MS` after the first of a burst, when `refresh` is called on
// the event `coding_task`; a reading answered late is not taken (`newest`).
import { failureWords } from "../language/errors";
import { wording } from "../language/language";
import { answerTask, getSettings, getTask, startTask, stopTask, undoTask } from "../api/client";
import type { Audit } from "../api/generated/Audit";
import type { Checkpoint } from "../api/generated/Checkpoint";
import type { CodingTeam } from "../api/generated/CodingTeam";
import type { Progress } from "../api/generated/Progress";
import type { Task } from "../api/generated/Task";
import type { Step } from "../api/generated/Step";
import type { StepDetail } from "../api/generated/StepDetail";
import type { StepTool } from "../api/generated/StepTool";
import type { Who } from "../api/generated/Who";
import type { Team } from "../api/generated/Team";
import type { Verdict } from "../api/generated/Verdict";
import { inDesktop, pickFolder } from "../desktop";
import { el, newest, selectField } from "../dom";
import { askFirst, formDialog } from "../dialogs";
import { icon } from "../icons";
import { askNode } from "./tool-ask";

/** The teams, in the order the settings show them. */
export const teams = (): [Team, string][] => [
  ["quick", wording("coding-quick")],
  ["balanced", wording("coding-balanced")],
  ["thorough", wording("coding-thorough")],
  ["custom", wording("coding-custom")],
];

/** A team's name. */
export const teamName = (which: Team) => teams().find(([value]) => value === which)![1];

/** How long a card waits before it reads its task on an event, so that a burst of them is read once. */
export const SETTLE_MS = 250;

/** What a task's state is called. */
export function stateWord(state: Progress): string {
  if (state === "running") return wording("coding-running");
  if (state === "done") return wording("coding-done");
  if (state === "failed") return wording("coding-failed");
  return wording("coding-stopped");
}

/** How many workers `which` has and when its auditor checks, as the server's `CodingTeam::shape`. */
export function shape(team: CodingTeam, which: Team): { workers: number; audit: Audit } {
  if (which === "quick") return { workers: 1, audit: "never" };
  if (which === "balanced") return { workers: 2, audit: "end" };
  if (which === "thorough") return { workers: 3, audit: "each_step" };
  return { workers: Math.min(3, Math.max(1, team.workers)), audit: team.audit };
}

/** The line under the teams, which says what the chosen one is. */
export function teamSays(team: CodingTeam, which: Team): string {
  const { workers, audit } = shape(team, which);
  const name = teamName(which);
  if (audit === "never") return wording("coding-team-says-alone", { name, workers });
  if (audit === "end") return wording("coding-team-says-tests", { name, workers });
  return wording("coding-team-says-steps", { name, workers });
}

/** A team as the dialog's list and the settings' link name it: "Balanced · 2 workers, auditor". */
export function teamLabel(which: Team, workers: number, audit: Audit): string {
  const name = teamName(which);
  if (audit === "end") return wording("coding-team-label-auditor", { name, workers });
  if (audit === "each_step") return wording("coding-team-label-steps", { name, workers });
  return wording("coding-team-label", { name, workers });
}

/** What the auditor found: "41 of 42 tests pass", else whether it passed. */
export function verdictText(verdict: Pick<Verdict, "passed" | "tests_passed" | "tests_total">): string {
  if (verdict.tests_passed !== null && verdict.tests_total !== null) return wording("coding-tests-pass", { passed: String(verdict.tests_passed), total: String(verdict.tests_total) });
  return verdict.passed ? wording("coding-passed") : wording("coding-problems");
}

/** The first verbs a plan's step is known to begin with that change as said; the others take -s and -ed. */
const IRREGULAR: Record<string, [string, string]> = { write: ["writes", "wrote"], rewrite: ["rewrites", "rewrote"], run: ["runs", "ran"], make: ["makes", "made"], build: ["builds", "built"], read: ["reads", "read"], set: ["sets", "set"], put: ["puts", "put"], find: ["finds", "found"], split: ["splits", "split"] };
const REGULAR = new Set(["add", "create", "update", "fix", "remove", "delete", "refactor", "implement", "test", "move", "rename", "change", "check", "install", "replace", "extend", "clean", "document", "handle", "copy", "connect", "convert", "improve", "simplify", "show", "use", "load", "save", "list", "parse", "format", "render", "export", "import", "validate", "translate", "configure", "generate"]);

/** `verb` as it is while running ("Writes") and once done ("Wrote"), or null where it is not a known one. */
function conjugate(verb: string): [string, string] | null {
  const low = verb.toLowerCase();
  const said = IRREGULAR[low] ?? (REGULAR.has(low) ? [/(s|x|z|ch|sh)$/.test(low) ? `${low}es` : low.replace(/([^aeiou])y$/, "$1ie") + "s", low.endsWith("e") ? `${low}d` : low.replace(/([^aeiou])y$/, "$1i") + "ed"] : null);
  return said && [verb[0] + said[0].slice(1), verb[0] + said[1].slice(1)];
}

/** Who works a step, as the page names them ("Planner", "Worker 2", "Auditor"). */
export function whoName(who: Who): string {
  if (who.role === "worker") return wording("coding-worker", { number: who.number });
  return who.role === "planner" ? wording("label-coding-planner") : wording("label-coding-auditor");
}

/** What a step does: a worker's step of the plan as the planner wrote it, the others worded. */
function stepWhat(step: Pick<Step, "what">): string {
  const what = step.what;
  if (what.code === "work") return what.step;
  if (what.code === "plan") return wording("coding-plans");
  if (what.code === "planned") return wording("coding-planned", { steps: what.steps });
  if (what.code === "fix") return wording("coding-fixes");
  if (what.code === "check_step") return wording("coding-checks-step", { step: what.step });
  if (what.code === "check_all") return wording("coding-checks-all");
  const said = what.passed ? wording("coding-passed") : wording("coding-problems");
  return what.tests_passed !== null && what.tests_total !== null ? wording("coding-verdict-tests", { said, tests: verdictText(what) }) : said;
}

/** What a step says (board "Coding task"): a worker's step of the plan "Write X" as "Writes X" while it runs and
 *  "Wrote X" once done, where its first verb is a known one; otherwise, and for the other steps, as `stepWhat`. */
export function stepSays(step: Pick<Step, "who" | "what" | "state">): string {
  if (step.what.code !== "work" || (step.state !== "running" && step.state !== "done")) return stepWhat(step);
  const [first = "", ...rest] = step.what.step.split(" ");
  const said = conjugate(first);
  return said ? [said[step.state === "running" ? 0 : 1], ...rest].join(" ") : step.what.step;
}

/** The grey line a call of `tool` on `target` shows while it runs. */
function toolWords(tool: StepTool, target: string): string {
  if (tool === "list_files") return target ? wording("coding-looking-at", { target }) : wording("coding-looking-at-folder");
  if (tool === "write_file") return wording("coding-writing", { target });
  if (tool === "run_command") return wording("coding-running-command", { target });
  if (tool === "install_packages") return wording("coding-installing", { target });
  if (tool === "web_search") return wording("coding-searching-web", { target });
  return wording("coding-reading", { target });
}

/** A step's grey line: the tool it calls now, what it changed ("+4 −4 · 2 files"), or "Show the plan". */
export function stepDetail(detail: StepDetail): string {
  if (detail.code === "none") return "";
  if (detail.code === "show_plan") return wording("coding-show-plan");
  if (detail.code === "tool") return toolWords(detail.tool, detail.target);
  if (detail.files === 0) return wording("coding-no-files-changed");
  const files = wording("coding-files", { files: detail.files });
  const lines = lineCounts(detail.added, detail.removed);
  return lines ? wording("coding-lines-files", { lines, files }) : files;
}

/** A checkpoint's name ("Before step 3", "Before the fix"). */
export const checkpointName = (checkpoint: Checkpoint) =>
  checkpoint.code === "before_step" ? wording("coding-before-step", { step: checkpoint.step }) : wording("coding-before-fix");

/** A file's or step's lines added and removed, the side that is nought left out ("+124", "−4", "+4 −4"). */
export const lineCounts = (added: number, removed: number) => [added && `+${added}`, removed && `−${removed}`].filter(Boolean).join(" ");

/** How far a task is: the share of its bar, and the line under it ("Step 3 of 7 · Worker 2: Write the tests"). */
export function progressOf(task: Task): { share: number; line: string } {
  if (task.state !== "running") {
    const line = task.state === "done" ? (task.verdict ? verdictText(task.verdict) : wording("setup-done")) : task.state === "failed" ? wording("coding-failed-with-error", { error: task.error ? failureWords(task.error) : "" }) : wording("coding-stopped");
    return { share: task.state === "done" ? 1 : 0, line };
  }
  const audits = task.crew.audit === "end" ? 1 : task.crew.audit === "each_step" ? task.planned : 0;
  const total = task.planned + audits;
  const worked = task.steps.filter((step) => step.who.role !== "planner");
  const finished = worked.filter((step) => step.state !== "running").length;
  const share = total === 0 ? 0 : Math.min(1, finished / total);
  const running = [...task.steps].reverse().find((step) => step.state === "running");
  if (!running) return { share, line: "" };
  const what = stepWhat(running);
  if (running.who.role === "planner") return { share, line: wording("coding-planner-doing", { what }) };
  // The plan's steps begun: the workers' steps of the plan, not a pass that fixes what the auditor found.
  const begun = Math.min(task.planned, task.steps.filter((step) => step.what.code === "work").length || 1);
  return { share, line: wording("coding-step-doing", { begun, planned: task.planned, who: whoName(running.who), what }) };
}

/** Who asks while a task waits for the user: the step that runs. */
export function asker(task: Task): string {
  const running = [...task.steps].reverse().find((step) => step.state === "running");
  return running ? whoName(running.who) : wording("coding-the-team");
}

/** The state of a task as a pill. */
export const statePill = (state: Progress) => el("span", { className: `pill task-state ${state}` }, stateWord(state));

/**
 * A task's card in its chat, read at once and on `refresh`. `failed` says why something did not work, where the
 * chat says it.
 */
export function taskCard(id: number, failed: (error: unknown) => void): { node: HTMLElement; refresh(): void } {
  const node = el("div", { className: "task-card flex f-col g-10" }, el("span", { className: "meta" }, wording("page-coding-task")));
  const order = newest();
  const draw = (task: Task) => {
    const { share, line } = progressOf(task);
    const buttons = el("div", { className: "flex wrap g-8" }, el("button", { type: "button", className: "btn btn-secondary btn-sm", onclick: () => (location.hash = `#/chats/${task.chat_id}/tasks/${task.id}`) }, wording("coding-open-task")));
    if (task.state === "running") buttons.append(el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: () => stopTask(task.id).catch(failed) }, wording("gen-stop")));
    else if (task.files.length) {
      const undo = el("button", { type: "button", className: "btn btn-quiet btn-sm" }, wording("coding-undo-all"));
      const back = () => draw(task);
      undo.onclick = () => askFirst(buttons, wording("coding-put-the-folder-back"), wording("coding-undo-all"), () => void undoTask(task.id).then(draw, failed), back);
      buttons.append(undo);
    }
    const ask = task.ask ? askNode(task.ask, asker(task), (allow) => answerTask(task.id, allow), failed, false) : null;
    node.replaceChildren(
      el("div", { className: "task-head flex ai-c g-8" }, el("span", { className: "c-grey flex" }, icon("code", 16)), el("span", { className: "semi" }, wording("page-coding-task")), statePill(task.state), el("span", { className: "meta ml-auto minw0 ellipsis task-folder" }, task.folder)),
      el("span", { className: "task-goal" }, task.goal),
      el("div", { className: "bar f-none bg-fill", role: "progressbar", ariaValueNow: String(Math.round(share * 100)), ariaValueMin: "0", ariaValueMax: "100" }, bar(share)),
      el("span", { className: task.state === "failed" ? "c-danger fs-small" : "meta" }, line),
      ask ?? "",
      buttons,
    );
  };
  const read = () => {
    const mine = order.ask();
    getTask(id).then((task) => order.take(mine) && draw(task), failed);
  };
  // The events of a task come in bursts, a few for each of its tools' calls: they are read once.
  let waiting: ReturnType<typeof setTimeout> | null = null;
  const refresh = () => {
    waiting ??= setTimeout(() => {
      waiting = null;
      read();
    }, SETTLE_MS);
  };
  read();
  return { node, refresh };
}

/**
 * The dialog "Start a coding task" over `home`: the goal, the folder and the team, which begin as the settings
 * have them; `started` is told the task that began.
 */
export async function startDialog(home: HTMLElement, chatId: number, started: (task: Task) => void, goal = ""): Promise<void> {
  const settings = await getSettings();
  const team = settings.coding;
  const goalField = el("textarea", { id: "task-goal", className: "field", rows: 3, value: goal, placeholder: wording("coding-add-an-export-of") });
  const folder = el("input", { id: "task-folder", type: "text", className: "field f-grow minw0", value: settings.tools.folder ?? "", placeholder: wording("coding-c-users-you-projects"), autocomplete: "off" });
  // The desktop app has the system's folder picker, which fills the field; a browser cannot reach one.
  let folderLine: HTMLElement = folder;
  if (inDesktop()) {
    folder.readOnly = true;
    const change = el("button", { type: "button", className: "btn btn-secondary", onclick: () => void pickFolder(folder.value).then((path) => path && (folder.value = path)) }, wording("password-change"));
    folderLine = el("div", { className: "find flex ai-c g-8" }, folder, change);
  }
  const choices = teams().map(([value]) => {
    const { workers, audit } = shape(team, value);
    return { value: value as string, label: teamLabel(value, workers, audit) };
  });
  const choice = selectField(choices, team.team, () => {}, { id: "task-team" });
  const box = formDialog(
    home,
    wording("coding-start-a-coding-task"),
    [
      el("label", { htmlFor: goalField.id }, wording("coding-goal")),
      goalField,
      el("label", { htmlFor: folder.id }, wording("label-settings-folder")),
      folderLine,
      el("label", { htmlFor: choice.field.id }, wording("team-team")),
      choice.node,
      el("p", { className: "meta" }, wording("coding-a-checkpoint-is-kept")),
    ],
    async () => {
      const task = await startTask(chatId, { goal: goalField.value, folder: folder.value, team: choice.value as Team });
      box.close();
      started(task);
    },
    wording("coding-start"),
  );
  goalField.focus();
}

/** The filled part of a progress bar, `share` of it. */
function bar(share: number): HTMLElement {
  const filled = el("div");
  filled.style.width = `${share * 100}%`;
  return filled;
}
