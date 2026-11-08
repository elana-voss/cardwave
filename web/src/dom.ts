// The parts of a page, built without a framework; each says on itself what it does. The menus and dialogs are in
// dialogs.ts, what is written how in format.ts, what the browser keeps and saves in storage.ts.
//
// What is here: `View`, a screen, with what main.ts tells it; `el`; what went wrong (`told`, `reason`, `failure`)
// and `oneAtATime`, which runs a screen's actions and shows why one failed in `noticeBox`; the readings of a list
// (`latest`, `newest`); `announce`, the notice at the bottom with "Undo", and `copyText`, which says so; `titled`,
// which names a screen's tab; the small parts (`iconButton`, `lineButton`, `segmented`, `savedChoice`, `searchField`, `suggest`,
// `selectField`, the app's own select, `typingDots`, `pill`, `closeButton`, `item`, `tabs`, `changesBar`, `fileField`, `atMost`),
// a settings page's `group`; the window's width (`SMALL`, 600 px or less, `NARROW`, 960 px or less, `WIDE`, 1200 px
// or more).
//
// Escape closes one thing at a time: what takes it calls `preventDefault`, and a listener on the document asks
// `escapeFree` first.
//
// Traps: `suggest` asks what it offers with what the user typed, so a value put into the field otherwise narrows nothing.
import type { ServerEvent } from "./api/generated/ServerEvent";
import { icon, type IconName } from "./icons";
import { after, type MenuItem, menuOn } from "./dialogs";
import { wording } from "./language/language";

/** One screen in the main area. */
export interface View {
  node: HTMLElement;
  /** Called for every server event while the screen is shown. */
  onEvent?(event: ServerEvent): void;
  /** Called when the event socket has opened, at first or after a drop: what happened before was not told. */
  onConnected?(): void;
  /** Does what "Create" leads to the screen for: it asks for the files to import, or opens the form for a new item. */
  create?(): void;
  /** Called when another screen takes this one's place: what it watched outside itself is let go. */
  left?(): void;
  /**
   * Called when the address has changed: answers whether the screen shows the
   * new address itself, as another part of what it holds. It stays then, and
   * no screen is made.
   */
  moved?(): boolean;
  /** The ways the screen is shown, for the title bar's view menu (shell/view-menu.ts); a screen of one has none. */
  views?: PageViews;
}

/** A screen's views: each one's name and words, the one in use, and what shows another at once. */
export interface PageViews {
  list: [name: string, words: string][];
  now(): string;
  choose(name: string): void;
}

export type Child = Node | string | null | false | undefined;

/** Creates an element, sets its properties and appends its children. */
export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props: Partial<HTMLElementTagNameMap[K]> | null = null,
  ...children: Child[]
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (props) Object.assign(node, props);
  node.append(...children.filter((child): child is Node | string => child != null && child !== false));
  return node;
}

/**
 * A group of a settings page (`section.settings-group`): its name, where it has one, with `head` at its right
 * (`.gh`, the design system's group head), then what it holds, its lines in a `.group` of the caller's.
 */
export function group(title: string | null, head: Child, ...content: Child[]): HTMLElement {
  const name = title === null ? null : el("div", { className: head ? "gh group-head" : "gh" }, el("h2", null, title), head);
  return el("section", { className: "settings-group flex f-col g-8" }, name, ...content);
}

/**
 * Whether an Escape is still free for a listener on the document: no menu, field or window took it before (each
 * that does calls `preventDefault`), and no dialog is open, which takes it itself. So Escape closes one thing at a
 * time, the one on top, as a back button does, and never the app; who takes it calls `preventDefault` too.
 */
export const escapeFree = (event: KeyboardEvent) => event.key === "Escape" && !event.isComposing && !event.defaultPrevented && !document.querySelector("dialog[open]");

/** A line saying what went wrong, which a screen reader reads out at once. */
export const failure = (text: string) => el("p", { className: "error c-danger m0", role: "alert" }, text);

