// The menus and the windows over the page: `menu`, `menuOn`, `opener`, `contextMenu` and `menuAt` (one at a point), a line of one a
// `MenuItem`, with `step` and `within` for the arrow keys and the window's edge; `dialog`, `formDialog` with "Save"
// or the word it is given, `folderDialog`, `sheet`, and `askFirst`, the question in a line's place (`askUnder`: under a list's line).
//
// Traps: a menu that would be cut off places itself in the window (`float`) and closes when the window changes
// its size or what its button stands in scrolls; a dialog stands in its screen and goes with it.
import { icon, type IconName } from "./icons";
import { type Child, closeButton, el, noticeBox, oneAtATime } from "./dom";
import { wording } from "./language/language";

/**
 * Moves the focus through `all` as an arrow key does: `down` to the next,
 * else to the one before, after the last to the first and before the first to
 * the last. From outside them it goes to the first, or to the last.
 */
export function step(all: HTMLElement[], down: boolean): void {
  after(all, all.indexOf(document.activeElement as HTMLElement), down)?.focus();
}

/**
 * The one of `all` an arrow key leads to from the one at `at`: `down` the
 * next, else the one before, after the last the first and before the first the
 * last. From none of them (-1) it is the first, or the last.
 */
export function after<T>(all: T[], at: number, down: boolean): T | undefined {
  const by = down ? 1 : at < 0 ? 0 : -1;
  return all[(at + by + all.length) % all.length];
}

/** One line of a menu. */
export interface MenuItem {
  label: string;
  action(): void;
  /** The drawing at the line's right. */
  shape?: IconName;
  /** A picture at the line's right in the drawing's place, by its address: the app's icon of "Open Cardwave". */
  picture?: string;
  /** The line deletes: it is red. */
  danger?: boolean;
  /** The line begins a group: a rule stands over it. */
  apart?: boolean;
  /** The line is a narrow window's alone, where the button that does the same has no room (`.narrow-only`). */
  narrow?: boolean;
  /** The line begins a group of this name, which stands over it, under a rule unless the menu begins with it. */
  group?: string;
  /** The line is one choice of several, and whether it is the one made: that one is semibold and has a tick at its right. */
  chosen?: boolean;
  /** The line cannot be picked: it is greyed, and a press on it does nothing. */
  off?: boolean;
  /** What the line does, in grey under its name. */
  sub?: string;
  /** The line is not shown, as what it does is not there for the user. */
  hidden?: boolean;
}

/**
 * The lines of a menu in their box, each with its name at the left and its
 * drawing at the right, and what the `keys` do while it is open: the arrows go
 * through the lines. A line that is picked, Tab and Escape `shut` the menu
 * first; Escape and a line picked ask for the focus to go `back` to where the
 * menu was opened from, and Escape is the menu's alone: what the menu stands in stays open. `first`
 * reads anew which lines cannot be picked (`off`), as that may have changed
 * since the menu was made, and puts the focus on the first line that can.
 */
