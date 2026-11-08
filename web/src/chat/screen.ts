// The chat screen's state, which its parts in this folder share, and what they all do with it: read the chat
// (`load`), run one action at a time (`act`), tell what went wrong (`failed`, `tell`), put a message into the view
// (`show`), ask for a reply (`reply`) and read anew whether Reply length is used (`toolsNow`). The screen
// (views/chat.ts) makes it (`newScreen`) and sets `render` and `onEvent`; the parts draw only from it.
//
// Traps: events that come while the chat is read wait (`held`) and apply to what was read; `ended` keeps a late
// answer to `generate` from bringing back a reply known to have ended. While something is written (`drafting`), or
// the characters reply by themselves (`talk`), a message is only read (`idle`).
import { account as known } from "../account";
import type { Account } from "../api/generated/Account";
import type { Attachment } from "../api/generated/Attachment";
import type { Chat } from "../api/generated/Chat";
import type { ChatView } from "../api/generated/ChatView";
import type { Generate } from "../api/generated/Generate";
import type { Lorebook } from "../api/generated/Lorebook";
import type { MessageView } from "../api/generated/MessageView";
import type { Persona } from "../api/generated/Persona";
import type { Personality } from "../api/generated/Personality";
import type { PromptPreset } from "../api/generated/PromptPreset";
import type { ServerEvent } from "../api/generated/ServerEvent";
import type { ToolAsk } from "../api/generated/ToolAsk";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { generate, getChat, getPersonality, getVoice, libraryLorebooks, listPersonas, listPromptPresets, needsSetup, stopReply } from "../api/client";
import type { taskCard } from "./coding";
import { el, reason } from "../dom";
import { isPersonal, modeInUse } from "../card/modes";
import { readWebPictures } from "../narration";
import { failureWords } from "../language/errors";

/** The model writes the message field's text, or betters it, or makes a picture (`again`: anew, of that message); `stop` hangs up. */
export type Drafting = { stop: AbortController; improve: boolean; picture?: boolean; again?: number };
/**
 * The characters keep replying by themselves: how many replies they were asked for, whether one is being asked
 * for, the pause's timer, and whether a reply begun after they were stopped is to be stopped too.
 */
type Talk = { asked: number; asking: boolean; timer: number; stopped: boolean };

export interface Screen {
  readonly chatId: number;
  view: ChatView | null;
  /** The user's personas in plain view, the prompt presets and the library's lorebooks, for the side panel. */
  personas: Persona[];
  prompts: PromptPreset[];
  library: Lorebook[];
  /** The voice, which reads a message aloud once it is downloaded, and the message it reads. */
  voice: VoiceModel | null;
  reading: number | null;
  /** The account: its picture, or the first letter of its name, stands in the round beside the user's name. */
  account: Account | undefined;
  /** The personality of the chat's first character, while it is in a personal mode. */
  personality: Personality | null;
  /** The call of a tool the reply waits for the user to allow. */
  asking: ToolAsk | null;
  /** The message the next one branches off after, while the user has chosen to branch. */
  branchAt: number | null;
  /** The reply chosen with a click, whose "Used in this reply" the side panel shows; else the newest's. */
  chosen: number | null;
  /**
   * A reply is asked for: the newest message's id when it was (-1 for none). Until a newer message comes, a bubble
   * with the typing sign stands in the reply's place.
   */
  asked: number | null;
  /** The reply whose model thinks before its first word, and the newest sentence of its thinking. */
  thinking: { id: number; line: string } | null;
  editing: { id: number; draft: string } | null;
  /** The picture whose words are being changed ("Change prompt"), and the words. */
  repicturing: { id: number; words: string } | null;
  /** What waits attached for the next message, shown over the message field. */
  attached: Attachment[];
  notice: string;
  /** What the notice says failed needs a model, and the user has no provider yet: the notice leads to its setup. */
  unset: boolean;
  /** A request is on its way; further actions wait for it. */
  working: boolean;
  drafting: Drafting | null;
  /** Replies known to have ended, so a late answer to `generate` does not bring one back. */
  readonly ended: Set<number>;
  loading: Promise<void> | null;
  /** Events that came while the chat was being read. */
  readonly held: ServerEvent[];
  talk: Talk | null;
  /** The coding tasks' cards, by task. */
  readonly cards: Map<number, ReturnType<typeof taskCard>>;
  /** The screen, its list of messages, what scrolls it, and the message field. */
  readonly node: HTMLElement;
  readonly list: HTMLElement;
  readonly scroller: HTMLElement;
  readonly input: HTMLTextAreaElement;
  render(): void;
  onEvent(event: ServerEvent): void;
}