/** What went wrong, in the words it came with, to stand behind what was tried. */
export const told = (error: unknown) => (error instanceof Error ? error.message : String(error));

/** What went wrong, as a sentence for the user. */
export function reason(error: unknown): string {
  const text = told(error);
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/**
 * Makes the runner of a screen's actions: one at a time, so that a second click
 * does not do the same thing twice, and with the reason in `notice` when one
 * fails. The reason stands there until the next action starts. The runner
 * answers whether the action was done.
 */
export function oneAtATime(notice: HTMLElement): (action: () => Promise<void>, name?: string) => Promise<boolean> {
  let busy = false;
  let failed: HTMLElement | null = null;
  return async (action, name) => {
    if (busy) return false;
    busy = true;
    failed?.remove();
    let done = true;
    try {
      await action();
    } catch (error) {
      failed = failure(name ? wording("dom-text", { name, reason: reason(error) }) : reason(error));
      notice.replaceChildren(failed);
      done = false;
    }
    busy = false;
    return done;
  };
}

/** The place where why something failed stands, above what it is about (`oneAtATime`, `latest`); screen readers hear it. */
export const noticeBox = () => el("div", { className: "note", role: "status" });

/**
 * Numbers a screen's readings of one thing, so that an answer that comes late is not taken over a newer one:
 * `ask` gives a reading its number as it is sent, and `take` answers whether its answer is still to be taken
 * (none of a reading sent after it was taken), and notes it taken. `take()` without a number is the screen's own
 * store being taken, which every reading sent before it is older than.
 */
export function newest(): { ask(): number; take(mine?: number): boolean } {
  let asked = 0;
  let taken = 0;
  return {
    ask: () => ++asked,
    take(mine = ++asked) {
      if (mine < taken) return false;
      taken = mine;
      return true;
    },
  };
}

/**
 * Makes the reader of a screen's list. `read` asks the server and `show` is
 * given its answer, but only the answer to the last request: one that comes
 * late never replaces a newer one. Why a list could not be read stands in
 * `notice` until one is read, as `said` words it.
 */
export function latest<T>(
  notice: HTMLElement,
  read: () => Promise<T>,
  show: (answer: T) => void,
  said: (error: unknown) => HTMLElement = (error) => failure(reason(error)),
): () => Promise<void> {
  let request = 0;
  let unread: HTMLElement | null = null;
  return async () => {
    const mine = ++request;
    try {
      const answer = await read();
      if (mine !== request) return;
      unread?.remove();
      show(answer);
    } catch (error) {
      if (mine !== request) return;
      unread = said(error);
      notice.replaceChildren(unread);
    }
  };
}

/**
 * `run`, at most one at a time: a call while one runs asks for one more run after it, however many calls come, and
 * waits for that. So 500 cards imported, each an event, read the list a few times, not 500.
 */
export function coalesced(run: () => Promise<void>): () => Promise<void> {
  let running: Promise<void> | null = null;
  let next: Promise<void> | null = null;
  const start = (): Promise<void> => (running = run().finally(() => (running = null)));
  return () => {
    if (!running) return start();
    next ??= running.then(
      () => ((next = null), start()),
      () => ((next = null), start()),
    );
    return next;
  };
}

/** The window in which the rail is a bar on top, and a screen's tools stand under its search; styles.css draws it so from the same width on. */
export const SMALL = matchMedia("(max-width: 600px)");

/** The window in which a panel has no room beside its page: a chat's side panel lies over the chat, and a lorebook's entries are a screen of their own; styles.css draws it so from the same width on. */
export const NARROW = matchMedia("(max-width: 960px)");
/** A window of 1200 px or more, which has the chat's split view. */
export const WIDE = matchMedia("(min-width: 1200px)");
/** A screen worked by touch, where nothing is pointed at: what shows on hover shows there always. */
export const TOUCH = matchMedia("(hover: none)");

/** Three dots that rise in turn, `label` for who cannot see them: words are on their way and none have come. */
export const typingDots = (label: string): HTMLElement => el("span", { className: "typing", role: "status", ariaLabel: label }, el("i"), el("i"), el("i"));

/** How long typing must pause before a list is searched, in milliseconds. */
const TYPING_PAUSE = 200;

/**
 * A search field named `label`. What is typed is kept in `asked.q` at once;
 * `search` is called when the typing has paused, unless the screen was left
 * in the meantime.
 */
export function searchField(label: string, placeholder: string, asked: { q: string }, search: () => void, kind = ""): HTMLElement {
  const input = el("input", { type: "search", placeholder, value: asked.q });
  const node = el("label", { className: `field search ${kind}`.trim() }, icon("search", 16), el("span", { className: "sr visually-hidden" }, label), input);
  let typing = 0;
  input.oninput = () => {
    asked.q = input.value;
    clearTimeout(typing);
    typing = window.setTimeout(() => {
      if (node.isConnected) search();
    }, TYPING_PAUSE);
  };
  return node;
}

/**
 * Buttons side by side as one control named `label`; the pressed one is the
 * choice made. `choose` is told a new choice, and refuses it by answering
 * false, which leaves the one before pressed. An option with an icon shows
 * that, and has its text as its name.
 */
export function segmented<T>(
  label: string,
  options: [value: T, text: string, shape?: IconName][],
  chosen: T,
  choose: (value: T) => boolean | void,
): HTMLElement {
  const buttons = options.map(([value, text, shape]) =>
    el(
      "button",
      { type: "button", className: shape ? "icon btn btn-icon" : "btn", onclick: () => press(value), ...(shape && { ariaLabel: text, title: text }) },
      shape ? icon(shape, 16) : text,
    ),
  );
  const mark = (now: T) => options.forEach(([value], at) => (buttons[at].ariaPressed = String(value === now)));
  // A choice that `choose` refuses (it answers false) leaves the one before chosen.
  const press = (value: T) => {
    if (choose(value) !== false) mark(value);
  };
  mark(chosen);
  return el("div", { className: "seg seg-auto", role: "group", ariaLabel: label }, ...buttons);
}

/**
 * A `segmented` choice of a setting stored at once: `save` stores a pick and answers what was stored, which is
 * shown; one refused says why in `notice` and shows what `read` answers then. Only the last pick's answer is shown;
 * `save` keeps the order of the stores (`changeCompanion`). `read` shows what is stored anew; it runs once at the start.
 */
export function savedChoice<T>(
  label: string,
  options: [value: T, text: string][],
  notice: HTMLElement,
  read: () => Promise<T>,
  save: (value: T) => Promise<T>,
): { node: HTMLElement; read(): void } {
  let node = el("span");
  const draw = (value: T) => {
    const next = segmented(label, options, value, (pick) => void take(pick));
    node.replaceWith(next);
    node = next;
  };
  let picks = 0;
  const take = async (value: T) => {
    const mine = ++picks;
    notice.replaceChildren();
    try {
      const stored = await save(value);
      if (mine === picks) draw(stored);
    } catch (error) {
      if (mine !== picks) return;
      notice.replaceChildren(failure(reason(error)));
      await read().then((now) => mine === picks && draw(now), () => {});
    }
  };
  const show = () => void read().then(draw, (error: unknown) => notice.replaceChildren(failure(reason(error))));
  show();
  return { node, read: show };
}

/**
 * One choice of a `selectField`: its value, its words, the name of the group in its menu that it begins, whether it
 * cannot be picked, and grey words under it in the menu alone (`sub`), which the field does not show.
 */
export interface Choice {
  value: string;
  label: string;
  group?: string;
  off?: boolean;
  sub?: string;
}

/** The app's own select field: where it stands (`node`), its button (`field`), the value chosen, and `offer`, which gives it other choices. */
export interface Select {
  node: HTMLElement;
  field: HTMLButtonElement;
  value: string;
  offer(choices: Choice[]): void;
}

/**
 * A choice from a list, never the system's select (docs/design.md,
 * "Controls"): a field showing the choice made, with a chevron at its right,
 * which opens the app's menu of the `choices` with the one made ticked. A line
 * picked becomes the value, and `take` is told it, which may set the value
 * back. The field's `attrs` give it its ID, for a label, or its name, and
 * the grey words it shows while no choice is made (`placeholder`).
 */
export function selectField(
  choices: Choice[],
  value: string,
  take: (value: string) => void,
  { placeholder = "", wide = false, ...attrs }: { id?: string; ariaLabel?: string; disabled?: boolean; placeholder?: string; wide?: boolean } = {},
): Select {
  const words = el("span", { className: "select-words ellipsis" });
  const field = el("button", { type: "button", className: wide ? "field selectbtn selectbtn-wide" : "field selectbtn", ...attrs }, words, icon("down", 16));
  const node = el("div", { className: "select-field" });
  let offered = choices;
  let chosen = value;
  // The menu is made anew only when what it offers or ticks changed, so that one open stays open.
  let drawn = "";
  const draw = () => {
    const now = JSON.stringify([offered, chosen, placeholder]);
    if (now === drawn) return;
    drawn = now;
    const made = offered.find((one) => one.value === chosen);
    words.textContent = made?.label ?? placeholder;
    words.classList.toggle("c-grey", !made);
    const items = offered.map(({ value, label, group, off, sub }): MenuItem => ({
      label,
      group,
      off,
      sub,
      chosen: value === chosen,
      action: () => {
        select.value = value;
        take(value);
      },
    }));
    // The new menu would drop the focus of the field or of the line just picked: it goes to the field.
    const focused = node.contains(document.activeElement);
    node.replaceChildren(menuOn(field, items, true));
    if (focused) field.focus();
  };
  const select: Select = {
    node,
    field,
    get value() {
      return chosen;
    },
    set value(now) {
      chosen = now;
      draw();
    },
    offer(now) {
      offered = now;
      draw();
    },
  };
  draw();
  return select;
}

/**
 * Gives `input` a list to pick its value from, which opens under it: `from`
 * says what is offered for what was typed into the field. A value that was
 * not typed there, one the page put into the field or a line taken, narrows
 * nothing: `from` is asked as for an empty field then. The list opens when the
 * field is typed in, pressed or asked with an arrow key, and when `open` is
 * called, and the page moves as far as shows all of it; it stays shut while
 * there is nothing to offer, and the arrows are the field's own then. They go
 * through the list's lines while the focus stays in the field; Enter takes the
 * line they marked, and a press takes the line pressed. Escape and the focus
 * leaving shut it, and an Escape that shut it does nothing else: a window the
 * field stands in stays open. What is typed counts as it is: with no line
 * marked, Enter is the form's. The field stands in the `node`, which is put
 * where the field would be, and `typed` answers what the user typed into the
 * field, while that is what stands in it, and else nothing. `inside` makes the
 * list part of the window, in the flow where its caller puts `list`, and
 * always open while it has lines: the model picker's (docs/design.md).
 * `chosen`, the value in use, is ticked and marked in the list until the arrows
 * mark another. With `label`, a line shows the value's label with the value in
 * grey under it (`.opt.two`).
 */
export function suggest(input: HTMLInputElement, from: (typed: string) => string[], inside = false, chosen?: string, label?: (value: string) => string): { node: HTMLElement; list: HTMLElement; open(): void; typed(): string } {
  const list = el("div", { id: `${input.name}-offered`, className: "kind-list", role: "listbox", hidden: true });
  input.role = "combobox";
  input.ariaAutoComplete = "list";
  input.setAttribute("aria-controls", list.id);
  // The browser's memory of what was typed there before would open over the list.
  input.autocomplete = "off";

  /** What the user typed into the field, while that is what stands in it. */
  let typed: string | null = null;
  /** The line the arrows are at. */
  let marked: HTMLElement | null = null;
  function mark(line: HTMLElement | null): void {
    marked?.removeAttribute("aria-selected");
    marked = line;
    line?.setAttribute("aria-selected", "true");
    line?.scrollIntoView({ block: "nearest" });
    if (line) input.setAttribute("aria-activedescendant", line.id);
    else input.removeAttribute("aria-activedescendant");
  }
  /** Opens the list with what is offered now, or shuts it; one inside the window stays open. */
  function show(now: boolean): void {
    now ||= inside;
    const offered = now ? from(input.value === typed ? typed : "") : [];
    // The value in use is ticked and marked, so the arrows start from it (design.md, "A choice from a list").
    const lines = offered.map((value, n) => {
      const words = label ? el("span", { className: "flex f-col g-2" }, label(value), el("span", { className: "opt-id" }, value)) : value;
      const line = el("div", { id: `${list.id}-${n}`, className: label ? "opt two" : "opt", role: "option" }, words, value === chosen && icon("check", 16));
      line.dataset.value = value;
      return line;
    });
    list.replaceChildren(...lines);
    list.hidden = !lines.length;
    input.ariaExpanded = String(!list.hidden);
    // Marked once shown, so the list opens scrolled to it; a list not yet in its window, once it is.
    mark(lines.find((line) => line.dataset.value === chosen) ?? null);
    if (!list.isConnected) requestAnimationFrame(() => marked?.scrollIntoView({ block: "nearest" }));
    // All of it is in view, also under a field at the window's foot.
    if (lines.length && !inside) list.scrollIntoView({ block: "nearest" });
  }
  function take(line: HTMLElement): void {
    input.value = line.dataset.value ?? "";
    typed = null;
    show(false);
  }

  input.addEventListener("input", () => {
    typed = input.value;
    show(true);
  });
  input.addEventListener("click", () => show(true));
  input.addEventListener("blur", () => show(false));
  input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      const lines = [...list.children] as HTMLElement[];
      if (list.hidden) show(true);
      else mark(after(lines, marked ? lines.indexOf(marked) : -1, event.key === "ArrowDown") ?? null);
      // With nothing to offer the arrows do what they do in any field.
      if (!list.hidden) event.preventDefault();
    } else if (event.key === "Enter" && marked) {
      event.preventDefault();
      take(marked);
    } else if (event.key === "Escape" && !list.hidden && !inside) {
      event.preventDefault();
      show(false);
    }
  });
  // A press in the list leaves the focus in the field, so the list stays open under it.
  list.onmousedown = (event) => event.preventDefault();
  list.onclick = (event) => {
    const line = (event.target as HTMLElement).closest<HTMLElement>('[role="option"]');
    if (line) take(line);
  };
  show(false);
  if (inside) list.classList.add("inside");
  return { node: el("div", { className: "suggest rel flex f-grow" }, input, !inside && list), list, open: () => show(true), typed: () => (input.value === typed ? typed : "") };
}