function menuItems(items: MenuItem[], shut: (back: boolean) => void): { list: HTMLElement; keys(event: KeyboardEvent): void; first(): void } {
  const pick = (item: MenuItem) => {
    // A line that cannot be picked leaves the menu as it is.
    if (item.off) return;
    // The focus goes back to where the menu was opened from: what the line opens (a dialog, a field written in
    // place) gives it back there when it closes, and what moves it elsewhere does so after.
    shut(true);
    item.action();
  };
  const lines = items.map((item) => {
    const choice = item.chosen !== undefined;
    const mark = item.chosen ? icon("check", 16) : item.picture ? el("img", { className: "menu-picture ico", width: 16, height: 16, src: item.picture, alt: "" }) : item.shape && icon(item.shape, 16);
    const line = el(
      "button",
      { type: "button", className: [item.danger && "danger", item.narrow && "narrow-only", item.sub && "two"].filter(Boolean).join(" "), role: choice ? "menuitemradio" : "menuitem", onclick: () => pick(item) },
      ...(item.sub ? [el("span", { className: "l1" }, item.label, mark), el("span", { className: "sub" }, item.sub)] : [item.label, mark]),
    );
    if (choice) line.ariaChecked = String(item.chosen);
    // The line's name is its label; the grey line under it describes it.
    if (item.sub) {
      line.ariaLabel = item.label;
      line.setAttribute("aria-description", item.sub);
    }
    return line;
  });
  const rules = items.map((item, at) => ((item.group !== undefined || item.apart) && at > 0 ? el("hr") : null));
  // Said to who does not see it, and not by `disabled`: a press on a disabled button takes the focus out of the menu, which Escape would no longer close.
  // A rule stands only under a line that is there: lines hidden above it would leave it at the menu's top.
  const offs = () =>
    lines.forEach((line, at) => {
      line.ariaDisabled = items[at].off ? "true" : null;
      line.hidden = items[at].hidden ?? false;
      const rule = rules[at];
      if (rule) rule.hidden = items.slice(0, at).every((item) => item.hidden);
    });
  offs();
  const parted = items.flatMap((item, at) => [rules[at], item.group !== undefined && el("div", { className: "menu-group sec", role: "presentation" }, item.group), lines[at]]);
  const list = el("div", { className: "pop", role: "menu" }, ...parted);
  /** The lines to pick from that the window shows: one of a narrow window alone is not there in a wide one. */
  const shown = () => lines.filter((line) => line.ariaDisabled !== "true" && line.getClientRects().length > 0);
  const keys = (event: KeyboardEvent) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      step(shown(), event.key === "ArrowDown");
    } else if (event.key === "Escape") {
      event.preventDefault();
      shut(true);
    } else if (event.key === "Tab") {
      shut(false);
    }
  };
  return {
    list,
    keys,
    first: () => {
      offs();
      shown()[0]?.focus();
    },
  };
}

/**
 * A `button` with what it opens under it, `panel`: a press on the button
 * opens and closes it, and a press beside the two closes it. `opened` is told
 * each time it has opened.
 */
export function opener(
  button: HTMLButtonElement,
  panel: HTMLElement,
  opened: (shut: AbortSignal) => void,
): { node: HTMLElement; open(now: boolean): void } {
  const node = el("div", { className: "menu" }, button, panel);
  const outside = (event: Event) => {
    if (!node.contains(event.target as Node)) open(false);
  };
  /** Ends what listens while it is open, so a closed one leaves nothing behind. */
  let listening: AbortController | null = null;
  function open(now: boolean): void {
    panel.hidden = !now;
    button.ariaExpanded = String(now);
    listening?.abort();
    listening = now ? new AbortController() : null;
    if (listening) document.addEventListener("pointerdown", outside, { signal: listening.signal });
  }
  button.onclick = () => {
    open(panel.hidden);
    if (listening) opened(listening.signal);
  };
  open(false);
  return { node, open };
}

/** How far under its button a menu that places itself opens, in pixels. */
const MENU_GAP = 6;

/**
 * Gives `button` a list of actions that opens under it. With `float` the menu
 * places itself in the window: under the button, from its left edge on, or
 * with `"end"` back from its right edge, and all of it inside the window. That
 * is for a button whose surroundings would cut a menu off, as the rail does;
 * it closes when the button moves away from over it: the window changes its
 * size, or what the button stands in scrolls. A menu that stands in its page
 * has the page move as far as shows all of it.
 */
export function menuOn(button: HTMLButtonElement, items: MenuItem[], float: boolean | "end" = false): HTMLElement {
  button.ariaHasPopup = "menu";
  const { list, keys, first } = menuItems(items, (back) => {
    open(false);
    if (back) button.focus();
  });
  const { node, open } = opener(button, list, (shut) => {
    if (float) {
      const at = button.getBoundingClientRect();
      place(list, float === "end" ? at.right - list.getBoundingClientRect().width : at.left, at.bottom + MENU_GAP);
      window.addEventListener("resize", () => open(false), { signal: shut });
      const scrolled = (event: Event) => {
        if ((event.target as Node).contains(button)) open(false);
      };
      document.addEventListener("scroll", scrolled, { signal: shut, capture: true });
    }
    first();
    // The focus has the page show the menu's first line; all of the menu is to show, where the page can move so far.
    if (!float) list.scrollIntoView({ block: "nearest" });
  });
  if (float) node.classList.add("float");
  // On its button too, which can hold the focus while the menu is open.
  node.onkeydown = (event) => {
    if (!list.hidden) keys(event);
  };
  return node;
}

