// The companion's compact chat (board "Companion window"): a box beside the figure with the character's round and
// name, "Open in Cardwave", the speaker that mutes reading aloud (kept with the settings, `muted`; grey while no
// voice is set up), More (the figure's menu) and Close, the chat's messages as bubbles, and the message field without
// "+". Its parts: finding the chat (`chatFinder`), the voice (`boxVoice`) and the server's events (`onEvent`). It is
// the newest chat with the companion's card, or a new one started with the card's first character when there is
// none. A reply streams in by the event socket, as in the chat's screen (views/chat.ts), and what the box does is
// told as the figure's mood: listening while the user types, thinking until the reply's first words, talking while
// they come and while the reply it asked for is read aloud in the card's voice, where the voice is set up and not muted (the
// lips move with it, figure.ts; a reply no voice will read has its letters told as they come, `talks`, for lips.ts);
// a reply that ended is told too (`replied`), for the animator. A reply cut off or broken off says so under its bubble
// (ending.ts), with no "Continue this reply", which the box has for no reply. A memory pass that failed is told in
// the status line, as a reply's failure is.
//
// Traps: the box is made before its chat is known (`open` finds it, once, also when opened twice at once); an event of another chat, or one that
// comes while the chat is read, is let go, as the reply's end brings the whole message; a message sent or deleted in
// another window has the chat read anew, unless a reply of this box is under way; the events `chat` and `trash` and a failed
// search have the chat found anew, and the second `hello` (the socket came back) ends a reply whose end was not heard.
import { avatarUrl, cardChats, changeCompanion, generate, getCard, getChat, getSettings, getVoice, sendMessage, startChat } from "../api/client";
import type { VoiceModel } from "../api/generated/VoiceModel";
import type { MessageView } from "../api/generated/MessageView";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { menuAt, type MenuItem } from "../dialogs";
import { el, failure, reason } from "../dom";
import { icon } from "../icons";
import { narrated } from "../narration";
import type { Mood } from "./body";
import { failureWords, memoryNotKept } from "../language/errors";
import { endingLine } from "../ending";
import { wording } from "../language/language";
import { readAloud, spoken, stopReading } from "../voice/voice";

export interface Hooks {
  mood(mood: Mood): void;
  replied(chatId: number): void;
  /** Letters of a reply that came in and no voice will read (the figure's lips speak them), or none: it ended. */
  talks(letters: string | null): void;
  /** "Open in Cardwave": the chat in the app's window. */
  openFull(chatId: number): void;
  closed(): void;
  /** The figure's menu, read at each press of the head's More (its lines change: "Sit still", "Walk around"). */
  more(): MenuItem[];
}

export interface CompactChat {
  node: HTMLElement;
  /** Shows the box and reads its chat. */
  open(): Promise<void>;
  close(): void;
  onEvent(event: ServerEvent): void;
}

/** How many of the newest messages the box shows. */
const SHOWN = 30;

/** The box's parts: its header, the list of messages, its status line and the message field. */
function compactBox() {
  const picture = el("img", { className: "ava", alt: "" });
  const name = el("span", { className: "compact-name semi f-grow" });
  const full = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("chat-open-in-cardwave"), title: wording("chat-open-in-cardwave") }, icon("go", 16));
  const loud = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("chat-read-replies-aloud"), title: wording("chat-read-replies-aloud"), ariaPressed: "true" }, icon("speaker", 16));
  const more = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("common-more"), title: wording("common-more"), ariaHasPopup: "menu" }, icon("more", 16));
  const shut = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("window-close"), title: wording("window-close") }, icon("close", 16));
  const list = el("div", { className: "compact-list f-grow flex f-col g-12" });
  const status = el("div", { className: "compact-status" });
  const input = el("textarea", { rows: 1, ariaLabel: wording("composer-message") });
  const send = el("button", { type: "submit", className: "send", ariaLabel: wording("composer-send") }, icon("send", 16));
  const form = el("form", { className: "composer" }, input, send);
  const node = el(
    "section",
    { className: "compact-chat flex f-col", role: "dialog", ariaLabel: wording("chat-compact-chat"), hidden: true },
    el("header", { className: "flex ai-c g-10" }, picture, name, full, loud, more, shut),
    list,
    status,
    form,
  );
  return { node, picture, name, full, loud, more, shut, list, status, input, form };
}