/**
 * Lets `input` hold `most` signs at most, counted as the server counts them: a
 * sign that takes two units of a text, as 🌊 does, is one, where `maxLength`
 * counts it twice. As `maxLength` does, what is typed or pasted beyond is
 * refused where it is typed: the part of it that fits is kept, the text after it
 * stays and the caret stands after what was kept. A word being composed (an
 * input method) is let be until it is done.
 */
export function atMost(input: HTMLInputElement | HTMLTextAreaElement, most: number): void {
  let before = input.value;
  const held = () => {
    const now = input.value;
    if ([...now].length <= most) {
      before = now;
      return;
    }
    // The part typed: what lies between the text both have at the start and at the end.
    let start = 0;
    while (start < before.length && start < now.length && before[start] === now[start]) start++;
    let end = 0;
    while (end < before.length - start && end < now.length - start && before[before.length - 1 - end] === now[now.length - 1 - end]) end++;
    // Never between the two halves of a 🌊.
    if (start > 0 && /[\uD800-\uDBFF]/.test(now[start - 1])) start--;
    if (end > 0 && /[\uDC00-\uDFFF]/.test(now[now.length - end])) end--;
    const head = now.slice(0, start);
    const tail = now.slice(now.length - end);
    const room = Math.max(0, most - [...head].length - [...tail].length);
    const kept = [...now.slice(start, now.length - end)].slice(0, room).join("");
    input.value = head + kept + tail;
    input.setSelectionRange(head.length + kept.length, head.length + kept.length);
    before = input.value;
  };
  input.addEventListener("input", (event) => {
    if (!(event as InputEvent).isComposing) held();
  });
  input.addEventListener("compositionend", held);
}

