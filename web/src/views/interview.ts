// "Make a character together" (boards MkOpen … MkFailed), at `#/interview`: one page whose content changes, the
// conversation in one column: each question asked with its answer, then the open question and `askBox`. A move goes
// to the server with the whole state (`stepInterview`), which keeps nothing: while it runs the answer stands in the
// thread with the chat's three dots (MkWait); a failure stands in red where the next question would be, with
// Try again and Just make it (MkFailed), the answers kept; failing again after Try again it names Settings › Providers.
//
// The interview and the open answer are one unsaved field, `interview` (unsaved.ts), kept at each change and
// brought back when the page shows, unless the style changed in the settings. Leaving the page hangs up, which
// stops the model. `asking` null: the read-back comes (MkReading, MkReadback), and under it the private list and the
// writing, which end on the new character's page with "Add to your persona?"; once written the field is forgotten.
//
// Trap: past the thread the read-back stands in `holder`, which `paint` alone repaints: `draw`'s scroll would jump.
import { ApiError, correctInterview, getInterview, readBackInterview, stepInterview, writeInterview } from "../api/client";
import type { Interview } from "../api/generated/Interview";
import type { InterviewText } from "../api/generated/InterviewText";
import type { InterviewMove as Move } from "../api/generated/InterviewMove";
import type { OtherModel } from "../api/generated/OtherModel";
import type { ReadBack } from "../api/generated/ReadBack";
import type { ReadBackVerdict } from "../api/generated/ReadBackVerdict";
import { el, failure, reason, typingDots, type View } from "../dom";
import { draftOf, endAfter, saidBy, saidOf, type Draft, type Said } from "../interview/answers";
import { askBox } from "../interview/ask";
import { offerPersona } from "../interview/persona";
import { closedLine, closedPrivate, privateBox, privateSent, type PrivateState } from "../interview/private-list";
import { askedAgain, byPills, readBackList } from "../interview/readback";
import { declinedRow, writeRow, writingRow } from "../interview/writing";
import { hasText, textWords } from "../language/interview";
import { wording } from "../language/language";
import { pageTitle } from "../library/list-screen";
import { forget, keep, kept } from "../unsaved";

const FIELD = "interview";

/** The read-back as it stands: its lines, what the user did with them, the private list, and a question asked again. */
type Reading = { back: ReadBack; verdicts: (ReadBackVerdict | null)[]; private: PrivateState; again: { question: number; draft: Draft } | null };
type Kept = { interview: Interview; draft: Draft; reading?: Reading | null };
/** What stands where "Write the character" does: the writing's stop, a failure, a refusal. */
type Problem = { failed: string } | { declined: string };

const question = (words: string) => el("div", { className: "msg" }, el("div", { className: "bubble-row" }, el("div", { className: "bubble" }, el("p", {}, words))));

/** The user's answer in the thread; Skip and "I don't know" in grey. */
function answer(said: Said): HTMLElement {
  const grey = said.words === null;
  const words = said.words ?? (said.dontKnow ? wording("interview-dont-know") : wording("interview-skip"));
  const bubble = el("div", { className: grey ? "bubble c-grey" : "bubble" }, el("p", {}, words));
  return el("div", { className: "msg me" }, el("div", { className: "bubble-row jc-e" }, bubble));
}

/** The three dots of the app's next message. */
function waiting(label = wording("interview-writing-next")): HTMLElement {
  return el("div", { className: "msg" }, el("div", { className: "bubble-row" }, el("div", { className: "bubble" }, typingDots(label))));
}

/** The kept interview, where it can be read and is of `fresh`'s style. */
function keptOf(text: string | null, fresh: Interview): Kept | null {
  if (!text) return null;
  try {
    const parsed = JSON.parse(text) as Kept;
    // A kept interview from before the seed cannot draw what the card needs, nor one from before its texts went as
    // ids (each an English string) be worded: either starts anew.
    const { interview } = parsed;
    const texts = [...interview.log, ...(interview.asking ? [interview.asking] : [])].map((one) => one.question as unknown);
    const worded = texts.every((text) => typeof text === "object" && text !== null);
    return interview.style === fresh.style && interview.seed && worded ? parsed : null;
  } catch {
    return null; // An unreadable field is as none: the interview starts anew.
  }
}

