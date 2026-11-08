// The UI's words for the interview's texts: the server sends each fixed question and choice as an id
// (crates/cw-library/src/interview/shown.rs) and `textWords` says it in the language in use (en.interview.ftl,
// `interview-<id>`), a model's words as they came. `sameText` compares texts by id, never by words. The build fails
// on an id of api/generated/InterviewTextId.ts without words (keys.ts `idsMissing`).
// Traps: the key is put together from the id, so this module lives here, where the key check does not look; the
// probe and the "why" question quote an answer, `said`, whose parts are worded each and joined by "; " as the
// engine joins them.
import type { InterviewText } from "../api/generated/InterviewText";
import { wording } from "./language";

/** The key of an id's words. */
export const keyOfText = (id: string) => `interview-${id}`;

/** How a need stored by its name (`keep_company`, cw-library needs.rs `LIST`) finishes "I need…", as the interview asks it. */
export const needWords = (need: string) => wording(keyOfText(`need-${need.replaceAll("_", "-")}`));

/** What the page shows of `text`. */
export function textWords(text: InterviewText): string {
  if ("words" in text) return text.words;
  return wording(keyOfText(text.id), { said: text.said.map(textWords).join("; ") });
}

/** Whether `a` and `b` are the same text. */
export function sameText(a: InterviewText, b: InterviewText): boolean {
  if ("words" in a || "words" in b) return "words" in a && "words" in b && a.words === b.words;
  return a.id === b.id && a.said.length === b.said.length && a.said.every((part, at) => sameText(part, b.said[at]));
}

/** Whether `list` holds `text`. */
export const hasText = (list: readonly InterviewText[], text: InterviewText): boolean => list.some((one) => sameText(one, text));