/** The line over the AI's changes that wait: what it says of them ("1 text changed by AI"), "Keep all" and "Undo all". */
export const changesBar = (said: string, keepAll: () => void, undoAll: () => void): HTMLElement[] => [
  el("span", null, said),
  el("button", { type: "button", className: "btn btn-primary btn-sm", onclick: keepAll }, wording("dom-keep-all")),
  el("button", { type: "button", className: "btn btn-secondary btn-sm on-box", onclick: undoAll }, wording("coding-undo-all")),
];


/** A switch (the design system's `.switch`), with `props` such as its label, whether it is on and whether it can be used. */
export const switchBox = (props: Partial<HTMLInputElement> = {}) => el("input", { type: "checkbox", role: "switch", className: "switch", ...props });
/** An item's label and grey line, each a text or the element that shows it. */
const itemText = (tag: "div" | "span", label: HTMLElement | string, about: HTMLElement | string) =>
  el(tag, { className: "item-text" }, typeof label === "string" ? el("span", { className: "item-label" }, label) : label, typeof about === "string" ? el("span", { className: "meta" }, about) : about);
/** A line of a group: its label and grey line (`itemText`), then its control. */
export const item = (label: HTMLElement | string, about: HTMLElement | string, control: HTMLElement) => el("div", { className: "item" }, itemText("div", label, about), control);
/** A setting's grey line: `until` (how it is set while the user has not chosen), or that the user chose it. */
export const aboutChoice = (chosen: boolean, until: string): string => (chosen ? wording("dom-chosen-by-you") : until);
/** A line of a group that leads to `href`: its label and grey line (`itemText`), then an arrow. */
export const link = (href: string, label: string, about: HTMLElement | string) => el("a", { className: "item ink-link", href }, itemText("span", label, about), icon("right"));

