// The chat screen: the branch in view, a reply streaming in, a message's tools, who replies, the characters replying
// by themselves, the mode's pill, and the side panel. Bubbles, Plain and a narrow window draw the same parts, by
// styles.css alone. Its parts are in `web/src/chat/`: the shared state and its actions (screen.ts), the bar
// (header.ts), the messages (messages.ts), the field (composer.ts), the characters replying by themselves
// (talk.ts), the server's events (events.ts), the side panel (panel.ts) and the split view (split.ts); this file puts
// them together and draws. The split view and the side panel never show together: the split view, from 1200 px
// (`WIDE`), hides the panel while it shows, and the panel's button closes it (`showSides`).
//
// Traps: a tool's call that waits (`asking`) is tools.ts's card over the field. A reply that fails for want of a
// provider leads to first run (`unset`). A chat without a character is the AI itself: its replies under the model's
// name, no "Add a character", and its title, once it named itself, from `chat_title`. Leaving the chat ends what
// is written on its page's behalf (`leave`). Escape closes the panel where it lies over the chat, else lets a reply
// chosen go (`unchoose`), unless a tool's call waits, whose Deny it is.
import { showRound, watchAccount } from "../account";
import {
  addLorebook,
  answerTool,
  changeChat,
  changePersonality,
  createPersona,
  getChat,
  moveCharacter,
  removeCharacter,
  removeLorebook,
  setChatPromptPreset,
  setChatReply,
  setChatTalk,
  setLore,
  setPersona,
} from "../api/client";
import type { ChatView } from "../api/generated/ChatView";
import { codingOffered, composer, drawComposer, type Composer } from "../chat/composer";
import { onEvent } from "../chat/events";
import { drawHeader, header, type Header } from "../chat/header";
import { drawMessages, replierName } from "../chat/messages";
import { chatPanel, sourceOf, type ChatPanel, type PanelActions } from "../chat/panel";
import { act, atBottom, failed, branch, find, load, newScreen, newest, tell, toBottom, took, toolsNow, type Screen } from "../chat/screen";
import { splitView, type Split } from "../chat/split";
import { canTalk, end, halt, onward } from "../chat/talk";
import { el, escapeFree, failure, NARROW, TOUCH, WIDE, type View } from "../dom";
import { daysLeft } from "../format";
import { remember, remembered } from "../storage";
import { modeInUse } from "../card/modes";
import { foldFor } from "../shell/rail";
import { CHAT_VIEWS } from "../theme";
import { stopReading } from "../voice/voice";
import { askNode } from "../chat/tool-ask";
import { wording } from "../language/language";

/** Whether the side panel shows is kept under this name for the next start. */
const PANEL = "chat-panel";
/** Whether the split view is open is kept under this name for the next start. */
const SPLIT = "chat-split";

/** The screen's parts that its drawing reaches. */
interface Parts {
  header: Header;
  composer: Composer;
  panel: ChatPanel;
  split: Split;
  status: HTMLElement;
  branching: HTMLElement;
  inTrash: HTMLElement;
  /** The days left before the chat in the Trash is deleted for good. */
  trashLeft: HTMLElement;
  talking: HTMLElement;
  talkCount: HTMLElement;
  /** The notice of a tool's call over the field, and what it was drawn from. */
  ask: { node: HTMLElement; for: string };
  panelOpen: boolean;
  /** The split view chosen, and whether it shows (it needs a wide window and a character), which folds the rail. */
  splitOpen: boolean;
  splitShown: boolean;
}

/**
 * Whether a chat opens with its message field in focus: one the user has written nothing in yet, unless the focus
 * went somewhere while it was read, and not on a touch screen, whose keyboard would rise each time (Claude).
 */
export const opensWriting = (view: ChatView | null | undefined, active: Element | null, touch = TOUCH.matches) =>
  !touch && (active === null || active === document.body) && !view?.messages.some((m) => m.role === "user");

