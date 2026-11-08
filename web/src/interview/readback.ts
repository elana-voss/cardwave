// The read-back's list (boards MkReadback, MkNotIt): each line its sentence, what the user said and Keep, Change,
// Remove, That's not it; where the server says no answer holds its words (`guesses`), "the AI's own guess" in their
// place. Remove strikes the line and leaves it there, to be taken back; Change opens a field for the
// user's own sentence, a field left empty keeps the line. A line not yet touched has no pill pressed (`null`) and
// goes as kept.
//
// `askedAgain` is That's not it's question (MkNotIt): its earlier answer in a field, Next and Back; a question answered
// by pills, the kinds always, by its pills (`byPills`), as words would lose the picks (no kind, no needs' branches).
//
// Trap: a press changes the line in place and redraws nothing, so focus and scroll stay.
import type { Entry } from "../api/generated/Entry";
import type { InterviewText } from "../api/generated/InterviewText";
import type { InterviewMove as Move } from "../api/generated/InterviewMove";
import type { ReadBack } from "../api/generated/ReadBack";
import type { ReadBackLine } from "../api/generated/ReadBackLine";
import type { ReadBackVerdict } from "../api/generated/ReadBackVerdict";
import type { Style } from "../api/generated/Style";
import { el, pill } from "../dom";
import { wording } from "../language/language";
import { answerMove, given, type Draft } from "./answers";
import { askBox } from "./ask";

const textOf = (line: ReadBackLine, struck: boolean): HTMLElement =>
  el("p", { className: "m0" }, struck ? el("s", {}, line.sentence) : line.sentence);

/** A line and its four pills. `verdict` is the line's verdict now, which `set` changes. */
function lineOf(args: {
  line: ReadBackLine;
  verdict: ReadBackVerdict | null;
  set: (verdict: ReadBackVerdict | null) => void;
  notIt: (() => void) | null;
  guessed: boolean;
}): HTMLElement {
  const { line, set, notIt } = args;
  let verdict = args.verdict;
  const source = args.guessed ? wording("interview-own-guess") : wording("interview-you-said", { words: line.words });
  const said = [el("p", { className: "rb-said" }, source)];
  const words = el("div", { className: "flex f-col g-2" });
  const field = el("input", { className: "field w100 bb", ariaLabel: wording("interview-own-sentence"), value: typeof verdict === "object" && verdict ? verdict.change : "" });
  const keep = pill(wording("interview-keep"), false, () => take("keep"));
  const change = pill(wording("interview-change"), false, () => {
    take({ change: field.value });
    field.focus();
  });
  const remove = pill(wording("interview-remove"), false, () => take(verdict === "remove" ? null : "remove"));
  const again = el("button", { type: "button", className: "pill", onclick: () => notIt?.() }, wording("interview-not-it"));
  again.disabled = notIt === null;
  if (notIt === null) again.title = wording("interview-not-it-off");
  const pills = el("div", { className: "pillset" }, keep, change, remove, again);
  const node = el("div", { className: "flex f-col g-10" }, words, pills);

  function show(): void {
    const struck = verdict === "remove";
    words.classList.toggle("faded", struck);
    words.replaceChildren(textOf(line, struck), ...said);
    keep.ariaPressed = String(verdict === "keep");
    const changing = typeof verdict === "object" && verdict !== null;
    change.ariaPressed = String(changing);
    remove.ariaPressed = String(struck);
    if (changing) words.after(field);
    else field.remove();
  }
  function take(next: ReadBackVerdict | null): void {
    verdict = next;
    set(next);
    show();
  }
  field.oninput = () => {
    verdict = { change: field.value };
    set(verdict);
  };
  show();
  return node;
}

/** The list. `notIt(line)` asks the line's question again; a line resting on no question has that pill off. */
export function readBackList(args: { back: ReadBack; verdicts: (ReadBackVerdict | null)[]; changed: () => void; notIt: (question: number) => void }): HTMLElement {
  const { back, verdicts, changed, notIt } = args;
  const lines = back.lines.map((line, at) => {
    const question = back.questions[at];
    return lineOf({
      line,
      verdict: verdicts[at],
      set: (verdict) => {
        verdicts[at] = verdict;
        changed();
      },
      notIt: question === null ? null : () => notIt(question),
      guessed: back.guesses[at],
    });
  });
  return el("div", { className: "readback" }, ...lines);
}

/** Whether a question is asked again by its pills, not a field. */
export const byPills = (entry: Entry): boolean => entry.slot === "kinds" || entry.picks.length > 0;

/** The question asked again; `why` is the last try's failure, over its buttons. */
export function askedAgain(args: {
  style: Style;
  entry: Entry;
  draft: Draft;
  kinds: InterviewText[];
  alone: InterviewText[];
  why: string | null;
  changed: (draft: Draft, redraw: boolean) => void;
  next: (move: Move) => void;
  back: () => void;
}): HTMLElement {
  const { style, entry, draft, kinds, alone, why, changed, next, back } = args;
  const backButton = el("button", { type: "button", className: "btn btn-quiet", onclick: back }, wording("interview-back"));
  const told = why === null ? [] : [el("p", { className: "m0 c-danger fs-small", role: "alert" }, why)];
  if (byPills(entry)) {
    const box = askBox({ style, asking: entry, draft, kinds, alone, hint: null, changed, act: next });
    box.querySelector(".ask-acts")?.append(backButton);
    box.querySelector(".ask-acts")?.before(...told);
    return box;
  }
  const go = el("button", { type: "button", className: "btn btn-primary", disabled: !given(draft), onclick: () => next(answerMove(draft)) }, wording("interview-next"));
  const field = el("textarea", { className: "field w100 bb", rows: 4, ariaLabel: wording("interview-your-answer"), placeholder: wording("interview-few-words"), value: draft.free });
  field.oninput = () => {
    draft.free = field.value;
    go.disabled = !given(draft);
    changed(draft, false);
  };
  return el("div", { className: "ask" }, field, ...told, el("div", { className: "ask-acts" }, go, backButton));
}