/**
 * The tabs in a screen's bar, called `label`: the open one is the screen's
 * name, the others lead to their pages.
 */
export function tabs(label: string, of: { name: string; href: string; open: boolean }[]): HTMLElement {
  return el(
    "nav",
    { className: "tabs flex g-24", ariaLabel: label },
    ...of.map(({ name, href, open }) => (open ? el("h1", { className: "tab iflex ai-c m0", ariaCurrent: "page" }, name) : el("a", { className: "tab iflex ai-c", href }, name))),
  );
}

/** The × that closes what lies over the page, its drawing of a `size`. */
export const closeButton = (size?: number) => el("button", { type: "button", className: "quiet icon btn btn-quiet btn-icon", ariaLabel: wording("window-close") }, icon("close", size));

/** A pill: a small grey button that is light blue while it is `pressed`, which says that it is the choice made, or one of them. */
export function pill(label: string, pressed: boolean, press: () => void): HTMLButtonElement {
  const one = el("button", { type: "button", className: "pill", ariaPressed: String(pressed), onclick: press }, label);
  // Its words in semibold, unseen, hold the width it has pressed (app.css `.pill[data-label]`): pressing moves no other.
  one.dataset.label = label;
  return one;
}

/** A small button that is an icon, with its name for who does not see it and what it says when pointed at. */
export const iconButton = (label: string, title: string, shape: IconName, action: () => void): HTMLButtonElement =>
  el("button", { type: "button", className: "quiet icon small btn btn-quiet btn-icon btn-sm", ariaLabel: label, title, onclick: action }, icon(shape, 16));