export function chatView(chatId: number): View {
  const s = newScreen(chatId);
  const talkCount = el("span");
  const trashLeft = el("span", { className: "meta" });
  const p: Parts = {
    header: header(),
    composer: composer(s),
    panel: chatPanel(panelActions(s, () => p)),
    split: splitView(s.node),
    status: el("div", { className: "note" }),
    branching: el(
      "p",
      { className: "note", hidden: true },
      wording("chat-your-next-message-starts"),
      el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: () => branch(s, null) }, wording("common-cancel")),
    ),
    inTrash: el("div", { className: "banner chat-wrap", role: "status", hidden: true }, el("span", null, wording("chat-this-chat-is-in")), trashLeft, el("button", { type: "button", className: "btn btn-secondary", onclick: () => void restore(s) }, wording("label-settings-restore"))),
    talking: el("p", { className: "note", hidden: true }, talkCount, el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: () => halt(s, true) }, wording("gen-stop"))),
    talkCount,
    trashLeft,
    ask: { node: el("div", { hidden: true }), for: "null" },
    panelOpen: !NARROW.matches && remembered(PANEL) !== "closed",
    splitOpen: remembered(SPLIT) === "open",
    splitShown: false,
  };
  s.render = () => render(s, p);
  s.onEvent = (event) => {
    // Dictation's model downloaded or removed: the microphone shows while it is there.
    if (event.type === "dictation") p.composer.dictate.read();
    onEvent(s, event);
  };
  const main = el("div", { className: "chat-main" }, p.header.node, s.scroller, p.status, p.branching, p.talking, p.ask.node, el("div", { className: "chat-dock" }, p.composer.form, p.inTrash));
  // Where the panel lies over the chat, a press on the chat closes it; its own button does that on its click.
  main.addEventListener("pointerdown", (event) => {
    if (NARROW.matches && p.panelOpen && !p.header.panelToggle.contains(event.target as Node)) showPanel(s, p, false);
  });
  s.node.append(main, p.panel.node, p.split.node);
  const toggle = p.header.panelToggle;
  toggle.onclick = () => {
    // The panel's button shows the panel where the split view hides it, closing the split view.
    const split = p.splitShown;
    if (split) splitTo(p, false);
    p.panelOpen = split || !p.panelOpen;
    // Over a narrow window's chat the panel is opened for the moment; that is not the choice kept.
    if (!NARROW.matches) remember(PANEL, p.panelOpen ? "open" : "closed");
    showSides(s, p);
  };
  p.header.splitToggle.onclick = () => (splitTo(p, !p.splitOpen), showSides(s, p));
  // The chat's menu adds a lorebook while the side panel shows no Lorebooks: it opens the panel and the part.
  p.header.lorebooks = {
    needed: () => !!s.view?.characters.length && !s.view.chat.trashed && (p.panel.node.hidden || !p.panel.lorebooksShown()),
    add: () => {
      if (p.panel.node.hidden) toggle.click();
      p.panel.addLorebook();
    },
  };
  p.split.close.onclick = () => {
    splitTo(p, false);
    showSides(s, p);
    p.header.splitToggle.focus();
  };
  const sides = () => showSides(s, p);
  WIDE.addEventListener("change", sides);
  showSides(s, p);
  // What the account is called, as it is known and after a rename: the rounds beside the user's messages of a chat
  // without a persona have its letter, until the chat is left.
  const left = watchAccount((now) => {
    s.account = now;
    p.composer.codingLine.hidden = !codingOffered(s);
    for (const own of s.node.querySelectorAll<HTMLElement>(".avatar.own:not(.of-persona)")) showRound(own, now);
  });
  void load(s).then(() => {
    toBottom(s);
    if (s.node.isConnected && opensWriting(s.view, document.activeElement)) s.input.focus();
  });
  const unchoose = (event: KeyboardEvent) => {
    // A chat in a tab out of view takes no key.
    if (!s.node.isConnected || !escapeFree(event) || s.asking) return;
    // Where the panel lies over the chat, Escape closes it first.
    if (NARROW.matches && !p.panel.node.hidden) {
      event.preventDefault();
      showPanel(s, p, false);
      p.header.panelToggle.focus();
      return;
    }
    if (s.chosen === null) return;
    event.preventDefault();
    s.chosen = null;
    s.render();
  };
  document.addEventListener("keydown", unchoose);
  const leave = () => {
    document.removeEventListener("keydown", unchoose);
    // The characters reply by themselves, and the model writes the user's message, only while their chat is in view.
    end(s);
    s.drafting?.stop.abort();
    stopReading();
    left();
    WIDE.removeEventListener("change", sides);
    if (p.splitShown) foldFor(false);
  };
  // What is being read may be from before the socket opened, so it is read again after.
  return { node: s.node, onEvent: s.onEvent, onConnected: () => {
    p.composer.dictate.read();
    void (s.loading ?? Promise.resolve()).then(() => load(s));
  }, left: leave, views: CHAT_VIEWS };
}

