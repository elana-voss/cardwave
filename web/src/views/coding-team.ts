// Settings › Tools › "Coding team" (board "Coding team, settings"), at `#/settings/tools/coding`: the team (Quick,
// Balanced, Thorough, Custom) with the line that says what it is, the roles' models (Planner, Workers, Auditor,
// each "Change" opening the model picker of the stored address, with Custom's count of workers and when its
// auditor checks, each the app's select field), and the newest five tasks, each a link to its page. The team
// has no permissions of its own: it goes by Settings › Tools. A model left unset is the chat model's for the planner and the auditor, the background model's for
// the workers (`roleModels`). Every change is the whole team, stored at once (`changeSettings`); one made in another
// window shows at once (the event `settings`).
import { wording } from "../language/language";
import { changeSettings, getProvider, getSettings, recentTasks } from "../api/client";
import type { Audit } from "../api/generated/Audit";
import type { CodingTeam } from "../api/generated/CodingTeam";
import type { ProviderView } from "../api/generated/ProviderView";
import type { TaskLine } from "../api/generated/TaskLine";
import { shape, stateWord, teamSays, teams, verdictText } from "../chat/coding";
import { el, group, noticeBox, oneAtATime, segmented, selectField, type View } from "../dom";
import { day } from "../format";
import { icon } from "../icons";
import { models } from "../models/provider-form";
import { LABELS } from "../setting-labels";

const audits = (): [Audit, string][] => [
  ["end", wording("team-audit-end")],
  ["each_step", wording("team-audit-each")],
  ["never", wording("team-audit-never")],
];

/** The model each role has: its own, else the chat model's (planner, auditor) or the background model's (workers). */
export function roleModels(team: CodingTeam, provider: ProviderView | null): { planner: string; worker: string; auditor: string } {
  const chat = provider?.model ?? "";
  return {
    planner: team.planner_model ?? chat,
    worker: team.worker_model ?? provider?.worker_model ?? chat,
    auditor: team.auditor_model ?? chat,
  };
}

/** What a recent task's line says under its goal: "C:\app · Done · 41 of 42 tests pass · 15 Oct 2026". */
export const taskSays = (task: TaskLine) => [task.folder, stateWord(task.state), task.verdict && verdictText(task.verdict), day(task.started_at)].filter(Boolean).join(" · ");

export function codingTeamView(): View {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const groups = el("div", { className: "page-col" }, notice);
  const node = el(
    "section",
    { className: "main g-24 coding-team" },
    el("header", { className: "page-head" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-coding-team")))),
    groups,
  );
  let team: CodingTeam | null = null;
  let provider: ProviderView | null = null;
  let tasks: TaskLine[] = [];
  const picker = models(node, () => ({ base_url: provider?.base_url ?? "" }), () => {});

  /** Stores the team with `change`, and shows it as the server holds it. */
  const save = (change: Partial<CodingTeam>) =>
    void attempt(async () => {
      team = (await changeSettings({ coding: { ...team!, ...change } })).coding;
      draw();
    });

  const select = <T extends string>(label: string, options: [T, string][], chosen: T, take: (value: T) => void) => {
    const choices = options.map(([value, text]) => ({ value: value as string, label: text }));
    return selectField(choices, chosen, (value) => take(value as T), { ariaLabel: label }).node;
  };

  function draw(): void {
    if (!team) return;
    const now = team;
    const { workers, audit } = shape(now, now.team);
    const custom = now.team === "custom";
    const chosen = roleModels(now, provider);
    const change = (title: string, aria: string, current: string, key: "planner_model" | "worker_model" | "auditor_model") =>
      el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: aria, disabled: !provider, onclick: () => picker.pick(current, title, (id) => save({ [key]: id })) }, wording("team-change"));
    const line = (label: string, says: string, ...controls: HTMLElement[]) =>
      el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), el("span", { className: "meta" }, says)), ...controls);
    const workerLine = line(LABELS.coding.workers, wording("team-workers-of", { workers: String(workers), model: chosen.worker }), change(wording("team-worker-model"), wording("team-change-worker"), chosen.worker, "worker_model"));
    if (custom) workerLine.lastElementChild!.before(select(wording("team-how-many"), [["1", "1"], ["2", "2"], ["3", "3"]], String(workers), (count) => save({ workers: Number(count) })));
    const auditorSays = audit === "never" ? wording("team-none") : audit === "end" ? wording("team-auditor-tests", { model: chosen.auditor }) : wording("team-auditor-steps", { model: chosen.auditor });
    const auditorLine = line(LABELS.coding.auditor, auditorSays, change(wording("team-auditor-model"), wording("team-change-auditor"), chosen.auditor, "auditor_model"));
    if (custom) auditorLine.lastElementChild!.before(select(wording("team-when"), audits(), audit, (when) => save({ audit: when })));
    const recent = tasks.map((task) =>
      el(
        "a",
        { className: "item ink-link", href: `#/chats/${task.chat_id}/tasks/${task.id}` },
        el("span", { className: "item-text" }, el("span", { className: "item-label" }, task.goal), el("span", { className: "meta" }, taskSays(task))),
        el("span", { className: "c-grey flex" }, icon("right")),
      ),
    );
    // Custom begins as the team chosen before it.
    const choose = (which: CodingTeam["team"]) => save(which === "custom" ? { team: which, workers, audit } : { team: which });
    groups.replaceChildren(
      notice,
      el("p", { className: "m0" }, wording("team-intro")),
      group(wording("team-team"), null, segmented(wording("team-team"), teams(), now.team, choose), el("p", { className: "hint mt-8" }, teamSays(now, now.team))),
      group(wording("team-roles"), null, el("div", { className: "group" }, line(LABELS.coding.planner, chosen.planner, change(wording("team-planner-model"), wording("team-change-planner"), chosen.planner, "planner_model")), workerLine, auditorLine)),
      group(wording("team-recent"), null, tasks.length ? el("div", { className: "group" }, ...recent) : el("p", { className: "hint" }, wording("team-no-tasks"))),
    );
  }

  const load = () =>
    attempt(async () => {
      const [settings, stored, recent] = await Promise.all([getSettings(), getProvider(), recentTasks()]);
      [team, provider, tasks] = [settings.coding, stored, recent];
      draw();
    });
  void load();
  return {
    node: node,
    onEvent: (event) => {
      if (event.type === "coding_task" || event.type === "provider" || event.type === "settings") void load();
    },
    onConnected: () => void load(),
  };
}
