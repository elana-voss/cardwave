// The message field and what stands with it: the "+" ("Add or write": Write for me, Improve, Make a picture, Attach
// picture or document, Add a character, Start a coding task; most with a grey line saying what it does), the microphone
// while dictation is set up (dictate.ts), Send, grey while there is nothing to send and Stop while something is written, and
// over the field the pill "Who replies" of a chat of several characters, with the turn orders, "Always" a character,
// and "Keep replying by themselves", and the tiles of what waits attached for the next message, each with its ×.
// What is attached goes to the server at once and waits there (`s.attached`); a message of attachments alone is sent.
//
// "Write for me" and a message's Continue are steered by the field's words, which are sent as no message (C7).
//
// Traps: the lines of "+" that write can be picked only while nothing is written, set at each drawing and as the
// field's words change (`offer`); the coding team works on this computer's files, so its line is that account's
// alone, and only in a chat without a character or in the Assistant mode (`codingOffered`). Pill and menu of who replies are made anew only when what they
// say changes, as an open menu would close. What is typed and not sent is kept as the field's unsaved text
// (`typed`, ../unsaved.ts) and comes back when the chat is opened again. The field takes words while a reply
// arrives; only Send waits, being Stop meanwhile.
import type { MessageView } from "../api/generated/MessageView";
import type { Turn } from "../api/generated/Turn";
import type { TurnOrder } from "../api/generated/TurnOrder";
import { addCharacter, attach, draft, makePicture, moveHead, removeAttachment, removeCharacter, sendMessage, setTurn } from "../api/client";
import { addCharacterDialog } from "../library/add-character";
import { modeInUse, sameMode } from "../card/modes";
import { startDialog } from "./coding";
import { announce, el } from "../dom";
import { menuOn, type MenuItem } from "../dialogs";
import { icon } from "../icons";
import { dictateButton } from "./dictate";
import { attachmentNode } from "./pictures";
import { act, busy, failed, idle, load, newest, reply, show, startDrafting, stop, toBottom, took, type Drafting, type Screen } from "./screen";
import { canTalk, halt, talkOn } from "./talk";
import { forget, keep, kept } from "../unsaved";
import { wording } from "../language/language";
import { comma } from "../format";

/** The turn orders, by which a chat of several characters picks who replies next: what "Who replies" calls each, and what it says of the one chosen. */
const orderChoices = (): { order: TurnOrder; line: string; means: string }[] => ([
  { order: "natural", line: wording("composer-whoever-is-named-replies"), means: wording("composer-the-character-named-in") },
  { order: "list", line: wording("composer-each-replies-in-turn"), means: wording("composer-the-characters-reply-one") },
  { order: "random", line: wording("composer-a-random-one-replies"), means: wording("composer-one-of-the-characters") },
]);
/** The line of "Who replies" that has the characters keep replying by themselves. */
const talk = () => (wording("composer-keep-replying-by-themselves"));

export interface Composer {
  form: HTMLFormElement;
  field: HTMLElement;
  primary: HTMLButtonElement;
  /** The microphone; `read` is called on the event `dictation`. */
  dictate: { node: HTMLButtonElement; read(): void };
  writeLine: MenuItem;
  improveLine: MenuItem;
  pictureLine: MenuItem;
  addLine: MenuItem;
  codingLine: MenuItem;
  /** The tiles of what waits attached, and the ids they show. */
  waiting: HTMLElement;
  waitingFor: string;
  /** Who replies next: a pill that says the choice, and opens a menu of the turn orders and the characters. */
  replier: HTMLElement;
  repliersFor: string;
  /** The menu's last line, under a rule; whether it can be picked is set at each drawing. */
  go: MenuItem;
}