export function newScreen(chatId: number): Screen {
  const list = el("div", { className: "chat-thread messages" });
  return {
    chatId,
    view: null,
    personas: [],
    prompts: [],
    library: [],
    voice: null,
    reading: null,
    account: undefined,
    personality: null,
    asking: null,
    branchAt: null,
    chosen: null,
    asked: null,
    thinking: null,
    editing: null,
    repicturing: null,
    attached: [],
    notice: "",
    unset: false,
    working: false,
    drafting: null,
    ended: new Set(),
    loading: null,
    held: [],
    talk: null,
    cards: new Map(),
    node: el("section", { className: "chat f-grow flex minw0" }),
    list,
    scroller: el("div", { className: "chat-scroller f-grow flex f-col ai-c" }, list),
    input: el("textarea", { id: "composer", rows: 1 }),
    render: () => {},
    onEvent: () => {},
  };
}

/** Takes what went wrong as the notice over the chat. */
export function failed(s: Screen, error: unknown): void {
  s.notice = reason(error);
  s.unset = needsSetup(error);
}

/** Shows what went wrong outside an action. */
export function tell(s: Screen, error: unknown): void {
  failed(s, error);
  s.render();
}

export const find = (s: Screen, id: number) => s.view?.messages.find((message) => message.id === id);
export const newest = (s: Screen) => s.view?.messages.at(-1);
/** A reply is being generated: the chat takes nothing but a stop. */
export const busy = (s: Screen) => newest(s)?.complete === false;
/** Nothing is being written, by a model or by the characters by themselves: a message can be changed. */
export const idle = (s: Screen) => !busy(s) && !s.talk && !s.drafting;
export const atBottom = (s: Screen) => s.scroller.scrollHeight - s.scroller.scrollTop - s.scroller.clientHeight < 40;
export const toBottom = (s: Screen) => s.scroller.scrollTo(0, s.scroller.scrollHeight);

/** Reads the chat from the server. */
export function load(s: Screen): Promise<void> {
  s.loading ??= (async () => {
    const first = !s.view;
    try {
      // The chat shows without the lists of personas and of lorebooks too; why one did not come is said over it.
      const or = <T>(list: Promise<T>, known: T) =>
        list.catch((error) => {
          failed(s, error);
          return known;
        });
      // What the account is called is the letter in a round, which is told below: the chat waits for it, and is no worse without it.
      [s.view, s.personas, s.library, s.prompts, s.voice] = await Promise.all([
        getChat(s.chatId),
        or(listPersonas(), s.personas),
        or(libraryLorebooks(), s.library),
        or(listPromptPresets(), s.prompts),
        getVoice().catch(() => s.voice),
        known().catch(() => {}),
        // Whether a picture from another website shows; held back where the settings do not say.
        readWebPictures(),
      ]);
      s.asking = s.view.asking;
      if (first) sayBrokeOff(s);
      await personalityNow(s).catch((error: unknown) => failed(s, error));
    } catch (error) {
      failed(s, error);
    }
    s.loading = null;
    s.render();
    for (const event of s.held.splice(0)) s.onEvent(event);
  })();
  return s.loading;
}

/** A reply the app's close broke off says so when its chat is opened, as it said so live (`events`). */
export function sayBrokeOff(s: Screen): void {
  if (newest(s)?.broke_off) failed(s, failureWords({ code: "model_answer", error: "", details: { what: "reply_broke_off" } }));
}