/** What a line can do, as an icon that shows while the line is pointed at. */
export const lineButton = (label: string, title: string, shape: IconName, action: () => void): HTMLButtonElement => {
  const button = iconButton(label, title, shape, action);
  button.classList.add("reveal");
  return button;
};

export const toast = () => document.querySelector<HTMLElement>("#toast")!;
/** The notice in view outlives the next change of screen, or with "stays" every one until its button. */
let carried: boolean | "stays" = false;
/** The notice that stays until its button, shown again when a later one goes. */
let kept: (() => void) | null = null;
/** How long a notice without a button stays before it goes away on its own. */
const NOTICE_STAYS = 6000;
/** The notice in view goes away by itself when this runs. */
let fade: ReturnType<typeof setTimeout> | undefined;

/** Copies `text` and says so in the notice, `told`. Not every page may write to the clipboard (one served over plain http may not). */
export async function copyText(text: string, told = wording("dom-address-copied")): Promise<void> {
  // A page outside https has no clipboard at all.
  await Promise.resolve()
    .then(() => navigator.clipboard.writeText(text))
    .catch(() => {
      throw new Error(wording("dom-the-browser-did-not"));
    });
  announce(told);
}

/**
 * Says at the bottom of the window what was just done, with "Undo" when it can
 * be taken back, or with what else can be done about it under its own `label`.
 * It stays until the next notice or until the screen changes; with `carry`,
 * over the one change of screen that follows; with `carry` "stays" (one with a
 * button), over every one until its button is pressed, and back when a later
 * notice goes. One without a button also goes away by itself after a few seconds.
 */
