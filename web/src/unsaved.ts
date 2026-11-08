// Unsaved edits: what is typed in a field and not saved yet is kept on the server per field (`keep`), so that a
// window closed takes nothing with it, and is brought back when the field shows again (`kept`); a field saved or
// let go forgets it (`forget`). A field is named by its screen: `chat.<id>` (the message field), `message.<id>` (a
// message being edited), `card.<id>.<language>.<text>` and `lorebook.<book>.<entry>` (a text written where it
// stands, card-block.ts), `interview` (the interview, whole, views/interview.ts).
//
// Traps: what is typed is sent a moment after the typing stops (`WAIT`), and at once as the page is hidden or
// closed; a field's requests go one after the other (`queue`), so a text sent late never comes back over a
// forgetting. Whoever brings a text back puts it into the field only while the user has not typed there.
import { getUnsaved, keepUnsaved } from "./api/client";

/** How long after the last letter typed the text is sent. */
const WAIT = 400;

/** Texts typed and not sent yet, by field. */
const waiting = new Map<string, { text: string; timer: number }>();
/** Each field's newest request, which the next waits for. */
const queue = new Map<string, Promise<void>>();

/** Sends `text` as the field's unsaved text after the field's requests before it; a failure only loses it. */
function put(field: string, text: string, closing = false): void {
  const after = (queue.get(field) ?? Promise.resolve()).then(() => keepUnsaved(field, text, closing).catch(() => {}));
  queue.set(field, after);
  void after.then(() => {
    if (queue.get(field) === after) queue.delete(field);
  });
}

/** Sends what waits for the field now. */
function flush(field: string, closing = false): void {
  const typed = waiting.get(field);
  if (!typed) return;
  clearTimeout(typed.timer);
  waiting.delete(field);
  put(field, typed.text, closing);
}

/** Keeps `text` as what the field holds unsaved; an empty text is none. */
export function keep(field: string, text: string): void {
  clearTimeout(waiting.get(field)?.timer);
  waiting.set(field, { text, timer: window.setTimeout(() => flush(field), WAIT) });
}

/** The field was saved or let go: nothing of it is unsaved. */
export function forget(field: string): void {
  clearTimeout(waiting.get(field)?.timer);
  waiting.delete(field);
  put(field, "");
}

/** The field's unsaved text, after what is on its way for it; null where there is none, or it cannot be read. */
export async function kept(field: string): Promise<string | null> {
  flush(field);
  await queue.get(field);
  return getUnsaved(field)
    .then((unsaved) => unsaved?.text || null)
    .catch(() => null);
}

// A window closed or hidden sends what was typed.
addEventListener("pagehide", () => {
  for (const field of [...waiting.keys()]) flush(field, true);
});
