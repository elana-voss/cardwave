// "Make a character together": the open question's answer under it (boards MkOpen, MkWhat, MkWant, MkKinds, MkAskPills,
// MkAskFree): pills under a grey line saying how many it takes and a free line, or a free field that grows; on the kinds pills alone and "More"; then "Next" and, past the
// opening and the kinds, Skip, "I don't know", Back and "Just make it". `answers.ts` decides what a press means.
//
// Traps: typing changes the draft and Next's `disabled` and redraws nothing, so the field keeps its focus and caret;
// a pill or More asks for a redraw through `changed`. "Just make it" keeps what is given as the last answer (Claude).
import type { Asking } from "../api/generated/Asking";
import type { InterviewText } from "../api/generated/InterviewText";
import type { InterviewMove as Move } from "../api/generated/InterviewMove";
import type { Style } from "../api/generated/Style";
import { el, pill } from "../dom";
import { hasText, textWords } from "../language/interview";
import { wording } from "../language/language";
import { answerMove, full, given, howMany, nextAlone, pillWords, pressed, type Draft } from "./answers";

/** A quiet button of the row. */
const quiet = (label: string, press: () => void, end = false) =>
  el("button", { type: "button", className: end ? "btn btn-quiet end" : "btn btn-quiet", onclick: press }, label);

/** The box under the question. `hint` is the grey line of the first question; `alone` the picks that stand alone. */
export function askBox(args: {
  style: Style;
  asking: Asking;
  draft: Draft;
  kinds: InterviewText[];
  alone: InterviewText[];
  hint: string | null;
  changed: (draft: Draft, redraw: boolean) => void;
  act: (move: Move) => void;
}): HTMLElement {
  const { style, asking, draft, kinds, alone, hint, changed, act } = args;
  const next = el("button", { type: "button", className: "btn btn-primary", disabled: !given(draft), onclick: () => act(answerMove(draft)) }, wording("interview-next"));
  const typed = (free: string) => {
    draft.free = free;
    next.disabled = !given(draft);
    changed(draft, false);
  };
  const isKinds = asking.slot === "kinds";
  const shown = isKinds && draft.more ? [...asking.choices, ...kinds.filter((kind) => !hasText(asking.choices, kind))] : asking.choices;
  const body: HTMLElement[] = [];
  if (shown.length > 0) {
    const pills = shown.map((choice) => {
      const button = pill(pillWords(textWords(choice)), hasText(draft.picks, choice), () => {
        draft.picks = pressed(asking, draft.picks, choice, alone);
        changed(draft, true);
      });
      button.disabled = full(asking, draft.picks, choice);
      return button;
    });
    if (asking.slot === "needs") body.push(el("p", { className: "hint" }, wording("interview-needs-hint")));
    body.push(el("p", { className: "hint" }, howMany(asking)), el("div", { className: "pillset" }, ...pills));
    if (isKinds && !draft.more) {
      const open = () => {
        draft.more = true;
        changed(draft, true);
      };
      body.push(el("div", {}, quiet(wording("interview-more"), open)));
    }
    if (!isKinds && asking.slot !== "treat") {
      const line = el("input", { className: "field w100 bb", placeholder: wording("interview-own-words"), ariaLabel: wording("interview-in-own-words"), value: draft.free });
      line.oninput = () => typed(line.value);
      body.push(line);
    }
  } else {
    const field = el("textarea", { className: "field w100 bb", rows: 4, ariaLabel: wording("interview-your-answer"), placeholder: asking.slot === "wanted" ? wording("interview-wanted-hint") : wording("interview-few-words"), value: draft.free });
    field.oninput = () => typed(field.value);
    body.push(field);
  }
  if (hint) body.push(el("p", { className: "hint" }, hint));
  const acts: HTMLElement[] = [next];
  if (!nextAlone(style, asking)) {
    acts.push(
      quiet(wording("interview-skip"), () => act("skip")),
      quiet(wording("interview-dont-know"), () => act("dont_know")),
      quiet(wording("interview-back"), () => act("back")),
      quiet(wording("interview-just-make-it"), () => act(given(draft) ? { end_after: answerMove(draft) } : "just_make_it"), true),
    );
  }
  return el("div", { className: "ask" }, ...body, el("div", { className: "ask-acts" }, ...acts));
}
