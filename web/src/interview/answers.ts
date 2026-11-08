// "Make a character together": what the interview's screen decides, no page in it. A `Draft` is the open question's
// answer while it is given; the engine (crates/cw-library/src/interview.rs) has the rest. How many picks a question
// takes: the kinds two, the "deal" slot three, a question not `multi` one, which a new pick replaces. Picks are the
// server's texts (ids), compared by id and worded by `textWords`. Trap: Cloud's opening is two questions, as it may ask
// the Tree's other two later, with Skip and Back.
import type { Asking } from "../api/generated/Asking";
import type { Entry } from "../api/generated/Entry";
import type { Interview } from "../api/generated/Interview";
import type { InterviewMove as Move } from "../api/generated/InterviewMove";
import type { InterviewText } from "../api/generated/InterviewText";
import type { Style } from "../api/generated/Style";
import { hasText, sameText, textWords } from "../language/interview";
import { comma } from "../format";
import { wording } from "../language/language";

export type Draft = { picks: InterviewText[]; free: string; more: boolean };

const OPENING: Record<Style, string[]> = {
  tree: ["wanted", "relation", "moments", "needs"],
  hybrid: ["wanted", "relation", "moments", "needs"],
  cloud: ["wanted", "relation"],
};

/** Whether the question has "Next" alone: the opening and the kinds. */
export const nextAlone = (style: Style, asking: Asking): boolean => asking.slot === "kinds" || OPENING[style].includes(asking.slot);

/** The answer the open question starts with: the one Back came to, else on the kinds the two that fit best. */
export function draftOf(interview: Interview, kinds: InterviewText[]): Draft {
  const asking = interview.asking;
  const back = interview.ahead[0];
  const same = back !== undefined && back.slot === asking?.slot;
  const picks = same ? back.picks : asking?.slot === "kinds" ? asking.choices.slice(0, 2) : [];
  const more = asking?.slot === "kinds" && picks.some((pick) => !hasText(asking.choices, pick) && hasText(kinds, pick));
  return { picks: [...picks], free: same ? back.free : "", more };
}

/** The most picks the question takes. */
const most = (asking: Asking): number => (asking.slot === "kinds" ? 2 : asking.slot === "deal" ? 3 : asking.multi ? Infinity : 1);

/** The grey line over the pills that says how many the question takes. */
export function howMany(asking: Asking): string {
  const limit = most(asking);
  if (limit === 1) return wording("interview-pick-one");
  if (limit === 2) return wording("interview-pick-two");
  return limit === 3 ? wording("interview-pick-three") : wording("interview-pick-many");
}

/** Whether `pick` cannot be pressed now: the question has as many as it takes, and one more would not replace. */
export function full(asking: Asking, picks: InterviewText[], pick: InterviewText): boolean {
  const limit = most(asking);
  return limit > 1 && picks.length >= limit && !hasText(picks, pick);
}

/** The picks after `pick` was pressed. A pick of `alone` (the server's: "any time" and the like) clears the others,
 * and another pick clears it. */
export function pressed(asking: Asking, picks: InterviewText[], pick: InterviewText, alone: InterviewText[]): InterviewText[] {
  if (hasText(picks, pick)) return picks.filter((one) => !sameText(one, pick));
  if (hasText(alone, pick)) return [pick];
  picks = picks.filter((one) => !hasText(alone, one));
  if (full(asking, picks, pick)) return picks;
  return most(asking) === 1 ? [pick] : [...picks, pick];
}

/** Whether something is given, without which "Next" stays off. */
export const given = (draft: Draft): boolean => draft.picks.length > 0 || draft.free.trim() !== "";

/** The move of a given answer. */
export const answerMove = (draft: Draft): Move => ({ answer: { picks: draft.picks, free: draft.free.trim() } });

/** Whether the move answers the open question, as Back and "Just make it" do not. */
export const answers = (move: Move): boolean => move === "skip" || move === "dont_know" || (typeof move === "object" && "answer" in move);

/** A choice as its pill says it: the engine's words are lower case, as its prompts take them. */
export const pillWords = (choice: string): string => choice.charAt(0).toUpperCase() + choice.slice(1);

/** Picks in a sentence: "Late at night, after a hard day"; only the first has a capital, and "I" always. */
function sentence(picks: InterviewText[], free: string): string {
  const later = (pick: string) => (/^I\b/.test(pick) ? pick : pick.charAt(0).toLowerCase() + pick.slice(1));
  const parts = picks.map(textWords).map((pick, at) => (at === 0 ? pillWords(pick) : later(pick)));
  return [...parts, ...(free ? [free] : [])].join(comma());
}

export type Said = { words: string | null; dontKnow: boolean };

/** An answer in the thread; `null` words are Skip or "I don't know", which stand in grey. */
export function saidOf(entry: Pick<Entry, "picks" | "free" | "skipped" | "dont_know">): Said {
  if (entry.skipped || entry.dont_know) return { words: null, dontKnow: entry.dont_know };
  return { words: sentence(entry.picks, entry.free), dontKnow: false };
}

/** What a move would write in the thread, while its step is on its way or failed; none for one that answers nothing. */
export function saidBy(move: Move): Said | null {
  if (move === "skip") return { words: null, dontKnow: false };
  if (move === "dont_know") return { words: null, dontKnow: true };
  if (typeof move !== "object") return null;
  if ("answer" in move) return { words: sentence(move.answer.picks, move.answer.free), dontKnow: false };
  return saidBy(move.end_after);
}

/** What "Just make it" sends after `move` failed: its answer is kept. */
export function endAfter(move: Move): Move {
  if (answers(move)) return { end_after: move };
  return typeof move === "object" && "end_after" in move ? move : "just_make_it";
}
