// A coding task's page (board "Coding team, a task's page"), at `#/chats/{chat}/tasks/{task}`, from "Open task" on
// its card or from the recent tasks: the path "Chats / [chat] / Coding task" with Stop while it runs; the goal,
// then folder, team, start and state; a call that waits (tools.ts's card); the steps, each a line with who did
// what and a grey detail, which a press opens in place (its output, and the diff of each file it changed); the
// auditor's verdict under them; and at the right the checkpoints, each with Undo (back to before that step, asked
// first in its line), "Undo all", and the changed files with the lines added and removed, each opening its diff
// in place. At 600 px the right column goes under the steps (styles.css). Read anew on `coding_task`, once a
// burst of them has settled.
import { answerTask, getTask, stopTask, undoTask } from "../api/client";
import type { FileChange } from "../api/generated/FileChange";
import type { Step } from "../api/generated/Step";
import type { Task } from "../api/generated/Task";
import { asker, checkpointName, lineCounts, SETTLE_MS, stateWord, stepDetail, stepSays, teamName, verdictText, whoName } from "../chat/coding";
import { el, newest, noticeBox, oneAtATime, type View } from "../dom";
import { chatTitle } from "../chat-title";
import { askFirst } from "../dialogs";
import { icon, type IconName } from "../icons";
import { askNode } from "../chat/tool-ask";
import { failureWords } from "../language/errors";
import { clock, dateTime } from "../format";
import { midSentence, wording } from "../language/language";

const SHAPES: Record<Step["state"], IconName> = { running: "play", done: "check", failed: "close", stopped: "stop" };

/** A file's diff, opened in place: its path and the lines. */
const diffOf = (file: FileChange) => el("div", { className: "task-diff flex f-col g-4" }, el("span", { className: "mono" }, file.path), el("pre", { className: "code" }, file.diff));

/** The auditor's verdict under the steps, where there is one. */
function verdictOf(now: Task): HTMLElement | "" {
  if (!now.verdict) return "";
  return el(
    "div",
    { className: "group task-verdict flex f-col g-6" },
    el("span", { className: "item-label" }, now.verdict.passed ? wording("coding-task-verdict-passed") : wording("coding-task-verdict-not-passed")),
    el("span", { className: "meta" }, verdictText(now.verdict)),
    now.verdict.notes ? el("p", { className: "m0" }, now.verdict.notes) : "",
    ...now.verdict.failures.map((failure) => el("div", { className: "task-diff flex f-col g-4" }, el("b", null, failure.name), el("pre", { className: "code" }, failure.output))),
  );
}

/**
 * The right column: the checkpoints, each with Undo (asked first in its line, by `undo`), "Undo all", and the
 * changed files, each opening its diff in place (`opened`, `toggle`).
 */
function sideColumn(
  now: Task,
  undo: (place: HTMLElement, question: string, stepId?: number) => void,
  opened: Set<string>,
  toggle: (key: string) => () => void,
): HTMLElement {
  const running = now.state === "running";
  const checkpoints = now.steps.filter((step) => step.checkpoint && !step.undone).reverse();
  const undoAll = el("button", { type: "button", className: "btn btn-quiet btn-fit", disabled: running || !checkpoints.length }, wording("coding-undo-all"));
  const head = el("div", { className: "gh mb-6" }, el("span", { className: "label" }, wording("coding-task-checkpoints")), undoAll);
  undoAll.onclick = () => undo(head, wording("coding-put-the-folder-back"));
  const points = checkpoints.map((step) => {
    const button = el("button", { type: "button", className: "btn btn-quiet btn-fit", disabled: running }, icon("undo", 16), wording("card-block-undo"));
    const line = el("div", { className: "item item-side-act" }, el("span", { className: "item-text" }, el("span", { className: "medium" }, checkpointName(step.checkpoint!)), el("span", { className: "meta" }, clock(step.started_at))), button);
    button.onclick = () => undo(line, wording("coding-task-put-the-folder-back", { toLowerCase: midSentence(checkpointName(step.checkpoint!)) }), step.id);
    return line;
  });
  const files = now.files.map((file) => {
    const key = `file-${file.path}`;
    const line = el(
      "button",
      { type: "button", className: "item item-side task-file", ariaExpanded: String(opened.has(key)), onclick: toggle(key) },
      el("span", { className: "item-text mono" }, file.path),
      el("span", { className: "meta" }, lineCounts(file.added, file.removed)),
    );
    return opened.has(key) ? el("div", null, line, diffOf(file)) : line;
  });
  return el(
    "aside",
    { className: "task-side flex f-col g-20" },
    el("div", null, head, points.length ? el("div", { className: "group" }, ...points) : el("p", { className: "hint" }, wording("coding-task-none-yet"))),
    el("div", null, el("div", { className: "gh mb-6" }, el("span", { className: "label" }, wording("coding-task-changed-files"))), files.length ? el("div", { className: "group" }, ...files) : el("p", { className: "hint" }, wording("coding-task-none-yet"))),
  );
}

