// How a reply's writing ended, told in a grey line under its message in the chat and the companion, from what
// the message keeps (`MessageView.ending`): broken off by the app's close, or cut off at the model's own length
// limit. A whole reply, and one still being written, has none. Its words are the errors' (`reply_broke_off`,
// `reply_cut_off`), so the line says what a failure notice would.
import type { MessageView } from "./api/generated/MessageView";
import { el } from "./dom";
import { failureWords } from "./language/errors";

/** The errors' word for each ending that is told; a whole one has none. */
const TOLD: Partial<Record<MessageView["ending"], string>> = { broke_off: "reply_broke_off", cut_off: "reply_cut_off" };

/** The line under a finished reply that did not end whole, with `className`, if any, beside `hint`; else null. */
export function endingLine(message: MessageView, className?: string): HTMLElement | null {
  const what = message.complete ? TOLD[message.ending] : undefined;
  if (!what) return null;
  return el("p", { className: className ? `hint reply-ending ${className}` : "hint reply-ending" }, failureWords({ code: "model_answer", error: "", details: { what } }));
}