/** The newest chat with the card alone (never a chat of several it is in), else a new one with its first character. */
async function findChat(cardId: number): Promise<number> {
  for (const chat of await cardChats(cardId)) {
    if ((await getChat(chat.id)).characters.length === 1) return chat.id;
  }
  const { card, characters } = await getCard(cardId);
  const first = characters[0];
  if (!first) throw new Error(wording("chat-the-card-has-no"));
  return (await startChat({ characters: [{ version_id: card.version_id, character: first.id }] })).chat.id;
}

/** Sends by Enter (a new line by Shift+Enter) and by the form, and tells the mood as the field changes. */
function wireField(input: HTMLTextAreaElement, form: HTMLFormElement, mood: () => void, sendNow: () => Promise<void>): void {
  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      void sendNow();
    }
  });
  input.addEventListener("input", mood);
  input.addEventListener("focus", mood);
  input.addEventListener("blur", mood);
  form.onsubmit = (event) => {
    event.preventDefault();
    void sendNow();
  };
}

/** The newest `SHOWN` messages as bubbles, the list scrolled to its end. */
function drawBubbles(list: HTMLElement, messages: MessageView[]): void {
  list.replaceChildren(
    ...messages
      .slice(-SHOWN)
      .flatMap((message) => [el("div", { className: message.role === "user" ? "bubble me" : "bubble" }, ...narrated(message.content, !message.complete)), endingLine(message)])
      .filter((node) => node !== null),
  );
  list.scrollTop = list.scrollHeight;
}

/** Whether `voice` can read aloud: downloaded, or at a provider. */
const usable = (voice: VoiceModel): boolean => voice.state === "ready" || voice.at_provider;

/** The head's More: opens the figure's menu under it, and a press while it is open closes it. */
function wireMore(button: HTMLButtonElement, items: () => MenuItem[]): void {
  let open: AbortSignal | null = null;
  /** Whether the press began on an open menu, which the press beside it closes first. */
  let wasOpen = false;
  button.onpointerdown = () => void (wasOpen = open !== null && !open.aborted);
  button.onclick = (event) => {
    if (wasOpen) return void (wasOpen = false);
    const at = button.getBoundingClientRect();
    open = menuAt(button, items(), at.left, at.bottom + 6, event.detail > 0);
  };
}

/** The box's chat, found once however often the box is opened meanwhile; a failed search is not kept, the next asks again. */
function chatFinder(cardId: number) {
  let id: number | null = null;
  let finding: Promise<number> | null = null;
  return {
    /** The chat, once found. */
    get id(): number | null {
      return id;
    },
    async found(): Promise<number> {
      if (id !== null) return id;
      const asking = (finding ??= findChat(cardId));
      try {
        const now = await asking;
        // A search that a chat or trash event passed by is not the chat any more.
        if (finding === asking) id = now;
        return now;
      } catch (error) {
        if (finding === asking) finding = null;
        throw error;
      }
    },
    /** Takes the chat as not found. */
    forget(): void {
      id = null;
      finding = null;
    },
  };
}
type ChatFinder = ReturnType<typeof chatFinder>;

/**
 * The box's voice: the speaker, which mutes reading aloud (kept with the settings) and is grey while no voice is set
 * up, and the reading of a reply aloud. `ended` is told when the newest reading ends.
 */
