// A reply's statistics (board "Chat · a reply's statistics"): the (i) beside a reply's "…" (`statsButton`), there
// only on a reply a model wrote (one with its model kept), and the dialog "Reply statistics" it opens: Model, Response
// time, Context with its bar, and "Sent to the AI" with the prompt's parts (`statLines`, `sentParts`). A line the
// reply has nothing for stays out (a reply written before this was built has no times or provider) (Claude).
import type { MessageView } from "../api/generated/MessageView";
import type { Sent } from "../api/generated/Sent";
import { el } from "../dom";
import { dialog } from "../dialogs";
import { icon } from "../icons";
import { count, decimal } from "../format";
import { wording } from "../language/language";
import { providerName } from "../models/kinds";

/** A line of the dialog: its name, what it says, and for Context how much of the bar is filled, in percent. */
export type StatLine = { name: string; says: string; filled?: number };

/** Seconds, to a tenth: "0.4 s", "12.3 s", the unit the language's (Claude). */
const seconds = (ms: number) => wording("format-seconds", { seconds: decimal(ms / 1000, 1) });

/** The dialog's lines before "Sent to the AI", each only where the reply has it. */
export function statLines(reply: MessageView): StatLine[] {
  const lines: StatLine[] = [];
  if (reply.model) lines.push({ name: wording("stats-model"), says: reply.provider !== null ? `${reply.model} · ${providerName(reply.provider)}` : reply.model });
  const times = reply.times;
  if (times) {
    const all = wording("stats-in-all", { seconds: seconds(times.in_all_ms) });
    lines.push({ name: wording("stats-response-time"), says: times.to_first_word_ms === null ? all : wording("stats-to-the-first-word", { seconds: seconds(times.to_first_word_ms), all }) });
  }
  const context = reply.context;
  if (context && context.size > 0) {
    const free = Math.max(0, context.size - context.used);
    const filled = Math.min(100, (context.used / context.size) * 100);
    lines.push({ name: wording("stats-context"), says: wording("stats-context-says", { used: count(context.used), size: count(context.size), free: count(free) }), filled });
  }
  return lines;
}

/** "Sent to the AI": its five parts by name with their tokens, and their sum. */
export function sentParts(sent: Sent): { total: number; parts: [string, number][] } {
  const parts: [string, number][] = [[wording("page-card"), sent.card], [wording("trash-persona"), sent.persona], [wording("panel-memory"), sent.memory], [wording("page-lorebook"), sent.lorebook], [wording("stats-chat-history"), sent.history]];
  return { total: parts.reduce((sum, [, tokens]) => sum + tokens, 0), parts };
}

/** The (i) that opens the reply's statistics in `home`; none on a message no model wrote. */
export function statsButton(home: HTMLElement, reply: MessageView): HTMLButtonElement | null {
  if (reply.role !== "assistant" || !reply.model) return null;
  return el("button", { type: "button", className: "btn btn-quiet btn-icon stats", ariaLabel: wording("stats-reply-statistics"), title: wording("stats-reply-statistics"), onclick: () => showStats(home, reply) }, icon("info", 16));
}

function showStats(home: HTMLElement, reply: MessageView): void {
  const rows = statLines(reply).map(({ name, says, filled }) => {
    const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, name), el("span", { className: "meta" }, says));
    if (filled === undefined) return el("div", { className: "item" }, text);
    const bar = el("div");
    bar.style.width = `${filled}%`;
    return el("div", { className: "item context f-col ai-st g-6" }, text, el("div", { className: "bar f-none on-box", role: "progressbar", ariaLabel: wording("stats-context-used"), ariaValueNow: String(Math.round(filled)) }, bar));
  });
  if (reply.sent) {
    const { total, parts } = sentParts(reply.sent);
    rows.push(
      el(
        "div",
        { className: "item sent f-col ai-st g-4" },
        el("span", { className: "item-label" }, wording("stats-sent-to-the-ai", { count: count(total) })),
        ...parts.map(([name, tokens]) => el("div", { className: "tok" }, el("span", null, name), el("span", null, count(tokens)))),
      ),
    );
  }
  const close = el("button", { type: "button", className: "btn btn-primary" }, wording("window-close"));
  const box = dialog(home, wording("stats-reply-statistics"), el("div", { className: "group reply-stats" }, ...rows), el("div", { className: "dfoot" }, close));
  close.onclick = () => box.close();
}