export function composer(s: Screen): Composer {
  const primary = el("button", { type: "submit", className: "send" });
  const replier = el("div", { className: "replier", hidden: true });
  const c: Composer = {
    form: el("form", { className: "chat-wrap flex f-col g-6", hidden: true }),
    field: el("div", { className: "composer" }),
    primary,
    dictate: dictateButton(s.input),
    writeLine: { label: wording("composer-write-for-me"), shape: "edit", sub: wording("composer-uses-what-you-typed"), action: () => void write(s, c, false) },
    improveLine: { label: wording("composer-improve"), shape: "sparkle", sub: wording("composer-rewrites-what-you-typed"), action: () => void write(s, c, true) },
    pictureLine: { label: wording("card-picture-make-a-picture"), sub: wording("composer-ai-draws-a-picture"), shape: "picture", action: () => void picture(s) },
    waiting: el("div", { className: "waiting-attachments", hidden: true }),
    waitingFor: "",
    addLine: {
      label: wording("add-character-add-a-character"),
      shape: "person",
      sub: wording("composer-joins-this-chat"),
      action: () => addCharacterDialog(s.node, s.view?.characters ?? [], (cardId, character) => void join(s, cardId, character)),
    },
    codingLine: { label: wording("coding-start-a-coding-task"), shape: "code", hidden: true, action: () => void startDialog(s.node, s.chatId, () => void load(s)).catch((error: unknown) => failed(s, error)) },
    replier,
    repliersFor: "",
    go: {
      label: talk(),
      shape: "play",
      apart: true,
      action: () => {
        talkOn(s);
        replier.querySelector("button")?.focus();
      },
    },
  };
  const attachLine: MenuItem = { label: wording("composer-attach-picture-or-document"), shape: "clip", apart: true, action: () => pick(s) };
  const add = menuOn(el("button", { type: "button", className: "btn btn-quiet btn-icon btn-lg", ariaLabel: wording("composer-add-or-write"), title: wording("composer-add-or-write") }, icon("plus")), [c.writeLine, c.improveLine, c.pictureLine, attachLine, c.addLine, c.codingLine]);
  add.classList.add("composer-tools");
  c.field.append(add, el("label", { htmlFor: "composer", className: "sr" }, wording("composer-message")), s.input, c.dictate.node, primary);
  // A press on the field beside its text is one on the text.
  c.field.onclick = (event) => {
    if (event.target === c.field) s.input.focus();
  };
  c.form.append(replier, c.waiting, c.field);
  c.form.onsubmit = (event) => {
    event.preventDefault();
    if (s.drafting) s.drafting.stop.abort();
    else if (!busy(s)) send(s);
    else if (s.talk) halt(s, true);
    else void stop(s);
  };
  s.input.oninput = () => {
    offer(s, c);
    typed(s);
  };
  // What was typed and not sent comes back, unless something is typed meanwhile.
  void kept(fieldOf(s)).then((text) => {
    if (text && !s.input.value) {
      s.input.value = text;
      offer(s, c);
    }
  });
  // Enter sends, Shift+Enter starts a new line.
  s.input.onkeydown = (event) => {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return;
    event.preventDefault();
    send(s);
  };
  return c;
}

/**
 * Whether "+" offers "Start a coding task": on this computer's account alone, whose files the team works on, and
 * only in a chat without a character or one in the Assistant mode, not in a roleplay.
 */
export function codingOffered(s: Screen): boolean {
  const view = s.view;
  if (!s.account?.local || !view) return false;
  return view.characters.length === 0 || sameMode(modeInUse(view.chat, view.modes) ?? "", "assistant");
}

/** The name the message field's unsaved text is kept by (../unsaved.ts). */
const fieldOf = (s: Screen) => `chat.${s.chatId}`;

/** Keeps what the field holds as its unsaved text, or forgets it where it is empty. */
export function typed(s: Screen): void {
  if (s.input.value) keep(fieldOf(s), s.input.value);
  else forget(fieldOf(s));
}

/**
 * Sets whether the lines of "+" that write can be picked: not while something is written, and Improve not without
 * words; whether "Start a coding task" is there (`codingOffered`); and whether Send can be pressed.
 */
function offer(s: Screen, c: Composer): void {
  c.codingLine.hidden = !codingOffered(s);
  c.writeLine.off = !idle(s) || !s.view || s.view.characters.length === 0;
  c.improveLine.off = c.writeLine.off || !s.input.value.trim();
  c.pictureLine.off = c.writeLine.off;
  // Send is grey while there is nothing to send; Stop never is.
  c.primary.disabled = !busy(s) && s.drafting === null && !s.input.value.trim() && !s.attached.length;
}

