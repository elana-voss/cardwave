// The companion's compact chat (board "Companion window"): a box beside the figure with the character's round and
// name, "Open in Cardwave", the speaker that mutes reading aloud (kept with the settings, `muted`; grey while no voice is set up), More (the figure's menu) and Close, the chat's messages as bubbles, and the message field without "+". It is
// the newest chat with the companion's card, or a new one started with the card's first character when there is
// none. A reply streams in by the event socket, as in the chat's screen (views/chat.ts), and what the box does is
// told as the figure's mood: listening while the user types, thinking until the reply's first words, talking while
// they come and while the reply it asked for is read aloud in the card's voice, where the voice is set up and not muted (the
// lips move with it, figure.ts); a reply that ended is told too (`replied`), for the animator.
//
// Traps: the box is made before its chat is known (`open` finds it, once, also when opened twice at once); an event of another chat, or one that
// comes while the chat is read, is let go, as the reply's end brings the whole message; a message sent or deleted in
// another window has the chat read anew, unless a reply of this box is under way.
import { avatarUrl, cardChats, changeCompanion, generate, getCard, getChat, getSettings, getVoice, sendMessage, startChat } from "../api/client";
import type { VoiceModel } from "../api/generated/VoiceModel";
import type { MessageView } from "../api/generated/MessageView";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { menuAt, type MenuItem } from "../dialogs";
import { el, failure, reason } from "../dom";
import { icon } from "../icons";
import { narrated } from "../narration";
import type { Mood } from "./body";
import { failureWords } from "../language/errors";
import { wording } from "../language/language";
import { readAloud, spoken, stopReading } from "../voice/voice";

export interface Hooks {
  mood(mood: Mood): void;
  replied(chatId: number): void;
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
    ...messages.slice(-SHOWN).map((message) =>
      el("div", { className: message.role === "user" ? "bubble me" : "bubble" }, ...narrated(message.content, !message.complete)),
    ),
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

export function compactChat(cardId: number, hooks: Hooks): CompactChat {
  let chatId: number | null = null;
  /** The chat being found, once for the box however often it is opened meanwhile. */
  let finding: Promise<number> | null = null;
  let messages: MessageView[] = [];
  let waiting = false;
  let streaming = false;
  /** Whether the reply on its way was asked for here, which is then read aloud; and the voice, where it is set up. */
  let asked = false;
  let voice: VoiceModel | null = null;
  /** Whether a reply is read aloud, and the readings begun (only the newest's end is the figure's). */
  let speaking = false;
  let readings = 0;
  /** Whether replies are not read aloud, as the settings keep it. */
  let muted = false;
  const { node, picture, name, full, loud, more, shut, list, status, input, form } = compactBox();

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
  /** The speaker: mutes reading aloud, or reads aloud again; kept with the settings. */
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

  const mood = () => hooks.mood(waiting ? "thinking" : streaming || speaking ? "talking" : document.activeElement === input && input.value.trim() ? "listening" : null);

  const draw = () => drawBubbles(list, messages);

  async function read(): Promise<void> {
    chatId ??= await (finding ??= findChat(cardId));
    const view = await getChat(chatId);
    const first = [...view.characters].sort((one, other) => one.id - other.id)[0];
    if (first) {
      picture.src = avatarUrl(first);
      name.textContent = first.name;
      input.placeholder = wording("chat-message", { name: first.name });
    }
    messages = view.messages;
    draw();
  }
  /** Reads `message` aloud in the card's voice, where the voice is set up. */
  function say(message: MessageView): void {
    const text = spoken(message.content);
    if (muted || !voice || !usable(voice) || !text.trim()) return;
    const mine = ++readings;
    speaking = true;
    readAloud(text, voice.rate, (why) => {
      if (why) status.replaceChildren(failure(why));
      if (mine !== readings) return;
      speaking = false;
      mood();
    }, { card: cardId });
  }

  async function sendNow(): Promise<void> {
    const content = input.value.trim();
    if (!content || chatId === null || waiting || streaming) return;
    stopReading();
    status.replaceChildren();
    asked = waiting = true;
    mood();
    try {
      const sent = await sendMessage(chatId, { content });
      input.value = "";
      messages.push(sent);
      draw();
      const reply = await generate(chatId, {});
      if (!messages.some((one) => one.id === reply.id)) messages.push(reply);
      draw();
    } catch (error) {
      asked = waiting = streaming = false;
      status.replaceChildren(failure(reason(error)));
    }
    mood();
  }

  function onEvent(event: ServerEvent): void {
    // The voice may have gone to a provider, or come back.
    if (event.type === "voice" || event.type === "provider") return void getVoice().then(hear, () => {});
    // A message sent, deleted or put back in another window.
    if (event.type === "messages" && event.chat_id === chatId && !waiting && !streaming) return void read().catch(() => {});
    if ((event.type !== "reply_text" && event.type !== "reply_ended") || event.chat_id !== chatId) return;
    if (event.type === "reply_text") {
      waiting = false;
      streaming = true;
      const message = messages.find((one) => one.id === event.message_id);
      if (!message) return;
      if (message.content.length < event.start) return;
      message.content = message.content.slice(0, event.start) + event.text;
      draw();
      return mood();
    }
    waiting = streaming = false;
    if (event.error) status.replaceChildren(failure(failureWords(event.error)));
    if (asked && !event.error && event.message) say(event.message);
    asked = false;
    if (event.message) {
      const at = messages.findIndex((one) => one.id === event.message!.id);
      if (at >= 0) messages[at] = event.message;
      else messages.push(event.message);
      draw();
    } else void read().catch(() => {});
    mood();
    if (!event.error && chatId !== null) hooks.replied(chatId);
  }

  wireField(input, form, mood, sendNow);
  full.onclick = () => chatId !== null && hooks.openFull(chatId);

  function close(): void {
    stopReading();
    node.hidden = true;
    input.blur();
    hooks.closed();
  }
  shut.onclick = close;
  wireMore(more, hooks.more);

  return {
    node,
    async open() {
      node.hidden = false;
      input.focus();
      getVoice().then(hear, () => {});
      getSettings().then((now) => showMuted(now.companion.muted), () => {});
      try {
        await read();
      } catch (error) {
        status.replaceChildren(failure(reason(error)));
      }
    },
    close,
    onEvent,
  };
}
