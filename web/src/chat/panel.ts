// The chat's side panel, a part per function: in a personal mode the character's personality ("As an assistant":
// the tools it may use, which a press on "Tools" shows as switches, and whether it remembers; `personalPart`), who
// is in a chat of several characters (`castPart`), who the user is in the chat (`personaPart`), the prompt preset it
// goes by (`promptPart`), how its replies are written (`replyPart`: Reply length in five steps, greyed where not sent, and "Let the AI write tools" (Code mode); in a chat of several the pause between
// the characters' own replies and how many they write in a row, while they keep replying by themselves), the lorebooks its characters and their cards bring along, its persona's,
// those for every chat (each of these two saying so in grey after its name) and those it took from the library, which alone have a × (`lorebooksPart`), what the reply chosen with a click, or else the newest, was given, read and saved to
// memory, counting no tokens (`usedPart`, last), and before it the portrait (`portraitPart`). Lorebooks shows only
// where the chat has one, or once the chat's menu asked for it (`addLorebook`); "Used in last reply" where it used something.
//
// A chat's lorebook tells its entries' references, by which the panel knows what the chat can still leave out.
// "Characters" has a "+" that opens "Add a character", "In speaking order" under it, and a line per character, its
// round and name, with the "…" that moves it (`orderMenu`, "Options for Isolde"); it is hidden in a chat of one. A chat
// in the Trash has a grey line at the top saying why its controls are pale; Show portrait stays, as it changes no chat. The portrait is of the one who spoke last, or else of the one the chat
// began with (`firstJoined`; who said a message is `speakerOf`); where that one's card has an expression pack, the pack's picture of the newest
// reply's mood, which the server tells once the reply is complete. The panel begins with its name and the × that closes it (`.panel-close`), which show
// where it lies over the chat as a sheet. A chat without a character, the AI itself, has no persona, prompt preset,
// lorebooks or portrait (and Prompt preset hides while there is no preset to choose); it has the reply's box. A part is drawn anew only when what it shows changed (`draw`), keeping the focus.
import type { ChatCharacter } from "../api/generated/ChatCharacter";
import type { ChatLorebook } from "../api/generated/ChatLorebook";
import type { ChatView } from "../api/generated/ChatView";
import type { MessageView } from "../api/generated/MessageView";
import type { Lore } from "../api/generated/Lore";
import type { Lorebook } from "../api/generated/Lorebook";
import type { LoreSource } from "../api/generated/LoreSource";
import type { Persona } from "../api/generated/Persona";
import type { ChatPromptPreset } from "../api/generated/ChatPromptPreset";
import type { ChatReply } from "../api/generated/ChatReply";
import type { ChatTalk } from "../api/generated/ChatTalk";
import type { PromptPreset } from "../api/generated/PromptPreset";
import type { ChangePersonality } from "../api/generated/ChangePersonality";
import type { Personality } from "../api/generated/Personality";
import type { Tool } from "../api/generated/Tool";
import { toolNames } from "../card/modes";
import { messageExpression } from "../api/client";
import { closeButton, el, lineButton, selectField, switchBox } from "../dom";
import { isArt } from "../art";
import { menuOn, type MenuItem } from "../dialogs";
import { remember, remembered } from "../storage";
import { icon } from "../icons";
import { addLorebookMenu } from "../library/library-actions";
import { personaForm } from "../library/persona-form";
import { wording } from "../language/language";
import { comma } from "../format";
import { avatar } from "./pictures";

/** A lorebook or one of its entries, as its card or its lorebook of the library names it. */
type LoreRef = LoreSource & Pick<Lore, "reference" | "name">;

/**
 * The character a chat began with and is called after: the one that joined first, whose ID is the lowest, whatever
 * the speaking order.
 */
export function firstJoined(characters: ChatCharacter[]): ChatCharacter | undefined {
  return characters.reduce<ChatCharacter | undefined>((first, one) => (first && first.id < one.id ? first : one), undefined);
}

/** The character who said a message of `speaker` (its `speaker_id`): that one, else the one the chat began with. */
export const speakerOf = (characters: ChatCharacter[], speaker: number | null | undefined) => characters.find((character) => character.id === speaker) ?? firstJoined(characters);