/** Draws the field, Send or Stop with its tooltip, and the pill of who replies. */
export function drawComposer(s: Screen, c: Composer): void {
  const { characters, messages } = s.view!;
  const stopping = busy(s) || s.drafting !== null;
  const label = stopping ? wording("gen-stop") : wording("composer-send");
  if (c.primary.ariaLabel !== label) {
    c.primary.ariaLabel = label;
    c.primary.replaceChildren(icon(stopping ? "stop" : "send"));
  }
  // Send's tooltip says how much of the context the newest reply's prompt took (the owner, 2026-10-15).
  const context = [...messages].reverse().find((message) => message.context)?.context;
  c.primary.title = stopping ? wording("gen-stop") : context ? wording("composer-tokens-of", { used: context.used, size: context.size }) : wording("composer-send");
  const whom = characters.map((character) => character.name).join(comma());
  const drafting = s.drafting;
  s.input.placeholder = drafting?.picture ? wording("card-picture-making-a-picture") : drafting && !drafting.improve ? wording("composer-writing-your-message") : characters.length ? wording("composer-message-2", { whom }) : wording("composer-message");
  c.addLine.hidden = !characters.length;
  s.input.readOnly = drafting !== null;
  c.field.classList.toggle("drafting", drafting !== null);
  offer(s, c);
  drawReplier(s, c);
  drawWaiting(s, c);
}

/** The tiles of what waits attached, made anew only as that changes; a tile's × takes it off, with its document. */
function drawWaiting(s: Screen, c: Composer): void {
  const ids = s.attached.map((attached) => attached.id).join(",");
  if (ids === c.waitingFor) return;
  c.waitingFor = ids;
  c.waiting.hidden = !s.attached.length;
  c.waiting.replaceChildren(
    ...s.attached.map((attached) => {
      const off = () =>
        void act(s, async () => {
          await removeAttachment(attached.id);
          s.attached = s.attached.filter((other) => other.id !== attached.id);
        });
      const remove = el("button", { type: "button", className: "remove btn btn-secondary btn-icon", ariaLabel: wording("mcp-remove"), title: wording("add-character-remove", { name: attached.name }) }, icon("close", 12));
      remove.onclick = off;
      return el("div", { className: "waiting-tile" }, attachmentNode(attached, true), remove);
    }),
  );
}

/** Asks for pictures and documents, and attaches each to the next message; one refused leaves those before it. */
function pick(s: Screen): void {
  const field = el("input", { type: "file", accept: ".png,.jpg,.jpeg,.webp,.pdf,.docx,.txt,.md,.markdown", multiple: true, hidden: true });
  field.oncancel = () => field.remove();
  field.onchange = () => {
    const files = [...(field.files ?? [])];
    field.remove();
    if (!files.length) return;
    void act(s, async () => {
      for (const file of files) s.attached.push(await attach(s.chatId, file));
    });
  };
  document.body.append(field);
  field.click();
}

/** Who replies next: the character picked by hand, else whom the chat's order picks. */
function drawReplier(s: Screen, c: Composer): void {
  const view = s.view!;
  const { chat, characters } = view;
  const picked = characters.find((character) => character.id === chat.replier_id);
  const cast = JSON.stringify([characters.map((character) => [character.id, character.name]), chat.turn_order, picked?.id]);
  if (cast !== c.repliersFor) {
    c.repliersFor = cast;
    // Makes `turn` the chat's; the pill, made anew with the choice, has the focus then.
    const choose = (turn: Turn) => async () => {
      await act(s, async () => took(s, await setTurn(s.chatId, turn)));
      c.replier.querySelector("button")?.focus();
    };
    const by = orderChoices().find(({ order }) => order === chat.turn_order)!;
    const says = picked ? wording("composer-replies", { name: picked.name }) : by.line;
    // A long name is cut in the pill, which is no wider than the field under it.
    const pill = el("button", { type: "button", className: "btn btn-quiet btn-fit fs-small c-grey", ariaLabel: wording("composer-who-replies", { says }), title: picked ? wording("composer-writes-every-reply", { name: picked.name }) : by.means }, el("span", null, says), icon("down", 14));
    const orders: MenuItem[] = orderChoices().map(({ order, line }, at) => ({
      label: line,
      group: at === 0 ? wording("composer-who-replies-group") : undefined,
      chosen: !picked && order === chat.turn_order,
      action: choose({ order }),
    }));
    const always: MenuItem[] = characters.map(({ id, name }, at) => ({
      label: name,
      group: at === 0 ? wording("lorebook-entry-always") : undefined,
      chosen: id === picked?.id,
      action: choose({ replier_id: id }),
    }));
    c.replier.replaceChildren(menuOn(pill, [...orders, ...always, c.go]));
  }
  // Whether the line can be picked changes as the characters start and stop replying by themselves, which leaves
  // the menu as it is, also where it is open then.
  c.go.off = !canTalk(view) || s.talk !== null;
  const line = [...c.replier.querySelectorAll<HTMLElement>('[role="menuitem"]')].at(-1);
  if (line) line.ariaDisabled = c.go.off ? "true" : null;
  c.replier.hidden = characters.length < 2;
}