/** A button named `label` that opens a list of actions under it: a "more" button, unless it is given another `shape` and `size`. */
export function menu(label: string, items: MenuItem[], shape: IconName = "more", size?: number): HTMLElement {
  return menuOn(el("button", { type: "button", className: "quiet icon btn btn-quiet btn-icon", ariaLabel: label }, icon(shape, size)), items);
}

/**
 * Opens a window over the page, named `title`: its name and the × that closes
 * it, over `content`. Escape closes it too, and so does a click beside it; the
 * focus then goes back to where it was. It stands in `home`, the screen it
 * belongs to, and goes with it.
 */
export function dialog(home: HTMLElement, title: string, ...content: Child[]): HTMLDialogElement {
  const close = closeButton();
  // The design system's: what is not its foot (`.dfoot`) stands in its body, unless it brings its own.
  const nodes = content.filter((part): part is HTMLElement => part instanceof HTMLElement);
  const own = nodes.some((part) => part.classList.contains("dlg-body"));
  const foot = nodes.filter((part) => part.classList.contains("dfoot"));
  const body = own ? content : [el("div", { className: "dlg-body" }, ...content.filter((part) => !foot.includes(part as HTMLElement))), ...foot];
  return raise(home, el("dialog", { className: "dialog", ariaLabel: title }, el("header", { className: "dlg-head" }, el("h2", null, title), close), ...body), close);
}

/**
 * Opens a [`dialog`] that is a form to save (`dialog.form-dialog > .form`):
 * `fields`, why it was not saved, and "Save" (or what `action` calls it) and
 * "Cancel". "Save" runs `save`, one at a time, which closes the dialog itself
 * once it has saved.
 */
export function formDialog(home: HTMLElement, title: string, fields: Child[], save: () => Promise<void>, action = wording("common-save")): HTMLDialogElement {
  const failed = noticeBox();
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const buttons = [el("button", { type: "submit", className: "primary btn btn-primary" }, action), cancel];
  const form = el("form", { className: "dlg-body" }, ...fields, failed, el("div", { className: "flex g-8" }, ...buttons));
  const box = dialog(home, title, form);
  box.classList.add("form-dialog");
  cancel.onclick = () => box.close();
  const run = oneAtATime(failed);
  form.onsubmit = (event) => {
    event.preventDefault();
    void run(save);
  };
  return box;
}

/**
 * Opens the dialog `title` (This computer's models, the folder of cards): the
 * field "Folder on this computer" holding `value`, `words` under it, and Save,
 * which hands the folder typed to `save`.
 */
export function folderDialog(home: HTMLElement, title: string, value: string, example: string, words: string, save: (folder: string) => Promise<void>, action?: string): void {
  const input = el("input", { id: "folder-field", className: "field", type: "text", value, placeholder: example, autocomplete: "off" });
  const folder = el("div", { className: "fld" }, el("label", { className: "label", htmlFor: input.id }, wording("dialogs-folder-on-this-computer")), input, el("p", { className: "hint" }, words));
  const box = formDialog(
    home,
    title,
    [folder],
    async () => {
      await save(input.value);
      box.close();
    },
    action,
  );
  input.focus();
}

/**
 * Asks in `place`, which is in the page, before what cannot be taken back is
 * done: the place holds the `question` (red in a `.confirm`), the red button
 * `yes` that does it and "Cancel", which has the focus, so a second Enter does
 * no harm, and which calls `back`, for the place to hold what it held again.
 */
export function askFirst(place: HTMLElement, question: string, yes: string, action: () => void, back: () => void): void {
  const cancel = el("button", { type: "button", className: "btn btn-secondary", onclick: back }, wording("common-cancel"));
  place.replaceChildren(
    el("span", { className: "question c-danger medium" }, question),
    el("button", { type: "button", className: "danger btn btn-danger-fill", onclick: action }, yes),
    cancel,
  );
  cancel.focus();
}

/**
 * Asks as `askFirst` does, on a line of its own under the row that holds `tools` (a list's line), so the row's
 * name stays whole: the tools hide meanwhile, and Cancel takes the line away, shows them again and gives the
 * focus back to `opener`, the button the ask was begun from.
 */