export function codingTaskView(chatId: number, taskId: number): View {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const bar = el("header", { className: "page-head" });
  const body = el("div", { className: "task-page flex f-col g-20" });
  const node = el("section", { className: "main g-20 coding-task" }, bar, notice, body);
  /** The steps and files opened, which stay open as the task is read anew. */
  const opened = new Set<string>();
  const order = newest();
  let task: Task | null = null;
  let waiting: ReturnType<typeof setTimeout> | null = null;

  const toggle = (key: string) => () => {
    if (!opened.delete(key)) opened.add(key);
    draw();
  };
  const undo = (place: HTMLElement, question: string, stepId?: number) =>
    askFirst(place, question, wording("card-block-undo"), () => void attempt(async () => show(await undoTask(taskId, stepId))), draw);

  function stepLine(step: Step): HTMLElement {
    const key = `step-${step.id}`;
    const open = opened.has(key);
    const detail = step.undone ? wording("coding-task-undone", { detail: stepDetail(step.detail) }) : stepDetail(step.detail);
    const line = el(
      "button",
      { type: "button", className: `item ai-s g-12 task-step ${step.state}`, ariaExpanded: String(open), onclick: toggle(key) },
      el("span", { className: "task-step-icon" }, icon(SHAPES[step.state], 16)),
      el("span", { className: "item-text" }, el("span", null, el("b", { className: "semi" }, whoName(step.who)), wording("coding-task-text", { stepSays: stepSays(step) })), detail ? el("span", { className: "meta" }, detail) : ""),
    );
    if (!open) return line;
    return el("div", { className: "task-step-open flex f-col g-8" }, line, step.output ? el("pre", { className: "code" }, step.output) : "", ...step.files.map(diffOf));
  }

  function draw(): void {
    if (!task) return;
    const now = task;
    const running = now.state === "running";
    bar.replaceChildren(
      el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/chats" }, wording("page-chats")), "/", el("a", { href: `#/chats/${chatId}` }, chatTitle(now.chat_title)), "/", el("b", null, wording("page-coding-task"))),
      running ? el("button", { type: "button", className: "btn btn-secondary", onclick: () => void attempt(() => stopTask(taskId)) }, wording("gen-stop")) : "",
    );
    const team = teamName(now.crew.team);
    const head = el(
      "div",
      { className: "task-title flex f-col g-6" },
      el("h1", { className: "m0" }, now.goal),
      el("span", { className: "meta" }, wording("coding-task-team-started", { folder: now.folder, team, format: dateTime(now.started_at) }), el("span", { className: `task-state-word ${now.state}` }, stateWord(now.state))),
      now.error ? el("p", { className: "error m0 c-danger" }, failureWords(now.error)) : "",
    );
    const ask = now.ask ? askNode(now.ask, asker(now), (allow) => answerTask(taskId, allow), (error) => void attempt(() => Promise.reject(error)), false) : "";
    const side = sideColumn(now, undo, opened, toggle);
    body.replaceChildren(
      head,
      ask,
      el(
        "div",
        { className: "task-columns flex g-32 wrap ai-s" },
        el("section", { className: "task-steps minw0" }, el("span", { className: "label" }, wording("coding-task-steps")), el("div", { className: "mt-8" }, ...now.steps.map(stepLine)), verdictOf(now)),
        side,
      ),
    );
  }

  function show(now: Task): void {
    task = now;
    draw();
  }

  const load = () => {
    const mine = order.ask();
    return attempt(async () => {
      const now = await getTask(taskId);
      if (order.take(mine)) show(now);
    });
  };
  void load();
  return {
    node: node,
    onEvent: (event) => {
      // A burst of events is read once.
      if (event.type !== "coding_task" || event.id !== taskId || waiting) return;
      waiting = setTimeout(() => {
        waiting = null;
        void load();
      }, SETTLE_MS);
    },
    onConnected: () => void load(),
  };
}
