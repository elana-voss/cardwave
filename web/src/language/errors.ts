// The UI's words for the server's error answers: `errorWords` says one in the language in use from its code and
// details (en.errors.ftl, `error-<code>` with "-" for "_"), never from its `error`, the server's English sentence
// for a developer or a model. The build fails on a code of api/generated/Code.ts without words (keys.ts).
// Traps: the key is put together from the code, so this module lives here, where the key check does not look; a
// detail a text picks its words by (`what`, `action`, `said`) is passed as a Fluent name, its spaces as "_"; an answer
// without a code (not the server's, such as a proxy's) is worded by its status.
import type { Code } from "../api/generated/Code";
import type { ErrorBody } from "../api/generated/ErrorBody";
import { type Args, hasWords, wording } from "./language";

/** An error answer's body as it may come: the server's, or anything else. */
export type Answered = Partial<ErrorBody> | null;

/** The key of a code's words. */
export const keyOf = (code: Code | string) => `error-${code.replaceAll("_", "-")}`;

/** A provider's own text closed with a full stop where it lacks an end mark, as a sentence of the app's may follow it. */
const closed = (text: string) => (!text.trim() || /[.!?。！？…]["'”»)]*$/u.test(text.trim()) ? text.trim() : `${text.trim()}.`);

/** What the user is told of an error answer of `status` with `body`. */
export function errorWords(status: number, body: Answered): string {
  const known = typeof body?.code === "string" && hasWords(keyOf(body.code));
  const code = known ? body!.code! : status >= 500 ? "internal" : "request_failed";
  const args: Args = {};
  for (const [name, value] of Object.entries((known && body!.details) || {})) {
    if (value === undefined) continue;
    args[name] = name === "what" || name === "action" || name === "said" ? String(value).replaceAll(" ", "_") : name === "reason" ? closed(String(value)) : value;
  }
  // What a provider's list said of the key or address is told as such, not as an answer to try again.
  if (code === "answered" && args.said !== undefined) return wording("error-answered-said", args);
  return wording(keyOf(code), args);
}

/** What the user is told of a failure an event or a task tells (a reply's, a coding task's), which has no status. */
export const failureWords = (body: ErrorBody) => errorWords(400, body);

/** The words of a status's failure (a download's, a list's), where it has one. */
export const failedWords = (body: ErrorBody | null | undefined) => (body ? failureWords(body) : null);