/** What the panel asks of its chat. Each answers whether it was done. */
export interface PanelActions {
  /** Closes the panel, where it lies over the chat. */
  close(): void;
  /** Opens "Add a character", whose pick joins the chat. */
  addCharacter(): void;
  /** Takes a character that has written nothing out of the chat again. */
  removeCharacter(character: ChatCharacter): Promise<boolean>;
  /** Moves a character to another place in the chat's speaking order, 0 being the first. */
  moveCharacter(character: ChatCharacter, place: number): Promise<boolean>;
  /** Makes the user this persona in the chat, or nobody in particular. */
  choosePersona(persona: Persona | null): Promise<boolean>;
  /** Has the chat go by a prompt preset of its own, the card's own prompt, or the one in use on the page Advanced. */
  choosePromptPreset(choice: ChatPromptPreset): Promise<boolean>;
  /** Sets the chat's reply length and Code mode. */
  setReply(reply: ChatReply): Promise<boolean>;
  /** Sets the pause between the characters' own replies and how many they write in a row. */
  setTalk(talk: ChatTalk): Promise<boolean>;
  /** Adds a persona and makes the user it in the chat. */
  addPersona(name: string, description: string): Promise<boolean>;
  /** Leaves a lorebook or one of its entries out of the chat, or takes it back in. */
  setLore(lore: LoreRef, on: boolean): Promise<boolean>;
  /** Takes a lorebook of the library along in the chat. */
  addLorebook(lorebook: Lorebook): Promise<boolean>;
  /** Lets a lorebook of the library go from the chat. */
  removeLorebook(lorebookId: number): Promise<boolean>;
  /** Changes the personality of the chat's first character. */
  changePersonality(change: ChangePersonality): Promise<boolean>;
}

/** What the panel shows: the chat as it is now, with what it can be given. */
interface Shown {
  view: ChatView;
  personas: Persona[];
  library: Lorebook[];
  prompts: PromptPreset[];
  /** The character's personality, where its mode is personal. */
  personality: Personality | null;
  /** A chat in the Trash is only read. */
  locked: boolean;
  /** The characters keep replying by themselves (talk.ts): only then are their pause and count shown. */
  talking: boolean;
  /** The reply chosen with a click, whose "Used in this reply" shows in place of the newest's. */
  chosen: number | null;
}

export interface ChatPanel {
  node: HTMLElement;
  show(shown: Shown): void;
  /** Shows Lorebooks, though the chat has none, and opens its "Add lorebook" (the chat's menu's line). */
  addLorebook(): void;
  /** Whether Lorebooks shows, with its "Add lorebook". */
  lorebooksShown(): boolean;
}

/** A part of the panel: its node, and how it draws what the panel shows. */
interface Part {
  node: HTMLElement;
  show(shown: Shown): void;
}

/** Whether the portrait shows is kept under this name for the next start. */
const PORTRAIT = "chat-portrait";
/** The persona field's line for adding one. */
const NEW = "new";

/** What the persona field says of a persona beside its name. */
const mark = (persona: Persona) => (persona.trashed ? wording("panel-in-trash") : "");

/** Where lore is from, and nothing else of it. */
export const sourceOf = (lore: LoreSource): LoreSource =>
  "card_id" in lore ? { card_id: lore.card_id } : { lorebook_id: lore.lorebook_id };
/** The same in a word, to tell two apart. */
const from = (lore: LoreSource) => ("card_id" in lore ? `card ${lore.card_id}` : `lorebook ${lore.lorebook_id}`);
/** What the control of a lorebook or an entry is known by, to be found again when its part is drawn anew. */
const keyOf = (lore: LoreRef) => `${from(lore)} ${lore.reference}`;
const same = (a: LoreRef, b: LoreRef) => keyOf(a) === keyOf(b);
/** How many switches were made: each is told apart by its number, for its name to be tied to it. */
let switches = 0;

const part = (...children: HTMLElement[]) => el("div", { className: "panel-part flex f-col g-6" }, ...children);
/** A part's heading; the label of its field where `htmlFor` names one. */
const heading = (text: string, htmlFor?: string) => {
  const className = "panel-label fs-small semi m0";
  return htmlFor ? el("label", { className, htmlFor }, text) : el("h2", { className }, text);
};
const toggle = (on: boolean, off = false) => switchBox({ checked: on, disabled: off });
/** An entry of a lorebook in a line: what is said of it, and under that its name. */
const entryText = (about: string, lore: Lore) =>
  el("span", { className: "item-text" }, el("span", { className: "meta" }, about), el("span", { className: "entry-name fs-small lh-snug" }, lore.name));
/** The × that takes something out of the chat. */
const removeButton = (label: string, action: () => void) => lineButton(label, wording("panel-remove-from-this-chat"), "close", action);
/** The newest reply in view. */
const lastReply = (view: ChatView) => view.messages.filter((message) => message.role === "assistant").at(-1);

/** What each part was last drawn from: a part is drawn anew only when that changed. */
const drawn = new WeakMap<HTMLElement, string>();
/** Draws a part unless it shows `from` already. A control of it that had the focus has it afterwards. */
function draw(where: HTMLElement, from: unknown, rows: () => HTMLElement[]): void {
  const now = JSON.stringify(from);
  if (drawn.get(where) === now) return;
  drawn.set(where, now);
  const held = where.contains(document.activeElement) ? (document.activeElement as HTMLElement).dataset.key : undefined;
  where.replaceChildren(...rows());
  if (held !== undefined) [...where.querySelectorAll<HTMLElement>("[data-key]")].find((control) => control.dataset.key === held)?.focus();
}

