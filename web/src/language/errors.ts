// The UI's words for the server's error answers: `errorWords` says one in the language in use from its code and
// details (en.errors.ftl, `error-<code>` with "-" for "_"), never from its `error`, the server's English sentence
// for a developer or a model. The build fails on a code of api/generated/Code.ts without words (keys.ts).
// Traps: the key is put together from the code, so this module lives here, where the key check does not look; a
// detail a text picks its words by (`what`, `action`, `said`) comes from the server as a Fluent name; an answer
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

/** Whether an answer's code has words of its own. */
const known = (body: Answered) => typeof body?.code === "string" && hasWords(keyOf(body.code));

/** The code whose words tell an error answer of `status` with `body`: its own where it has words, else by the status. */
export const spokenCode = (status: number, body: Answered): string => (known(body) ? body!.code! : status >= 500 ? "internal" : "request_failed");

/** What the user is told of an error answer of `status` with `body`. */
export function errorWords(status: number, body: Answered): string {
  const code = spokenCode(status, body);
  const args: Args = {};
  for (const [name, value] of Object.entries((known(body) && body!.details) || {})) {
    if (value === undefined) continue;
    args[name] = name === "reason" ? closed(String(value)) : value;
  }
  // What a provider's list said of the key or address is told as such, not as an answer to try again.
  if (code === "answered" && args.said !== undefined) return wording("error-answered-said", args);
  return wording(keyOf(code), args);
}

/** What the user is told of a failure an event or a task tells (a reply's, a coding task's), which has no status. */
export const failureWords = (body: ErrorBody) => errorWords(400, body);

/** The words of a status's failure (a download's, a list's), where it has one. */
export const failedWords = (body: ErrorBody | null | undefined) => (body ? failureWords(body) : null);