function boxVoice(cardId: number, loud: HTMLButtonElement, status: HTMLElement, ended: () => void) {
  let voice: VoiceModel | null = null;
  /** Whether a reply is read aloud, and the readings begun (only the newest's end is the figure's). */
  let speaking = false;
  let readings = 0;
  /** Whether replies are not read aloud, as the settings keep it. */
  let muted = false;
  /** Takes the voice the server tells, and greys the speaker, saying why, while none is set up. */
  const hear = (now: VoiceModel) => {
    voice = now;
    loud.disabled = !usable(now);
    loud.title = loud.disabled ? wording("chat-no-voice") : wording("chat-read-replies-aloud");
  };
  const showMuted = (now: boolean) => {
    muted = now;
    loud.ariaPressed = String(!now);
    loud.replaceChildren(icon(now ? "speaker-off" : "speaker", 16));
  };
  loud.onclick = async () => {
    const before = muted;
    showMuted(!before);
    if (muted) stopReading();
    try {
      showMuted((await changeCompanion({ muted })).companion.muted);
    } catch (error) {
      showMuted(before);
      status.replaceChildren(failure(reason(error)));
    }
  };
  return {
    get speaking(): boolean {
      return speaking;
    },
    /** Whether a reply asked for here will be read aloud: a voice set up and not muted. */
    get reads(): boolean {
      return !muted && voice !== null && usable(voice);
    },
    /** Reads the voice anew. A failed read keeps the speaker as it was: the next voice or provider event asks again. */
    readVoice(): void {
      getVoice().then(hear, () => {});
    },
    /** Reads the voice and whether it is muted. A failed read of the settings keeps the speaker on, as it was. */
    read(): void {
      this.readVoice();
      getSettings().then((now) => showMuted(now.companion.muted), () => {});
    },
    /** Reads `message` aloud in the card's voice, where the voice is set up. */
    say(message: MessageView): void {
      const text = spoken(message.content);
      if (muted || !voice || !usable(voice) || !text.trim()) return;
      const mine = ++readings;
      speaking = true;
      readAloud(text, voice.rate, (why) => {
        if (why) status.replaceChildren(failure(why));
        if (mine !== readings) return;
        speaking = false;
        ended();
      }, { card: cardId });
    },
  };
}

/** What the box knows of its chat's talk, which its events change. */
interface Talk {
  messages: MessageView[];
  /** A reply asked for and no words of it yet; its words coming. */
  waiting: boolean;
  streaming: boolean;
  /** Whether the reply on its way was asked for here, which is then read aloud. */
  asked: boolean;
  /** Whether the box has heard the server before: the next `hello` is after a drop, when a reply's end may have been missed. */
  heard: boolean;
  /** A reply's words that came before the answer to `generate` brought its message, by the message's id. */
  early: Map<number, string>;
}

/** What the box's event handling reaches. */
interface Box {
  talk: Talk;
  chat: ChatFinder;
  voice: ReturnType<typeof boxVoice>;
  node: HTMLElement;
  status: HTMLElement;
  hooks: Hooks;
  read(): Promise<void>;
  draw(): void;
  mood(): void;
}

/**
 * Reads the chat anew where a failure needs no word: the messages shown stay, and the next event or opening reads
 * again. A failure the user waits on (opening, a refind) is told in the status line instead.
 */
const quietly = (box: Box) => void box.read().catch(() => {});

function onEvent(box: Box, event: ServerEvent): void {
  const { talk, chat } = box;
  if (event.type === "hello") {
    if (!talk.heard) return void (talk.heard = true);
    talk.waiting = talk.streaming = talk.asked = false;
    box.hooks.talks(null);
    box.mood();
    if (!box.node.hidden && chat.id !== null) quietly(box);
    return;
  }
  const busy = talk.waiting || talk.streaming;
  // The chat deleted or archived in the app is not the one to go on with: the newest is found again.
  if ((event.type === "chat" || event.type === "trash") && !busy) {
    chat.forget();
    if (!box.node.hidden) void box.read().catch((error) => box.status.replaceChildren(failure(reason(error))));
    return;
  }
  // The voice may have gone to a provider, or come back.
  if (event.type === "voice" || event.type === "provider") return box.voice.readVoice();
  // A message sent, deleted or put back in another window.
  if (event.type === "messages" && event.chat_id === chat.id && !busy) return quietly(box);
  if (event.type === "reply_text" && event.chat_id === chat.id) return replyText(box, event);
  if (event.type === "reply_ended" && event.chat_id === chat.id) replyEnded(box, event);
  // Its chat's memory pass failed by the helper model: told in the status line, as a reply's failure is.
  if (event.type === "memory_failed" && event.chat_id === chat.id) box.status.replaceChildren(failure(memoryNotKept(event.error)));
}