export function chatPanel(actions: PanelActions): ChatPanel {
  const persona = personaPart(actions);
  const personal = personalPart(actions);
  const cast = castPart(actions, persona.field);
  /** The parts that are of the chat's characters, which a chat without a character does not show; Lorebooks hides itself. */
  const [prompt, lorebooks] = [promptPart(actions), lorebooksPart(actions)];
  const ofCharacters = [persona, prompt];
  const reply = replyPart(actions);
  const used = usedPart(actions);
  const portrait = portraitPart();
  const close = closeButton();
  close.onclick = () => actions.close();
  /** Why the controls of a chat in the Trash are pale. */
  const locked = el("p", { className: "meta m0", hidden: true }, wording("panel-in-trash-locked"));
  const node = el(
    "aside",
    { className: "side-panel chat-panel", ariaLabel: wording("panel-chat-details") },
    el("div", { className: "panel-close" }, close, el("h2", { className: "fs-title m0" }, wording("panel-chat-details"))),
    locked,
    personal.node,
    cast.node,
    persona.node,
    prompt.node,
    reply.node,
    lorebooks.node,
    portrait.node,
    used.node,
  );
  const parts = [personal, cast, ...ofCharacters, lorebooks, reply, used, portrait];
  return {
    addLorebook: lorebooks.add,
    lorebooksShown: () => !lorebooks.node.hidden,
    node,
    show(shown) {
      locked.hidden = !shown.locked;
      for (const one of [...ofCharacters, portrait]) one.node.hidden = !shown.view.characters.length;
      for (const one of parts) one.show(shown);
    },
  };
}

/** The character's personality, "As an assistant". There only in a personal mode. */
function personalPart(actions: PanelActions): Part {
  const rows = el("div", { className: "group" });
  const node = part(heading(wording("panel-as-an-assistant")), rows, el("p", { className: "meta" }, wording("panel-kept-with-the-character")));
  /** Whether the tools show as switches under "Tools". */
  const open = { tools: false };
  return {
    node,
    show({ personality, locked }) {
      node.hidden = personality === null;
      if (personality) draw(rows, [personality, locked, open.tools], () => personalRows(actions, rows, open, personality, locked));
    },
  };
}

/** The lines of a personality: "Tools" with those it may use, which a press shows as switches, and "Memory". */
function personalRows(actions: PanelActions, rows: HTMLElement, open: { tools: boolean }, personality: Personality, locked: boolean): HTMLElement[] {
  const { offered, tools_off: off, memory } = personality;
  const on = offered.filter((tool) => !off.includes(tool));
  const tools = el(
    "button",
    { type: "button", className: "item item-side row line", ariaExpanded: String(open.tools), disabled: locked },
    el("span", { className: "item-text" }, wording("tools-title")),
    el("span", { className: "meta" }, on.map((tool) => toolNames()[tool]).join(comma()) || wording("css-none")),
  );
  tools.dataset.key = "tools";
  tools.onclick = () => {
    open.tools = !open.tools;
    draw(rows, [personality, locked, open.tools], () => personalRows(actions, rows, open, personality, locked));
  };
  const switchLine = (name: string, checked: boolean, key: string, change: (on: boolean) => ChangePersonality) => {
    const control = toggle(checked, locked);
    control.id = `switch-${++switches}`;
    control.dataset.key = key;
    control.onchange = () => {
      control.checked = checked;
      void actions.changePersonality(change(!checked));
    };
    return el("div", { className: `item item-side${key.startsWith("tool-") ? " sub-item" : ""}` }, el("label", { className: "item-text", htmlFor: control.id }, name), control);
  };
  const toolOff = (tool: Tool) => (allowed: boolean) => ({ tools_off: allowed ? off.filter((one) => one !== tool) : [...off, tool] });
  return [
    tools,
    ...(open.tools ? offered.map((tool) => switchLine(toolNames()[tool], !off.includes(tool), `tool-${tool}`, toolOff(tool))) : []),
    switchLine(wording("panel-memory"), memory, "memory", (remembers) => ({ memory: remembers })),
  ];
}

/** Who is in the chat. There only in a chat of several characters; after a × the focus falls back on `after`. */
function castPart(actions: PanelActions, after: HTMLElement): Part {
  const cast = el("div", { className: "group" });
  const add = el("button", { type: "button", className: "quiet icon btn btn-quiet btn-icon btn-xs", ariaLabel: wording("add-character-add-a-character"), title: wording("add-character-add-a-character"), onclick: () => actions.addCharacter() }, icon("plus", 16));
  const head = el("div", { className: "panel-head gh m0" }, heading(wording("page-characters")), add);
  const node = part(head, el("p", { className: "meta m0" }, wording("panel-in-speaking-order")), cast);
  return {
    node,
    show({ view, locked }) {
      add.hidden = locked;
      const lines = view.characters.map((one) => [one.id, one.name, one.written, one.avatar_url]);
      // A chat keeps one character at least, and a chat of one does not show the part.
      const alone = view.characters.length < 2;
      draw(cast, [lines, locked], () => view.characters.map((one, at, all) => castRow(actions, cast, after, one, at, all.length, locked || alone)));
      node.hidden = alone;
    },
  };
}

