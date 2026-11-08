// The read-back's private list (boards MkPrivate, MkPrivateN): closed, a line under the read-back; open in its place,
// a row of five answers per topic, "Never" beside a No (three at most), a free line and Skip all, which closes it with
// nothing kept. What is sent leaves out the rows of "Don't know", and all of it while closed. A topic is the server's
// id, worded by `textWords`, and goes back as that id.
//
// Trap: a press changes the row in place and redraws nothing, so the focus stays on what was pressed; only opening
// and Skip all ask the page to repaint, through `changed`.
import type { InterviewPrivate } from "../api/generated/InterviewPrivate";
import type { InterviewText } from "../api/generated/InterviewText";
import { el, segmented } from "../dom";
import { icon } from "../icons";
import { textWords } from "../language/interview";
import { wording } from "../language/language";
import { pillWords } from "./answers";

const UNKNOWN = "don't know";
const MOST_NEVER = 3;
const answers = (): [string, string][] => [
  ["yes", wording("interview-yes")],
  ["no", wording("interview-no")],
  ["maybe", wording("interview-maybe")],
  ["fantasy only", wording("interview-fantasy-only")],
  [UNKNOWN, wording("interview-dont-know")],
];

export type PrivateRow = { topic: InterviewText; answer: string; never: boolean };
export type PrivateState = { open: boolean; rows: PrivateRow[]; free: string };

/** The list closed, every row at "Don't know". */
export const closedPrivate = (topics: InterviewText[]): PrivateState => ({
  open: false,
  rows: topics.map((topic) => ({ topic, answer: UNKNOWN, never: false })),
  free: "",
});

/** The same list open. */
export const opened = (state: PrivateState): PrivateState => {
  state.open = true;
  return state;
};

/** What goes to the server. */
export function privateSent(state: PrivateState): InterviewPrivate {
  if (!state.open) return { open: false, rows: [], free: "" };
  return { open: true, rows: state.rows.filter((row) => row.answer !== UNKNOWN).map((row) => ({ ...row })), free: state.free.trim() };
}

/** The closed line. */
export function closedLine(press: () => void): HTMLElement {
  const label = el("span", { className: "item-text" }, el("span", { className: "item-label" }, wording("interview-private-line")), el("span", { className: "meta" }, wording("interview-private-sub")));
  const line = el("button", { type: "button", className: "item w100 bb ink-link private-line plain-button", ariaExpanded: "false", onclick: press }, label, el("span", { className: "c-grey flex" }, icon("down", 16)));
  return el("div", { className: "group" }, line);
}

/** The open list. `changed` tells of a change, with `true` where the page is to repaint. */
export function privateBox(args: { state: PrivateState; changed: (repaint: boolean) => void }): HTMLElement {
  const { state, changed } = args;
  const refresh: (() => void)[] = [];
  const tell = () => {
    refresh.forEach((one) => one());
    changed(false);
  };
  const rows = state.rows.map((row) => {
    const tick = el("input", { type: "checkbox", checked: row.never });
    tick.onchange = () => {
      row.never = tick.checked;
      tell();
    };
    const never = el("label", { className: "flex ai-c g-6 fs-small" }, tick, wording("interview-never"));
    const seg = segmented(textWords(row.topic), answers(), row.answer, (answer) => {
      row.answer = answer;
      if (answer !== "no") row.never = false;
      tell();
    });
    const line = el("div", { className: "flex ai-c g-12 wrap" }, seg);
    refresh.push(() => {
      tick.checked = row.never;
      tick.disabled = !row.never && state.rows.filter((one) => one.never).length >= MOST_NEVER;
      if (row.answer === "no") line.append(never);
      else never.remove();
    });
    return el("div", { className: "fld" }, el("span", { className: "label" }, pillWords(textWords(row.topic))), line);
  });
  refresh.forEach((one) => one());
  const free = el("input", { className: "field", ariaLabel: wording("interview-private-free"), value: state.free });
  free.oninput = () => {
    state.free = free.value;
    changed(false);
  };
  const skip = () => {
    Object.assign(state, closedPrivate(state.rows.map((row) => row.topic)));
    changed(true);
  };
  return el(
    "section",
    { className: "flex f-col g-16" },
    el("div", { className: "gh m0" }, el("h2", {}, wording("interview-private-line")), el("button", { type: "button", className: "btn btn-quiet", onclick: skip }, wording("interview-skip-all"))),
    el("p", { className: "hint" }, wording("interview-private-hint")),
    el("div", { className: "flex f-col g-16" }, ...rows, el("div", { className: "fld" }, el("span", { className: "label" }, wording("interview-private-free")), free)),
  );
}