/** A chat in the Trash is only read: nothing is written into what is about to go. Restore takes it out. */
const restore = (s: Screen) =>
  act(s, async () => {
    await changeChat(s.chatId, { trashed: false });
    s.view = await getChat(s.chatId);
  });

function showPanel(s: Screen, p: Parts, open: boolean): void {
  const toggle = p.header.panelToggle;
  p.panelOpen = open;
  const shown = open && !p.splitShown;
  p.panel.node.hidden = !shown || !s.view;
  toggle.ariaPressed = String(shown);
  toggle.ariaLabel = toggle.title = shown ? wording("chat-hide-side-panel") : wording("chat-show-side-panel");
}

/** Opens or closes the split view, kept for the next start. */
function splitTo(p: Parts, open: boolean): void {
  p.splitOpen = open;
  remember(SPLIT, open ? "open" : "closed");
}

/**
 * Shows the split view where it is open, the window wide and the chat with a character, the side panel where the
 * split view does not show, and the split view's button where it could show; the rail is folded while it shows.
 */
function showSides(s: Screen, p: Parts): void {
  const characters = s.view?.characters ?? [];
  const can = WIDE.matches && characters.length > 0;
  const shown = can && p.splitOpen;
  if (shown !== p.splitShown) foldFor(shown);
  p.splitShown = shown;
  p.split.node.hidden = !shown;
  s.node.classList.toggle("with-split", shown);
  if (shown) p.split.show(characters, modeInUse(s.view!.chat, s.view!.modes));
  const toggle = p.header.splitToggle;
  toggle.hidden = !can;
  toggle.ariaPressed = String(shown);
  toggle.ariaLabel = toggle.title = shown ? wording("split-hide-card-editor") : wording("chat-show-card-editor");
  showPanel(s, p, p.panelOpen);
}