/** A reply's words so far: they replace the message's text from `start`. */
function replyText(box: Box, event: Extract<ServerEvent, { type: "reply_text" }>): void {
  box.talk.waiting = false;
  box.talk.streaming = true;
  const message = box.talk.messages.find((one) => one.id === event.message_id);
  const known = message ? message.content : (box.talk.early.get(event.message_id) ?? "");
  if (known.length < event.start) return;
  const content = known.slice(0, event.start) + event.text;
  if (message) message.content = content;
  else box.talk.early.set(event.message_id, content);
  if (!(box.talk.asked && box.voice.reads)) box.hooks.talks(content.slice(known.length));
  box.draw();
  box.mood();
}

/** A reply's end: its whole message, read aloud where it was asked for here, or its failure. */
function replyEnded(box: Box, event: Extract<ServerEvent, { type: "reply_ended" }>): void {
  const { talk } = box;
  talk.waiting = talk.streaming = false;
  box.hooks.talks(null);
  talk.early.clear();
  if (event.error) box.status.replaceChildren(failure(failureWords(event.error)));
  if (talk.asked && !event.error && event.message) box.voice.say(event.message);
  talk.asked = false;
  const ended = event.message;
  if (ended) {
    const at = talk.messages.findIndex((one) => one.id === ended.id);
    if (at >= 0) talk.messages[at] = ended;
    else talk.messages.push(ended);
    box.draw();
  } else quietly(box);
  box.mood();
  if (!event.error && box.chat.id !== null) box.hooks.replied(box.chat.id);
}

export function compactChat(cardId: number, hooks: Hooks): CompactChat {
  const talk: Talk = { messages: [], waiting: false, streaming: false, asked: false, heard: false, early: new Map() };
  const chat = chatFinder(cardId);
  const { node, picture, name, full, loud, more, shut, list, status, input, form } = compactBox();
  const mood = () =>
    hooks.mood(talk.waiting ? "thinking" : talk.streaming || voice.speaking ? "talking" : document.activeElement === input && input.value.trim() ? "listening" : null);
  const voice = boxVoice(cardId, loud, status, mood);
  const draw = () => drawBubbles(list, talk.messages);

  async function read(): Promise<void> {
    const view = await getChat(await chat.found());
    const first = [...view.characters].sort((one, other) => one.id - other.id)[0];
    if (first) {
      picture.src = avatarUrl(first);
      name.textContent = first.name;
      input.placeholder = wording("chat-message", { name: first.name });
    }
    talk.messages = view.messages;
    draw();
  }

  async function sendNow(): Promise<void> {
    const content = input.value.trim();
    if (!content || talk.waiting || talk.streaming) return;
    stopReading();
    status.replaceChildren();
    talk.asked = talk.waiting = true;
    mood();
    try {
      const id = await chat.found();
      const sent = await sendMessage(id, { content });
      input.value = "";
      talk.messages.push(sent);
      draw();
      const reply = await generate(id, {});
      // Its first words may have come before this answer, and its end too.
      if (!talk.messages.some((one) => one.id === reply.id)) talk.messages.push({ ...reply, content: talk.early.get(reply.id) ?? reply.content });
      talk.early.delete(reply.id);
      draw();
    } catch (error) {
      talk.asked = talk.waiting = talk.streaming = false;
      status.replaceChildren(failure(reason(error)));
    }
    mood();
  }

  wireField(input, form, mood, sendNow);
  full.onclick = () => chat.id !== null && hooks.openFull(chat.id);
  function close(): void {
    stopReading();
    node.hidden = true;
    input.blur();
    hooks.closed();
  }
  shut.onclick = close;
  wireMore(more, hooks.more);
  const box: Box = { talk, chat, voice, node, status, hooks, read, draw, mood };

  return {
    node,
    async open() {
      node.hidden = false;
      input.focus();
      voice.read();
      try {
        await read();
      } catch (error) {
        status.replaceChildren(failure(reason(error)));
      }
    },
    close,
    onEvent: (event) => onEvent(box, event),
  };
}