/**
 * One of the chat's characters in a line. One that has written nothing has
 * the × that takes it out of the chat; a message is under the name of the
 * one who wrote it, so who has written stays. With `kept` the line has no ×
 * and no "…": the chat is only read, or this is its one character. `at` is
 * its place of `count` in the speaking order. No character is muted (second
 * review of the v4 boards, 2026-10-17).
 */
function castRow(actions: PanelActions, cast: HTMLElement, after: HTMLElement, one: ChatCharacter, at: number, count: number, kept: boolean): HTMLElement {
  const leave = async () => {
    // Its line is gone, and the focus with it: the part's first × has it then, or else the field under the part.
    if (await actions.removeCharacter(one)) (cast.querySelector<HTMLElement>(".leave") ?? after).focus();
  };
  const out = !one.written && !kept && removeButton(wording("panel-remove-from-this-chat-2", { name: one.name }), () => void leave());
  if (out) out.classList.add("leave");
  return el("div", { className: "item item-side-act row g-8" }, avatar(one), el("span", { className: "item-text" }, one.name), out, !kept && orderMenu(actions, cast, one, at, count));
}

/**
 * A character's "…", which shows while its line is pointed at: its place in the speaking order, one up or one
 * down. Afterwards the "…" of its line, in its new place, has the focus, so that it can be moved on.
 */
function orderMenu(actions: PanelActions, cast: HTMLElement, one: ChatCharacter, at: number, count: number): HTMLElement {
  const move = async (place: number) => {
    await actions.moveCharacter(one, place);
    cast.querySelector<HTMLElement>(`[data-key="order ${one.id}"]`)?.focus();
  };
  const lines: MenuItem[] = [];
  if (at > 0) lines.push({ label: wording("panel-move-up"), shape: "up", action: () => void move(at - 1) });
  if (at < count - 1) lines.push({ label: wording("panel-move-down"), shape: "down", action: () => void move(at + 1) });
  const button = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("panel-options-for", { name: one.name }) }, icon("more", 16));
  button.dataset.key = `order ${one.id}`;
  // The panel would cut a menu off at its edge: it places itself in the window, back from the button's right edge.
  const node = menuOn(button, lines, "end");
  node.classList.add("reveal");
  return node;
}

/** Who the user is in the chat, with "New persona…", which opens the form that adds one. */
function personaPart(actions: PanelActions): Part & { field: HTMLElement } {
  // The persona the chat has; the field shows nothing else until the server took a change.
  let chosen = "";
  /** The personas the field offers: those in plain view, and the chat's own wherever it is. */
  let offered: Persona[] = [];
  const persona = selectField([], "", (picked) => {
    persona.value = chosen;
    if (picked === NEW) adding(true);
    else void actions.choosePersona(offered.find((one) => String(one.id) === picked) ?? null);
  }, { id: "chat-persona" });
  const { node: form, name } = personaForm(actions.addPersona, () => adding(false), null);
  form.hidden = true;
  function adding(now: boolean): void {
    form.hidden = !now;
    if (now) name.focus();
    else form.reset();
  }
  return {
    node: part(heading(wording("trash-persona"), persona.field.id), el("p", { className: "meta m0" }, wording("panel-who-you-are-in-this-chat")), persona.node, form),
    field: persona.field,
    show({ view, personas, locked }) {
      chosen = String(view.chat.persona_id ?? "");
      const own = view.persona;
      offered = own && !personas.some((one) => one.id === own.id) ? [...personas, own] : personas;
      // One in the Trash stays the chat's until it is gone for good, but is not chosen anew.
      persona.offer([
        { value: "", label: wording("panel-user") },
        ...offered.map((one) => ({ value: String(one.id), label: one.name + mark(one), off: one.trashed, sub: one.is_default ? wording("panel-persona-default") : undefined })),
        { value: NEW, label: wording("panel-new-persona") },
      ]);
      persona.value = chosen;
      persona.field.disabled = locked;
    },
  };
}

/**
 * The prompt preset the chat goes by: "settings", "card" or a preset's number, as the field's values. Hidden while
 * the account has no preset besides Default and the chat goes by Settings: there is nothing to choose then.
 */
function promptPart(actions: PanelActions): Part {
  let goesBy = "settings";
  const prompt = selectField([], goesBy, (picked) => {
    prompt.value = goesBy;
    void actions.choosePromptPreset(picked === "settings" || picked === "card" ? picked : { preset: Number(picked) });
  }, { id: "chat-prompt-preset" });
  const node = part(heading(wording("page-prompt-preset"), prompt.field.id), prompt.node);
  return {
    node,
    show({ view, prompts, locked }) {
      const choice = view.chat.prompt_preset;
      goesBy = typeof choice === "string" ? choice : String(choice.preset);
      if (!prompts.length && goesBy === "settings") node.hidden = true;
      const inUse = prompts.find((one) => one.in_use)?.name ?? wording("prompt-default");
      prompt.offer([
        { value: "settings", label: wording("panel-from-settings", { inUse }) },
        { value: "card", label: wording("panel-default-the-characters-own") },
        ...prompts.map((one) => ({ value: String(one.id), label: one.name })),
      ]);
      prompt.value = goesBy;
      prompt.field.disabled = locked;
    },
  };
}