/** The side panel changes the chat through the same door as everything else here. */
function panelActions(s: Screen, parts: () => Parts): PanelActions {
  const chatId = s.chatId;
  /** Takes the chat's lorebooks as the server has them after a change to them. */
  const lorebooksAre = async (answer: Promise<ChatView["lorebooks"]>) => {
    const lorebooks = await answer;
    if (s.view) s.view.lorebooks = lorebooks;
  };
  const run = (action: () => Promise<void>) => act(s, action);
  return {
    close: () => {
      showPanel(s, parts(), false);
      parts().header.panelToggle.focus();
    },
    choosePromptPreset: (choice) => run(async () => took(s, await setChatPromptPreset(chatId, choice))),
    setReply: (reply) => run(async () => took(s, await setChatReply(chatId, reply))),
    // Not by `run`: the fields show while the characters reply by themselves, and a reply holds `run` while it is written.
    setTalk: async (talk) => {
      try {
        took(s, await setChatTalk(chatId, talk));
        // Drawn again, as `run` would: the notice counts against the new limit.
        s.render();
        return true;
      } catch (error) {
        failed(s, error);
        return false;
      }
    },
    choosePersona: (persona) => run(async () => took(s, await setPersona(chatId, persona?.id ?? null), persona)),
    addPersona: (name, description) =>
      run(async () => {
        const persona = await createPersona({ name, description });
        s.personas.push(persona);
        took(s, await setPersona(chatId, persona.id), persona);
      }),
    setLore: (lore, on) => run(() => lorebooksAre(setLore(chatId, { ...sourceOf(lore), reference: lore.reference, on }))),
    addCharacter: () => parts().composer.addLine.action(),
    removeCharacter: (character) =>
      run(async () => {
        s.view = await removeCharacter(character.id);
      }),
    moveCharacter: (character, position) =>
      run(async () => {
        s.view = await moveCharacter(character.id, { position });
      }),
    addLorebook: (lorebook) => run(() => lorebooksAre(addLorebook(chatId, { lorebook_id: lorebook.id }))),
    changePersonality: (change) =>
      run(async () => {
        s.personality = await changePersonality(chatId, change);
        await toolsNow(s);
      }),
    removeLorebook: (lorebookId) => run(() => lorebooksAre(removeLorebook(chatId, lorebookId))),
  };
}

function render(s: Screen, p: Parts): void {
  const stick = atBottom(s);
  const lead = s.unset ? wording("chat-set-up-a-model") : "";
  if (p.status.textContent !== s.notice + lead) p.status.replaceChildren(...(s.notice ? [failure(s.notice)] : []), ...(lead ? [el("a", { href: "#/setup" }, lead)] : []));
  p.composer.form.hidden = !s.view || s.view.chat.trashed;
  p.inTrash.hidden = !s.view?.chat.trashed;
  const deletedAt = s.view?.chat.deleted_at;
  if (deletedAt != null) p.trashLeft.textContent = wording("trash-days-left", { count: daysLeft(deletedAt) });
  p.header.tools.hidden = !s.view;
  showSides(s, p);
  const view = s.view;
  if (!view) return;
  if (s.branchAt !== null && (!find(s, s.branchAt) || s.branchAt === newest(s)?.id)) s.branchAt = null;
  if (s.editing && !find(s, s.editing.id)) s.editing = null;
  if (s.chosen !== null && !find(s, s.chosen)) s.chosen = null;
  drawHeader(s, p.header);
  p.panel.show({ view, personas: s.personas, library: s.library, prompts: s.prompts, personality: s.personality, locked: view.chat.trashed, talking: s.talk !== null, chosen: s.chosen });
  drawMessages(s);
  p.branching.hidden = s.branchAt === null;
  // The characters stop replying by themselves where they can no longer, as one was picked by hand.
  if (!canTalk(view)) end(s);
  p.talking.hidden = !s.talk;
  drawAsk(s, p);
  if (s.talk) p.talkCount.textContent = wording("chat-the-characters-keep-replying", { asked: s.talk.asked, talk_replies: view.chat.talk_replies });
  drawComposer(s, p.composer);
  if (stick) toBottom(s);
  onward(s);
}

/** The call of a tool the reply waits for, over the field; who wants it is the one whose reply is being written. */
function drawAsk(s: Screen, p: Parts): void {
  const now = JSON.stringify(s.asking);
  if (now === p.ask.for) return;
  p.ask.for = now;
  const shown = s.asking ? askNode(s.asking, replierName(s.view!, newest(s)), (allow, forChat) => answerTool(s.chatId, allow, forChat), (error) => tell(s, error)) : el("div", { hidden: true });
  p.ask.node.replaceWith(shown);
  p.ask.node = shown;
  p.composer.form.classList.toggle("waiting", s.asking !== null);
}