/**
 * Reads anew whether the chat's model thinks and whether a tool is offered its replies, by which the side panel
 * tells whether Reply length is used: after the mode, the personality, the settings or the model changed.
 */
export async function toolsNow(s: Screen): Promise<void> {
  const { thinks, tools } = await getChat(s.chatId);
  if (s.view) Object.assign(s.view, { thinks, tools });
}

/** Reads the personality of the chat's first character where the mode it is in is personal; else there is none. */
export async function personalityNow(s: Screen): Promise<void> {
  const view = s.view;
  s.personality = view && isPersonal(modeInUse(view.chat, view.modes)) ? await getPersonality(s.chatId) : null;
}

/** Takes away what was told over the chat: a failure, and that no model is set up. */
const clear = (s: Screen) => Object.assign(s, { notice: "", unset: false });

/**
 * Runs one action at a time; a failure is shown over the chat as the server
 * has it. Answers whether the action was done.
 */
export async function act(s: Screen, action: () => Promise<void>): Promise<boolean> {
  if (s.working) return false;
  s.working = true;
  clear(s);
  let done = true;
  try {
    await action();
  } catch (error) {
    await load(s);
    failed(s, error);
    done = false;
  }
  s.working = false;
  s.render();
  return done;
}

/** Takes the chat as the server has it after a change, and with a change of persona who that is. */
export function took(s: Screen, chat: Chat, persona = s.view?.persona ?? null): void {
  if (s.view) Object.assign(s.view, { chat, persona });
}

/** Puts a message into the view: in place of itself or of another swipe of it, or at the end. */
export function show(s: Screen, message: MessageView): void {
  if (!s.view) return;
  // Who wrote it has written in the chat from now on, and stays in it.
  const by = s.view.characters.find((character) => character.id === message.speaker_id);
  if (by) by.written = true;
  const messages = s.view.messages;
  const same = messages.findIndex((other) => other.id === message.id);
  const swipe = messages.findIndex((other) => other.parent_id === message.parent_id);
  if (same >= 0) messages[same] = message;
  // What followed the other swipe is not in view after this one.
  else if (swipe >= 0) messages.splice(swipe, messages.length, message);
  else if ((newest(s)?.id ?? null) === message.parent_id) messages.push(message);
  else return void load(s);
  s.render();
}

/**
 * Asks for a reply: to the newest message, by whom the chat's turn says, or
 * as `how` says, that message written again or continued by the one who wrote it.
 */
export async function reply(s: Screen, how: Generate = {}): Promise<void> {
  // A reply continued is written in the message whose end was heard before: it has not ended yet.
  const going = how.continue ? newest(s)?.id : undefined;
  if (going !== undefined) s.ended.delete(going);
  // A new reply shows its bubble with the typing sign at once; one written again or continued has its own.
  const fresh = !how.continue && !how.regenerate;
  if (fresh) {
    s.asked = newest(s)?.id ?? -1;
    s.render();
    toBottom(s);
  }
  let message: MessageView;
  try {
    message = await generate(s.chatId, how);
  } finally {
    if (fresh) s.asked = null;
  }
  // The reply's events may have come before this answer. A reply continued is in view already, as it was written.
  if (!s.ended.has(message.id) && (find(s, message.id)?.complete ?? true)) show(s, message);
}

/** Stops the reply. It does not wait for an action on its way, as a stop is wanted at once. */
export const stop = (s: Screen) => stopReply(s.chatId).catch((error: unknown) => tell(s, error));

/** Starts the model writing for the field (`drafting`), or answers null where something else is on its way. */
export function startDrafting(s: Screen, improve: boolean, picture = false, again?: number): Drafting | null {
  if (s.drafting || s.working || !idle(s)) return null;
  const mine: Drafting = { stop: new AbortController(), improve, ...(picture && { picture }), ...(again !== undefined && { again }) };
  s.drafting = mine;
  clear(s);
  s.render();
  return mine;
}

/** Marks the message the next one branches off after, or none; the message field has the focus then. */
export function branch(s: Screen, at: number | null): void {
  s.branchAt = at;
  s.render();
  if (at !== null) s.input.focus();
}