export function askUnder(tools: HTMLElement, opener: HTMLElement, question: string, yes: string, action: () => void): void {
  const asking = el("div", { className: "confirm flex ai-c jc-e g-8" });
  tools.hidden = true;
  tools.parentElement!.after(asking);
  askFirst(asking, question, yes, action, () => {
    asking.remove();
    tools.hidden = false;
    opener.focus();
  });
}

/**
 * Opens a panel that slides in from the window's right, over the page, named
 * `title`: the × that closes it and its name, over `content`, which scrolls,
 * and `foot`, where there is one, which stays at its end. It closes as a
 * [`dialog`] does, stands in `home` and goes with it.
 */
export function sheet(home: HTMLElement, title: string, content: HTMLElement, foot?: HTMLElement): HTMLDialogElement {
  const close = closeButton();
  const head = el("header", { className: "sheet-head" }, close, el("h2", null, title));
  content.classList.add("sheet-body");
  foot?.classList.add("sheet-foot");
  return raise(home, el("dialog", { className: "sheet", ariaLabel: title }, head, content, ...(foot ? [foot] : [])), close);
}

/** Shows `box` over the page, in `home`: its `close` closes it, as do Escape and a click beside it, and closed it is gone. */
function raise(home: HTMLElement, box: HTMLDialogElement, close: HTMLButtonElement): HTMLDialogElement {
  close.onclick = () => box.close();
  // What it holds fills it: a click on the dialog itself is one on the page behind it. But one that began in it
  // (words marked, the mouse let go beside it) is told as the dialog's too, and closes nothing.
  let pressed: EventTarget | null = null;
  box.onpointerdown = (event) => (pressed = event.target);
  box.onclick = (event) => {
    if (event.target === box && pressed === box) box.close();
  };
  box.onclose = () => box.remove();
  home.append(box);
  box.showModal();
  return box;
}

/** How near a window's edge a menu at the pointer, or what a button opens under it, may come, in pixels. */
const MENU_EDGE = 4;

/** Where something `size` long that would begin `at` begins, so that all of it is inside a window with `room`. */
export const within = (at: number, size: number, room: number) => Math.max(MENU_EDGE, Math.min(at, room - size - MENU_EDGE));

/** Puts a menu that stands in the window by itself where its corner is at `left` and `top`, or as near as leaves all of it inside the window. */
function place(list: HTMLElement, left: number, top: number): void {
  const { width, height } = list.getBoundingClientRect();
  list.style.left = `${within(left, width, innerWidth)}px`;
  list.style.top = `${within(top, height, innerHeight)}px`;
}

/**
 * Gives `node` a menu of its own in place of the browser's: a right-click, or
 * the keyboard's menu key, opens `items` where the pointer is, all of it inside
 * the window. It closes with a line picked, Escape or Tab, which give the focus
 * back to `node`, and with a click elsewhere, a scroll or a change of screen.
 */
export function contextMenu(node: HTMLElement, items: () => MenuItem[]): void {
  node.oncontextmenu = (event) => {
    event.preventDefault();
    menuAt(node, items(), event.clientX, event.clientY, event.button === 2);
  };
}

/**
 * Opens `items` as a menu standing in the window by itself, its corner at `left` and `top` or as near as leaves
 * all of it inside the window, opened from `node` (where Escape, Tab and a line picked give the focus back); a
 * menu the pointer opened (`byPointer`) shows no focus ring on its first line. A click elsewhere, a scroll or a
 * change of screen closes it, which the signal it gives tells.
 */
export function menuAt(node: HTMLElement, items: MenuItem[], left: number, top: number, byPointer: boolean): AbortSignal {
  const open = new AbortController();
  const shut = (back: boolean) => {
    open.abort();
    list.remove();
    if (back) node.focus();
  };
  const { list, keys, first } = menuItems(items, () => shut(true));
  list.onkeydown = (down) => {
    list.classList.remove("by-pointer");
    keys(down);
  };
  list.classList.add("at-pointer", ...(byPointer ? ["by-pointer"] : []));
  document.body.append(list);
  place(list, left, top);
  first();

  const outside = (down: Event) => {
    if (!list.contains(down.target as Node)) shut(false);
  };
  document.addEventListener("pointerdown", outside, { signal: open.signal });
  document.addEventListener("scroll", () => shut(false), { signal: open.signal, capture: true });
  window.addEventListener("hashchange", () => shut(false), { signal: open.signal });
  return open.signal;
}
