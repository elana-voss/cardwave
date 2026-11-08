// What the chat screen does with the server's events: a reply streaming in, the model's thinking before it (one
// grey line, `showThinking`, gone with the first word), its end, a tool's call that waits,
// a coding task, what was saved to memory, the chat's mode and its title, lorebooks, personas or the voice changed, a
// message sent, deleted or put back, the chat changed or a written tool switched in another window, and "Pictures
// from the web" switched in Settings.
//
// Traps: events that come while the chat is read wait (`held`); a piece of a reply that does not fit what is
// known has the chat read anew (`streamed`), which also finds a reply's end missed while the socket was down.
import type { ServerEvent } from "../api/generated/ServerEvent";
import { getVoice } from "../api/client";
import { failureWords } from "../language/errors";
import { startDialog } from "./coding";
import { narrated, readWebPictures } from "../narration";
import { atBottom, failed, filesNow, find, load, personalityNow, show, tell, toBottom, toolsNow, type Screen } from "./screen";
import { showThinking } from "./messages";
import { end } from "./talk";

/** Events that say nothing to a chat. */
const IGNORED_TYPES = ["hello", "account", "presets", "descriptions", "search", "documents", "restored", "card", "card_folder", "trash", "local_models", "dictation", "companion_act"] as const satisfies readonly ServerEvent["type"][];
type Ignored = (typeof IGNORED_TYPES)[number];
const IGNORED = new Set<string>(IGNORED_TYPES);
const ignored = (event: ServerEvent): event is Extract<ServerEvent, { type: Ignored }> => IGNORED.has(event.type);

/** Draws the screen once `done` is read, or tells why it could not be. */
const redraw = (s: Screen, done: Promise<unknown>): void => void done.then(s.render, (error: unknown) => tell(s, error));

/** Reads the chat anew, or after the reading on its way where one is, as that may be of before the event. */
function again(s: Screen, event: ServerEvent): void {
  if (s.loading) s.held.push(event);
  else void load(s);
}

export function onEvent(s: Screen, event: ServerEvent): void {
  // The voice may have gone to a provider, or come back.
  if (event.type === "voice" || event.type === "provider") {
    if (event.type === "provider") redraw(s, toolsNow(s));
    getVoice().then((now) => {
      s.voice = now;
      s.render();
    }, () => {});
    return;
  }
  // Settings changed in another window: "Show pictures from other websites" may have, and the tools or the model, by which
  // the side panel tells whether Reply length is used.
  if (event.type === "settings") return redraw(s, Promise.all([readWebPictures(), toolsNow(s), filesNow(s)]));
  // A written tool switched or deleted: whether the chat offers a tool, by which Reply length is used.
  if (event.type === "written_tools") return redraw(s, toolsNow(s));
  // The chat renamed, starred, archived or put in the Trash in another window.
  if (event.type === "chat") return void (event.id === s.chatId && again(s, event));
  if (ignored(event)) return;
  // A lorebook or a persona was changed in another window: the side panel shows the chat's lorebooks (a persona's
  // among them), the library's and the personas as they read now.
  if (event.type === "lorebook" || event.type === "personas") return again(s, event);
  if (event.chat_id !== s.chatId) return;
  // A message sent, deleted or put back in another window.
  if (event.type === "messages") return again(s, event);
  // The chat named itself (`chats::title`).
  if (event.type === "chat_title") {
    if (s.view) s.view.chat.title = event.title;
    return s.render();
  }
  // The mode the chat picked by itself: the pill says it, and the side panel has the personality where it is personal.
  if (event.type === "chat_mode") {
    if (s.view) s.view.chat.auto_mode = event.mode;
    redraw(s, Promise.all([personalityNow(s), toolsNow(s)]));
    return s.render();
  }
  // A reply offered a coding task: the dialog that starts it, filled in, on this computer's account.
  if (event.type === "coding_offer") {
    if (s.view && !s.view.chat.trashed && s.account?.local) void startDialog(s.node, s.chatId, () => void load(s), event.goal).catch((error: unknown) => tell(s, error));
    return;
  }
  if (event.type === "tool_asks") {
    s.asking = event.ask;
    return s.render();
  }
  // A task's card reads its task anew; a task whose card is not in the chat yet has the chat read anew.
  if (event.type === "coding_task") {
    const card = s.cards.get(event.id);
    if (card) card.refresh();
    else again(s, event);
    return;
  }
  // What was saved to memory shows in the side panel's "Used in this reply" of the message it is from.
  if (event.type === "memories") return again(s, event);
  if (event.type === "reply_ended") {
    s.ended.add(event.message_id);
    if (s.thinking?.id === event.message_id) s.thinking = null;
    // A reply that failed ends the characters' replying by themselves, which the event's drawing shows.
    if (event.error) {
      failed(s, failureWords(event.error));
      end(s);
    }
  }
  if (s.loading) {
    s.held.push(event);
    return;
  }
  if (event.type === "reply_thinking") {
    // A reply not known yet shows the line once it is drawn.
    const message = find(s, event.message_id);
    if (message && (message.complete || message.content)) return;
    s.thinking = { id: event.message_id, line: event.line };
    return showThinking(s, event.message_id);
  }
  if (event.type === "reply_ended") {
    // Without a message the reply is gone and the chat is back where it was.
    if (event.message) show(s, event.message);
    else void load(s);
    return;
  }
  streamed(s, event);
}

/** A piece of a reply being written, put into its message's text. */
function streamed(s: Screen, event: Extract<ServerEvent, { type: "reply_text" }>): void {
  const message = find(s, event.message_id);
  // The message is not known yet, a piece before this one was missed, or it is known as complete: it is being
  // continued, and the event came before the answer that says so. Its end was heard before, so this is no late
  // piece of a reply that has ended.
  if (!message || message.complete || message.content.length < event.start) return void load(s);
  if (event.start + event.text.length <= message.content.length) return;
  message.content = message.content.slice(0, event.start) + event.text;
  if (s.thinking?.id === message.id) {
    s.thinking = null;
    showThinking(s, message.id);
  }
  const text = s.list.querySelector(`[data-id="${message.id}"] .text`);
  if (!text) return;
  const stick = atBottom(s);
  text.replaceChildren(...narrated(message.content, true));
  if (stick) toBottom(s);
}