/**
 * Has a character of a card of the library join the chat. It leaves again
 * by the notice's Undo as long as it has written nothing.
 */
const join = (s: Screen, cardId: number, character: string) =>
  act(s, async () => {
    s.view = await addCharacter(s.chatId, { card_id: cardId, character });
    const joined = s.view.characters.at(-1)!;
    announce(wording("composer-joined-the-chat", { name: joined.name }), async () => {
      s.view = await removeCharacter(joined.id);
      s.render();
    });
  });

function send(s: Screen): void {
  const content = s.input.value.trim();
  const attachments = s.attached.map((attached) => attached.id);
  if ((!content && !attachments.length) || s.drafting) return;
  // The user's message ends the characters' replying by themselves; one being written ends first, and the words wait.
  halt(s);
  if (busy(s)) return;
  void act(s, async () => {
    const at = s.branchAt;
    const head = newest(s)?.id;
    if (at !== null) s.view = await moveHead(s.chatId, { message_id: at });
    let message: MessageView;
    try {
      message = await sendMessage(s.chatId, { content, attachments });
    } catch (error) {
      // Nothing was sent, so the view ends again where it did. Why the message
      // was not sent is what gets told, whether or not this works.
      // The way back failing changes nothing of what is told.
      if (at !== null && head !== undefined) await moveHead(s.chatId, { message_id: head }).catch(() => {});
      throw error;
    }
    s.branchAt = null;
    s.input.value = "";
    typed(s);
    s.attached = [];
    show(s, message);
    await reply(s);
  });
}

/**
 * Has the model write the user's message, steered by the words in the field (C7), or, with `improve`, better the
 * one in the field, and puts its text there. Stopped, or failing, it leaves the field as it was. Words it takes
 * the place of come back by the notice's Undo.
 */
async function write(s: Screen, c: Composer, improve: boolean): Promise<void> {
  const before = s.input.value;
  if (improve && !before.trim()) return;
  const done = await drafted(s, improve, false, async (signal) => {
    const { content } = await draft(s.chatId, improve ? { improve: before } : before.trim() ? { direction: before } : {}, signal);
    s.input.value = content;
    typed(s);
    if (before.trim()) {
      announce(improve ? wording("composer-message-improved") : wording("composer-message-written-for-you"), async () => {
        s.input.value = before;
        typed(s);
        offer(s, c);
      });
    }
  });
  if (done) s.input.focus();
}

/**
 * Has a picture made for the chat, of the words in the field or, without any, of the newest messages, which comes
 * as a message of the character who replies; the field's words, once in the picture, leave it. Stopped, or failing,
 * it leaves the field as it was.
 */
async function picture(s: Screen): Promise<void> {
  const words = s.input.value;
  if (!s.view) return;
  const speaker = s.view.chat.replier_id;
  await drafted(s, false, true, async (signal, mine) => {
    await makePicture(s.chatId, { ...(words.trim() && { words }), ...(speaker !== null && { speaker_id: speaker }) }, signal);
    if (s.input.value === words) {
      s.input.value = "";
      typed(s);
    }
    // Cleared before `load` draws, which would show Stop for a frame otherwise.
    if (s.drafting === mine) s.drafting = null;
    await load(s);
    toBottom(s);
  });
}

/**
 * Runs `work` as the screen's drafting (none starts while another runs or the chat is busy, and then it answers
 * false); a failure not stopped by the user is told. The drafting ends, and the screen is drawn, either way.
 */
async function drafted(s: Screen, improve: boolean, picture: boolean, work: (signal: AbortSignal, mine: Drafting) => Promise<void>): Promise<boolean> {
  const mine = startDrafting(s, improve, picture);
  if (!mine) return false;
  try {
    await work(mine.stop.signal, mine);
  } catch (error) {
    if (!mine.stop.signal.aborted) failed(s, error);
  } finally {
    if (s.drafting === mine) s.drafting = null;
    s.render();
  }
  return true;
}