export function announce(text: string, undo?: () => Promise<void>, carry: boolean | "stays" = false, label = wording("card-block-undo")): void {
  carried = carry;
  if (carry === "stays") kept = () => announce(text, undo, "stays", label);
  const node = toast();
  node.replaceChildren(el("span", null, text));
  clearTimeout(fade);
  if (!undo) {
    fade = setTimeout(gone, NOTICE_STAYS);
    return;
  }
  const taking = async () => {
    carried = false;
    if (carry === "stays") kept = null;
    // Through `gone`, so a notice that stays is back at once.
    gone();
    try {
      await undo();
    } catch (error) {
      announce(reason(error));
    }
  };
  node.append(el("button", { type: "button", onclick: taking }, label));
}

/** Takes the notice away when the screen changes. */
export function clearNotice(): void {
  if (carried === "stays") return;
  if (carried) carried = false;
  else {
    clearTimeout(fade);
    gone();
  }
}

/** The notice in view goes; the one that stays, if any, comes back. */
function gone(): void {
  if (kept) kept();
  else toast().replaceChildren();
}

/** Whether what is dragged is files: a marked word dragged across the page is none. */
export const hasFiles = (event: DragEvent) => event.dataTransfer?.types.includes("Files") ?? false;

/**
 * A hidden field that asks for files of the kinds `accept` names, `several`
 * of them or one. The files picked in it, and those dropped on `place`, are
 * given to `take`. Who makes it puts it into the page and presses it.
 */
export function fileField(place: HTMLElement, accept: string, several: boolean, take: (files: File[]) => void): HTMLInputElement {
  const field = el("input", { type: "file", accept, multiple: several, hidden: true });
  field.onchange = () => {
    take([...(field.files ?? [])]);
    // So that picking the same file again counts as a change.
    field.value = "";
  };
  place.ondragover = (event) => {
    if (!hasFiles(event)) return;
    event.preventDefault();
    event.dataTransfer!.dropEffect = "copy";
  };
  place.ondrop = (event) => {
    if (!event.dataTransfer?.files.length) return;
    event.preventDefault();
    take([...event.dataTransfer.files]);
  };
  return field;
}

/** Names the tab that holds the screen `page` (tabs.ts): its title, and the picture of its round where it has one. */
export function titled(page: HTMLElement, title: string, picture: string | null = null): void {
  if (page.dataset.title === title && page.dataset.picture === (picture ?? "")) return;
  page.dataset.title = title;
  page.dataset.picture = picture ?? "";
  page.dispatchEvent(new Event("titled"));
}