/**
 * Whether the chat's Reply length is sent with a reply, and what its line says: not where the model thinks, which
 * wins, nor where a tool is offered (one besides Code mode's, `tools`, as the server tells, or Code mode).
 */
export function replyLengthNote(thinks: boolean, tools: boolean, codeMode: boolean): { used: boolean; says: string } {
  if (thinks) return { used: false, says: wording("panel-not-used-this-model") };
  if (tools || codeMode) return { used: false, says: wording("panel-not-used-while-a") };
  return { used: true, says: wording("panel-tokens-per-reply") };
}

/** Reply length's five named steps and their tokens, as the old Cardwave had them (the owner, 2026-10-22). */
export const replySteps = () => ([[wording("panel-very-short"), 80], [wording("panel-short"), 180], [wording("panel-medium"), 350], [wording("panel-long"), 750], [wording("panel-very-long"), 1500]] as const);

/** The place among `replySteps()` of the step nearest a length in tokens, the shorter where two are as near. */
export function replyStep(tokens: number): number {
  let best = 0;
  replySteps().forEach(([, step], at) => {
    if (Math.abs(step - tokens) < Math.abs(replySteps()[best][1] - tokens)) best = at;
  });
  return best;
}

/**
 * "Reply length", a slider of `replySteps()` whose line says the step ("Medium · 350"), with its note; `onStep` gets
 * the tokens of a step let go (or an arrow key pressed). `atStep` draws it at the step nearest some tokens, `noted`
 * says whether the length is used, greyed with its step kept where not, and whether it can be moved.
 */
function lengthSlider(onStep: (tokens: number) => void) {
  const length = el("input", { id: "chat-reply-length", type: "range", min: "0", max: String(replySteps().length - 1), step: "1" });
  const stepSays = el("span", { className: "step-says fs-small nowrap" });
  // The track, blue up to the knob, and a dot per step, under the slider, whose own track is clear.
  const dots = replySteps().map(() => el("span", { className: "dot" }));
  const slider = el("div", { className: "steps" }, el("span", { className: "trk" }), el("span", { className: "fil" }), el("div", { className: "steps-row" }, ...dots), length);
  // The ends' names under it, so the steps between are seen before the knob is moved.
  const ends = el("div", { className: "ticks", ariaHidden: "true" }, el("span", {}, replySteps()[0][0]), el("span", {}, replySteps()[replySteps().length - 1][0]));
  const lengthNote = el("span", { className: "meta" });
  /** Draws the slider at the step nearest `tokens`: its knob, the blue up to it, and the step's words. */
  const atStep = (tokens: number) => {
    const at = replyStep(tokens);
    const says = `${replySteps()[at][0]} · ${replySteps()[at][1]}`;
    length.value = String(at);
    dots.forEach((dot, place) => dot.classList.toggle("past", place < at));
    length.setAttribute("aria-valuetext", (stepSays.textContent = says));
    slider.style.setProperty("--at", String(at / (replySteps().length - 1)));
  };
  // The words follow the knob while it moves.
  length.oninput = () => atStep(replySteps()[Number(length.value)][1]);
  length.onchange = () => onStep(replySteps()[Number(length.value)][1]);
  const node = el("div", { className: "item item-stack reply-steps" }, el("div", { className: "steps-head flex jc-sb g-8" }, el("label", { className: "item-text", htmlFor: length.id }, el("span", { className: "item-label" }, wording("panel-reply-length")), lengthNote), stepSays), slider, ends);
  return {
    node,
    atStep,
    /** Whether the slider is being moved, under the pointer or the arrow keys, and so not drawn back. */
    moving: () => document.activeElement === length,
    noted(used: boolean, says: string, locked: boolean) {
      lengthNote.textContent = says;
      length.disabled = locked || !used;
      stepSays.classList.toggle("c-grey", !used);
    },
  };
}

/**
 * How the chat's replies are written: "Reply length" (`lengthSlider`), greyed where it is not sent (`replyLengthNote`), and the switch "Let the AI write tools" (Code mode);
 * in a chat of several "Pause between replies" in seconds and "Replies in a row", which the characters keep to while
 * they reply by themselves. A number is taken when its field is left or Enter pressed; what is no whole number of at
 * least `least`, or what the server refuses, goes back to what it holds.
 */