export function interviewView(): View {
  const thread = el("div", { className: "interview" });
  let now: Interview | null = null;
  let draft: Draft = { picks: [], free: "", more: false };
  let kinds: InterviewText[] = [];
  let alone: InterviewText[] = [];
  let hint = "";
  let sending: AbortController | null = null;
  let topics: InterviewText[] = [];
  let reading: Reading | null = null;
  const holder = el("div", { className: "flex f-col g-22" });
  let writing = false;
  let problem: Problem | null = null;
  let tried: OtherModel | null = null;

  /** The questions answered, and the open one's words. */
  function asked(): HTMLElement[] {
    if (!now) return [];
    const lines = now.log.flatMap((entry) => [question(textWords(entry.question)), answer(saidOf(entry))]);
    return now.asking ? [...lines, question(textWords(now.asking.question))] : lines;
  }

  function changed(next: Draft, redraw: boolean): void {
    draft = next;
    store();
    if (redraw) draw();
  }

  function store(): void {
    if (now) keep(FIELD, JSON.stringify({ interview: now, draft, reading }));
  }

  function draw(): void {
    if (!now) return;
    if (!now.asking) {
      if (reading) showReading();
      else void askReadBack();
      return;
    }
    const lines = asked();
    if (now.asking) {
      const first = now.log.length === 0 ? hint : null;
      lines.push(askBox({ style: now.style, asking: now.asking, draft, kinds, alone, hint: first, changed, act: (move) => void send(move) }));
    }
    thread.replaceChildren(...lines);
    thread.lastElementChild?.scrollIntoView({ block: "nearest" });
  }

  /** The thread with `move`'s answer and what stands under it. */
  function under(move: Move, last: HTMLElement): void {
    const said = saidBy(move);
    thread.replaceChildren(...asked(), ...(said ? [answer(said)] : []), last);
    last.scrollIntoView({ block: "nearest" });
  }

  /** A failure in a row after another: the grey line says where the AI is set. */
  function failed(move: Move, why: string, again: boolean): void {
    const acts = el(
      "div",
      { className: "ask-acts" },
      el("button", { type: "button", className: "btn btn-secondary", onclick: () => void send(move, true) }, wording("interview-try-again")),
      el("button", { type: "button", className: "btn btn-quiet", onclick: () => void send(endAfter(move)) }, wording("interview-just-make-it")),
    );
    const where = again ? [el("p", { className: "hint" }, wording("interview-failed-where"))] : [];
    under(move, el("div", { className: "flex f-col g-10" }, el("p", { className: "m0 c-danger fs-small", role: "alert" }, why), ...where, acts));
  }

  async function send(move: Move, retry = false): Promise<void> {
    if (!now) return;
    sending = new AbortController();
    const mine = sending;
    under(move, waiting());
    try {
      now = await stepInterview(now, move, mine.signal);
      draft = draftOf(now, kinds);
      store();
      draw();
    } catch (error) {
      if (!mine.signal.aborted) failed(move, reason(error), retry);
    }
  }

  /** The read-back's first coming: the dots, then the lines; a failure has Try again. */
  async function askReadBack(): Promise<void> {
    if (!now) return;
    sending = new AbortController();
    const mine = sending;
    const dots = waiting(wording("interview-reading"));
    thread.replaceChildren(...asked(), dots);
    dots.scrollIntoView({ block: "nearest" });
    try {
      const back = await readBackInterview(now, mine.signal);
      reading = { back, verdicts: back.lines.map(() => null), private: closedPrivate(topics), again: null };
      store();
      showReading();
    } catch (error) {
      if (mine.signal.aborted) return;
      const again = el("button", { type: "button", className: "btn btn-secondary", onclick: () => void askReadBack() }, wording("interview-try-again"));
      const row = el("div", { className: "flex f-col g-10" }, el("p", { className: "m0 c-danger fs-small", role: "alert" }, reason(error)), el("div", { className: "ask-acts" }, again));
      thread.replaceChildren(...asked(), row);
    }
  }

  function showReading(): void {
    const message = question(wording("interview-understood"));
    thread.replaceChildren(...asked(), message, holder);
    paint();
    message.scrollIntoView({ block: "start" });
  }

  /** The read-back's list. */
  function listOf(state: Reading): HTMLElement {
    return readBackList({
      back: state.back,
      verdicts: state.verdicts,
      changed: store,
      notIt: (at) => {
        const entry = now?.log[at];
        if (!entry) return;
        problem = null;
        const words = saidOf(entry).words ?? "";
        const more = entry.slot === "kinds" && entry.picks.some((pick) => !hasText(entry.choices, pick));
        state.again = { question: at, draft: byPills(entry) ? { picks: [...entry.picks], free: entry.free, more } : { picks: [], free: words, more: false } };
        store();
        paint();
        holder.lastElementChild?.scrollIntoView({ block: "nearest" });
      },
    });
  }

  const greyed = (className: string, ...parts: HTMLElement[]) => el("div", { className, ariaDisabled: "true", inert: true }, ...parts);

  function closedOrOpen(state: Reading): HTMLElement {
    if (!state.private.open) {
      return closedLine(() => {
        state.private.open = true;
        store();
        paint();
        holder.querySelector<HTMLElement>("section button")?.focus();
      });
    }
    const repaint = (whole: boolean) => {
      store();
      if (!whole) return;
      paint();
      holder.querySelector<HTMLElement>(".private-line")?.focus();
    };
    return privateBox({ state: state.private, changed: repaint });
  }

  function paint(): void {
    if (!now || !reading) return;
    const state = reading;
    if (state.again) {
      holder.replaceChildren(greyed("faded", listOf(state)), ...againParts(state, state.again));
      return;
    }
    if (writing) {
      const stop = () => sending?.abort();
      holder.replaceChildren(greyed("faded flex f-col g-22", listOf(state), closedOrOpen(state)), writingRow(stop));
      return;
    }
    const foot =
      problem && "declined" in problem
        ? declinedRow({
            why: problem.declined,
            tried,
            pick: (model) => void write(model),
            without: () => {
              problem = null;
              state.private.open = true;
              store();
              paint();
              holder.querySelector("section")?.scrollIntoView({ block: "start" });
            },
          })
        : writeRow(problem ? problem.failed : null, () => void write(problem ? tried : null));
    holder.replaceChildren(listOf(state), closedOrOpen(state), foot);
  }

  /** "That's not it": the question under the greyed list, with the answer it had. */
  function againParts(state: Reading, again: { question: number; draft: Draft }): HTMLElement[] {
    const entry = now?.log[again.question];
    if (!entry || !now) return [];
    const box = askedAgain({
      style: now.style,
      entry,
      draft: again.draft,
      kinds,
      alone,
      why: problem && "failed" in problem ? problem.failed : null,
      changed: (next, redraw) => {
        again.draft = next;
        store();
        if (redraw) paint();
      },
      next: (move) => void redo(state, again.question, move),
      back: () => {
        problem = null;
        state.again = null;
        store();
        paint();
      },
    });
    return [question(textWords(entry.question)), box];
  }

  /** Sends the new answer: its bubble and the dots, then a new list, which replaces the old and its choices. */
  async function redo(state: Reading, at: number, action: Move): Promise<void> {
    if (!now) return;
    const entry = now.log[at];
    sending = new AbortController();
    const mine = sending;
    problem = null;
    const said = saidBy(action);
    const dots = waiting(wording("interview-reading"));
    holder.replaceChildren(greyed("faded", listOf(state)), question(textWords(entry.question)), ...(said ? [answer(said)] : []), dots);
    dots.scrollIntoView({ block: "nearest" });
    try {
      const made = await correctInterview({ interview: now, question: at, action }, mine.signal);
      now = made.interview;
      reading = { back: made.read_back, verdicts: made.read_back.lines.map(() => null), private: state.private, again: null };
      store();
      showReading();
    } catch (error) {
      if (mine.signal.aborted) return;
      problem = { failed: reason(error) };
      paint();
    }
  }

  /** Writes the character; `model` is another than the chat model, for this writing alone. */
  async function write(model: OtherModel | null): Promise<void> {
    if (!now || !reading) return;
    sending = new AbortController();
    const mine = sending;
    writing = true;
    problem = null;
    tried = model;
    paint();
    try {
      const made = await writeInterview(
        { interview: now, lines: reading.back.lines, verdicts: reading.verdicts.map((verdict) => verdict ?? "keep"), private: privateSent(reading.private), other_model: model },
        mine.signal,
      );
      forget(FIELD);
      location.hash = `#/library/${made.card_id}`;
      void offerPersona(made.persona);
    } catch (error) {
      writing = false;
      if (!mine.signal.aborted) {
        problem = error instanceof ApiError && error.code === "model_declined" ? { declined: reason(error) } : { failed: reason(error) };
      }
      paint();
    }
  }

  void (async () => {
    try {
      const [start, text] = await Promise.all([getInterview(), kept(FIELD)]);
      kinds = start.kinds;
      alone = start.alone;
      topics = start.topics;
      hint = start.goes_to === null ? wording("interview-stays") : wording("interview-goes-to", { provider: start.goes_to });
      const back = keptOf(text, start.interview);
      now = back?.interview ?? start.interview;
      draft = back?.draft ?? draftOf(now, kinds);
      reading = back?.reading ?? null;
      draw();
    } catch (error) {
      thread.replaceChildren(failure(reason(error)));
    }
  })();

  const node = el(
    "section",
    { className: "main main-form rel" },
    el("header", { className: "pbar" }, pageTitle(wording("page-interview"))),
    el("div", { className: "page-col mt-12" }, thread),
  );
  return { node, left: () => sending?.abort() };
}