function replyPart(actions: PanelActions): Part {
  const number = (id: string) => el("input", { id, type: "text", inputMode: "numeric", className: "reply-length field", autocomplete: "off" });
  const slider = lengthSlider((tokens) => void (tokens !== now.reply_length && send({ reply_length: tokens })));
  const pause = number("chat-talk-pause");
  const replies = number("chat-talk-replies");
  const code = toggle(false);
  code.id = "chat-code-mode";
  let now: ChatReply = { reply_length: 350, code_mode: false };
  let talk: ChatTalk = { talk_pause: 4, talk_replies: 10 };
  // Whether the model thinks and a tool besides Code mode's is on, and whether the chat is in the Trash.
  let limit = { thinks: false, tools: false, locked: false };
  /** Tells whether the length is used, at once after Code mode is switched. */
  const noted = () => {
    const { used, says } = replyLengthNote(limit.thinks, limit.tools, now.code_mode);
    slider.noted(used, says, limit.locked);
  };
  const back = () => {
    slider.atStep(now.reply_length);
    pause.value = String(talk.talk_pause);
    replies.value = String(talk.talk_replies);
    code.checked = now.code_mode;
    noted();
  };
  // One change after the other, each on what the one before set, so a field left while the one before is on its
  // way is not lost. One not done (the chat busy with a reply, or the server refusing) gives back what was held
  // before it, unless a newer change was held since, and draws that.
  let queue = Promise.resolve();
  const later = (step: () => Promise<boolean>, undo: () => void) => void (queue = queue.then(step).then((done) => void (done || (undo(), back()))));
  // What is sent is held at once, so the next change is weighed against it.
  const send = (change: Partial<ChatReply>) => {
    const before = now;
    const to = (now = { ...now, ...change });
    later(() => actions.setReply(to), () => void (now === to && (now = before)));
  };
  const sendTalk = (change: Partial<ChatTalk>) => {
    const before = talk;
    const to = (talk = { ...talk, ...change });
    later(() => actions.setTalk(to), () => void (talk === to && (talk = before)));
  };
  /** Has the field take a whole number of at least `least`, sent by `take` where it changed. */
  const taking = (field: HTMLInputElement, least: number, held: () => number, take: (n: number) => void) => {
    field.onchange = () => {
      const n = wholeNumber(field.value, least);
      if (n === null) return back();
      if (n !== held()) take(n);
    };
  };
  taking(pause, 0, () => talk.talk_pause, (n) => sendTalk({ talk_pause: n }));
  taking(replies, 1, () => talk.talk_replies, (n) => sendTalk({ talk_replies: n }));
  code.onchange = () => {
    code.checked = now.code_mode;
    send({ code_mode: !now.code_mode });
    noted();
  };
  const line = (control: HTMLInputElement, label: string, says: string | HTMLElement) =>
    el("div", { className: "item item-side" }, el("label", { className: "item-text", htmlFor: control.id }, el("span", { className: "item-label" }, label), typeof says === "string" ? el("span", { className: "meta" }, says) : says), control);
  const ofSeveral = [line(pause, wording("panel-pause-between-replies"), wording("panel-seconds-when-they-reply")), line(replies, wording("panel-replies-in-a-row"), wording("panel-by-themselves-then-they"))];
  const node = part(
    el(
      "div",
      { className: "group" },
      slider.node,
      line(code, toolNames().code, wording("panel-small-tools-then-kept")), ...ofSeveral),
  );
  return {
    node,
    show({ view, locked, talking }) {
      now = { reply_length: view.chat.reply_length, code_mode: view.chat.code_mode };
      talk = { talk_pause: view.chat.talk_pause, talk_replies: view.chat.talk_replies };
      for (const [field, value] of [[pause, talk.talk_pause], [replies, talk.talk_replies]] as const) {
        if (document.activeElement !== field) field.value = String(value);
      }
      // As the fields, the slider being moved is not drawn back.
      if (!slider.moving()) slider.atStep(now.reply_length);
      code.checked = now.code_mode;
      for (const one of ofSeveral) one.hidden = view.characters.length < 2 || !talking;
      code.disabled = pause.disabled = replies.disabled = locked;
      limit = { thinks: view.thinks, tools: view.tools, locked };
      noted();
    },
  };
}

/** The whole number of at least `least` written in digits alone, spaces around them aside; else `null`. */
export function wholeNumber(text: string, least: number): number | null {
  const digits = text.trim();
  if (!/^\d+$/.test(digits)) return null;
  const n = Number(digits);
  return n >= least ? n : null;
}

/**
 * The chat's lorebooks, each with its switch, and "Add lorebook" with the library's it does not have yet. A chat
 * without a character, or without a lorebook, shows none of it, until `add` asks for it while the chat is open.
 */
function lorebooksPart(actions: PanelActions): Part & { add(): void } {
  const lorebooks = el("div", { className: "group" });
  /** Asked for by the chat's menu: it shows though the chat has no lorebook. */
  let asked = false;
  const none = el("p", { className: "meta" }, wording("panel-the-characters-bring-none"));
  /** The place of "Add lorebook", which is made anew when what it offers changes. */
  const addPlace = el("span");
  const take = async (lorebook: Lorebook) => {
    // The menu is made anew with what is left to take; its button has the focus again.
    if (await actions.addLorebook(lorebook)) addPlace.querySelector("button")?.focus();
  };
  const node = part(el("div", { className: "panel-head gh m0" }, heading(wording("page-lorebooks")), addPlace), lorebooks, none);
  return {
    node,
    add() {
      asked = true;
      node.hidden = false;
      addPlace.querySelector("button")?.click();
    },
    show({ view, library, locked }) {
      node.hidden = !view.characters.length || (!view.lorebooks.length && !asked);
      draw(lorebooks, [view.lorebooks, locked], () => view.lorebooks.flatMap((book) => lorebookRows(actions, book, locked)));
      lorebooks.hidden = view.lorebooks.length === 0;
      none.hidden = !lorebooks.hidden;
      // Offered are the library's lorebooks in plain view that the chat does not have yet, by itself or through a card.
      const had = view.lorebooks.map(from);
      const toTake = library.filter((lorebook) => !had.includes(from({ lorebook_id: lorebook.id })));
      draw(addPlace, [toTake.map((lorebook) => [lorebook.id, lorebook.name]), locked], () =>
        locked ? [] : [small(addLorebookMenu(toTake, (lorebook) => void take(lorebook)), wording("panel-add-lorebook-to-chat"))],
      );
    },
  };
}

/**
 * A lorebook's switch, and under it the entries the chat has left out, each
 * with the way back. A lorebook the chat took from the library can be let
 * go; one that is a character's, or attached to its card, comes with the
 * character.
 */
function lorebookRows(actions: PanelActions, book: ChatLorebook, locked: boolean): HTMLElement[] {
  const on = toggle(book.on, locked);
  on.id = `chat-lorebook-${++switches}`;
  on.title = wording("panel-use-in-this-chat");
  on.dataset.key = keyOf(book);
  // The switch moves once the server has taken the change.
  on.onchange = () => {
    on.checked = book.on;
    void actions.setLore(book, !book.on);
  };
  const leftOut = (lore: Lore) => {
    const back = el("button", { type: "button", className: "textbtn", ariaLabel: wording("panel-put-back-2", { name: lore.name }), disabled: locked }, wording("panel-restore"));
    back.dataset.key = keyOf(lore);
    back.onclick = () => void actions.setLore(lore, true);
    return el("div", { className: "item item-side-act entry" }, entryText(wording("panel-left-out"), lore), back);
  };
  const { why, own } = bookSays(book);
  const name = el("label", { className: "item-text", htmlFor: on.id }, book.trashed && el("span", { className: "meta" }, wording("panel-in-trash-2")), book.name, why && " ", why && el("span", { className: "meta" }, why));
  const letGo = own !== null && !locked && removeButton(wording("panel-remove-lorebook-from-this", { name: book.name }), () => void actions.removeLorebook(own));
  // A line ending in a switch, as the panel's others: its switch stands as far in as theirs.
  return [el("div", { className: "item item-side row g-8" }, name, letGo, on), ...book.removed.map(leftOut)];
}

/**
 * What a lorebook's line says in grey after its name, "persona" or "every chat", which are taken off where they are
 * set, and the lorebook the chat took itself, which its × lets go: also one of the persona's or for every chat, so
 * that what the user added stays the user's to take off (the line stays while the other holds it).
 */
export function bookSays(book: ChatLorebook): { why: string | null; own: number | null } {
  const why = book.persona ? wording("panel-book-persona") : book.everywhere ? wording("panel-book-every-chat") : null;
  return { why, own: book.taken && "lorebook_id" in book ? book.lorebook_id : null };
}

/**
 * "Used in last reply", or "Used in this reply" for a reply chosen with a click: the lorebook entries it was given
 * (those the chat has left out since aside), the pages and files it read and what was saved to memory from it; it counts
 * no tokens, which the reply's statistics do (stats.ts).
 */
function usedPart(actions: PanelActions): Part {
  const title = heading(wording("panel-used-in-last-reply"));
  const used = el("div", { className: "group" });
  // How to see another reply's, while the part shows the newest's.
  const hint = el("p", { className: "meta m0" }, wording("panel-click-a-reply"));
  const node = part(title, hint, used);
  return {
    node,
    show({ view, locked, chosen }) {
      title.textContent = chosen === null ? wording("panel-used-in-last-reply") : wording("panel-used-in-this-reply");
      hint.hidden = chosen !== null;
      const reply = view.messages.find((message) => message.id === chosen) ?? lastReply(view);
      const removed = view.lorebooks.flatMap((book) => book.removed);
      const entries = (reply?.lore ?? []).filter((lore) => !removed.some((gone) => same(gone, lore)));
      // An entry the chat no longer has (it let the lorebook go, or is with a version of the card without it)
      // can no longer be left out of it.
      const has = (lore: Lore) => view.lorebooks.some((book) => from(book) === from(lore) && book.entries.includes(lore.reference));
      const kept = entries.map((lore) => !locked && has(lore));
      const rest = reply ? usedFacts(reply) : [];
      // An entry is named with its lorebook, which the chat may no longer have.
      const books = entries.map((lore) => view.lorebooks.find((book) => from(book) === from(lore) && book.entries.includes(lore.reference))?.name);
      draw(used, [entries, kept, rest, books], () => [...entries.map((lore, at) => usedRow(actions, lore, kept[at], books[at])), ...rest.map(factRow)]);
      // Where the reply used nothing, the part does not show.
      node.hidden = entries.length === 0 && rest.length === 0;
    },
  };
}

/** A line of "Used in this reply" besides its lorebook entries: what it is, and under that each of them. */
type Fact = { about: string; lines: string[] };

/** What a reply read and what was saved to memory from it. */
export function usedFacts(reply: MessageView): Fact[] {
  const pages = reply.reads.flatMap((read) => (read.kind === "web" ? [pageLine(read.title, read.address)] : []));
  const files = reply.reads.flatMap((read) => (read.kind === "file" ? [read.path] : []));
  const facts: Fact[] = [];
  if (pages.length) facts.push({ about: wording("panel-read-on-the-web"), lines: pages });
  if (files.length) facts.push({ about: wording("panel-read-from-your-files"), lines: files });
  if (reply.memories.length) facts.push({ about: wording("panel-saved-to-memory"), lines: reply.memories });
  return facts;
}

/** A page read as "[title] · [site]", or its address where it has no title. */
function pageLine(title: string, address: string): string {
  let site = address;
  try {
    site = new URL(address).hostname.replace(/^www\./, "");
  } catch {
    // Not an address the browser reads: it shows as it is.
  }
  return title ? `${title} · ${site}` : address;
}

function factRow(fact: Fact): HTMLElement {
  return el("div", { className: "item item-side-act entry" }, el("span", { className: "item-text" }, el("span", { className: "meta" }, fact.about), ...fact.lines.map((line) => el("span", { className: "entry-name fs-small lh-snug" }, line))));
}

/** One thing the last reply was given, with the way to keep it out of the chat from now on where there is one. */
function usedRow(actions: PanelActions, lore: Lore, removable: boolean, book?: string): HTMLElement {
  return el(
    "div",
    { className: "item item-side-act row entry used g-8 ai-s" },
    entryText(book ? wording("panel-entry-of", { lorebook: book }) : wording("page-lorebook"), lore),
    removable && removeButton(wording("panel-remove-from-this-chat-2", { name: lore.name }), () => void actions.setLore(lore, false)),
  );
}

/**
 * "Show the character's picture" and the portrait of the one who spoke last, or else of the one the chat began with; where its
 * card has an expression pack, the picture of the newest reply's mood in its place, asked for while it shows.
 */
function portraitPart(): Part {
  const showPortrait = toggle(remembered(PORTRAIT) === "on");
  const portrait = el("img", { className: "portrait", alt: "", hidden: true });
  const noPortrait = el("p", { className: "meta", hidden: true }, wording("panel-this-character-has-no"));
  /** The picture the portrait was last given, and whether it is art. */
  let pictured: { url: string; art: boolean | null } = { url: "", art: null };
  const framed = () => {
    portrait.hidden = !showPortrait.checked || pictured.art !== true;
    noPortrait.hidden = !showPortrait.checked || pictured.art !== false;
  };
  const judged = (art: boolean) => {
    pictured.art = art;
    framed();
  };
  portrait.onload = () => judged(isArt(portrait));
  portrait.onerror = () => judged(false);
  /** The view last shown, the reply whose mood was asked for (its id and words) and the picture it has. */
  let last: ChatView | null = null;
  let asked = "";
  let expression: string | null = null;
  const picture = (view: ChatView) => {
    const reply = lastReply(view);
    const speaker = speakerOf(view.characters, reply?.speaker_id);
    const key = reply?.complete && showPortrait.checked ? `${reply.id}:${reply.content}` : "";
    if (key !== asked) {
      asked = key;
      expression = null;
      if (reply && key)
        void messageExpression(reply.id).then(
          ({ url }) => {
            if (asked !== key || !url || !last) return;
            expression = url;
            picture(last);
          },
          // The plain portrait shows, then.
          () => undefined,
        );
    }
    const url = expression ?? speaker?.avatar_url ?? "";
    if (url !== pictured.url) {
      pictured = { url, art: url ? null : false };
      portrait.alt = speaker?.name ?? "";
      if (url) portrait.src = url;
      else portrait.removeAttribute("src");
    }
    framed();
  };
  showPortrait.onchange = () => {
    remember(PORTRAIT, showPortrait.checked ? "on" : "off");
    if (last) picture(last);
    else framed();
  };
  const line = el("div", { className: "group" }, el("label", { className: "item item-side" }, el("span", { className: "item-text" }, el("span", { className: "item-label" }, wording("panel-show-portrait")), el("span", { className: "meta" }, wording("panel-portrait-beside"))), showPortrait));
  return {
    node: part(line, portrait, noPortrait),
    show({ view }) {
      last = view;
      picture(view);
    },
  };
}

/** A menu whose button is the small one the board Chat's side panel draws (`btn-xs`), named `label` there. */
function small(menu: HTMLElement, label: string): HTMLElement {
  const button = menu.querySelector("button");
  button?.classList.add("btn-xs");
  if (button) button.title = button.ariaLabel = label;
  return menu;
}
