// The view button, the eye, and its menu (boards "View menu · App theme side menu", "… Chat message colours side
// menu", "… 600 px, App theme"; docs/design.md "The view menu"): in the title bar between the chevron and the
// magnifier, and at 600 px in the narrow bar before Create (rail.ts). The menu, drawn anew each time it opens,
// holds the page's name over its views (`View.views`; none on a page of one view), a rule, "App theme ›" and
// "Compact spacing" with its switch, a rule, "Chat message colours ›". A line with › opens its side menu to the
// menu's left (`.vm-side`), level with the line and moved up to stay in a short window; at 600 px and less the side
// menu takes the menu's place under a back line (`.vm-narrow`, `.vm-back`). A view picked closes the menu; a theme,
// a set or Compact spacing applies at once and the menus stay. Keys: ↑ ↓ move, → or Enter opens a side menu,
// ← or Escape closes it, a second Escape closes all. The side menu is `sideMenu`'s, the menu `viewButton`'s. The
// choices are theme.ts's; the words language.ts's.
import { el, SMALL, type View } from "../dom";
import { opener, step } from "../dialogs";
import { icon } from "../icons";
import { compact, setCompact, setTextSet, setTheme, textSet, textSets, theme, themes, type TextSet, type Theme } from "../theme";
import { onLanguage, wording } from "../language/language";

/** Room kept between a side menu and the window's lower edge, in pixels. */
const SPARE = 8;

/** A choice of a group, ticked on its light blue ground while `on`; with `note`, a grey line under its words. */
function choice(words: string, on: boolean, act: (event: MouseEvent) => void, note?: string): HTMLButtonElement {
  const tick = on ? icon("check", 16) : null;
  tick?.classList.add("chk");
  const props = { type: "button", role: "menuitemradio", ariaChecked: String(on), tabIndex: -1, onclick: act } as const;
  if (note === undefined) return el("button", props, words, tick);
  return el("button", { ...props, className: "two" }, el("span", { className: "l1" }, words, tick), el("span", { className: "sub" }, note));
}

/** A side menu's matter: its name, the words of the one in use, and its choices drawn by `pick`. */
interface Side {
  name: () => string;
  now: () => string;
  lines: (pick: (act: () => void) => (event: MouseEvent) => void) => HTMLButtonElement[];
}

const THEMES: Side = {
  name: () => wording("view-theme"),
  now: () => themes().find(([name]) => name === theme())![1],
  lines: (pick) => themes().map(([name, words]) => choice(words, name === theme(), pick(() => setTheme(name as Theme)))),
};

const TEXT_SETS: Side = {
  name: () => wording("view-text-set"),
  now: () => textSets().find(([name]) => name === textSet())![1],
  lines: (pick) => textSets().map(([name, words, note]) => choice(words, name === textSet(), pick(() => setTextSet(name as TextSet)), note)),
};

/** The side menu beside the menu `list`: opened from one of its lines, drawn, placed and closed; its own keys. */
interface SideMenu {
  node: HTMLElement;
  /** Opens `of`'s side menu from `line`, with the focus on its first line at 600 px, else its ticked one, unless `focus` is false. */
  open(of: Side, line: HTMLButtonElement, focus?: boolean): void;
  /** Closes it, the focus back on its line. */
  close(): void;
  /** Hides it without moving the focus, for the menu opening anew. */
  reset(): void;
  /** Whether it is open from `line`. */
  from(line: HTMLButtonElement): boolean;
}

function sideMenu(list: HTMLElement): SideMenu {
  const side = el("div", { className: "pop vmenu vm-side", role: "menu", hidden: true });
  /** The side menu open and the line that opened it. */
  let open: { of: Side; line: HTMLButtonElement } | null = null;

  /** Draws `of`'s choices; a pick applies, both menus show it, and the focus stays on it. */
  const draw = (of: Side) => {
    const pick = (act: () => void) => (event: MouseEvent) => {
      act();
      const at = [...side.querySelectorAll("[role=menuitemradio]")].indexOf(event.currentTarget as Element);
      open!.line.querySelector(".vm-val")!.firstChild!.textContent = of.now();
      draw(of);
      side.querySelectorAll<HTMLElement>("[role=menuitemradio]")[Math.max(at, 0)]?.focus();
    };
    const back = SMALL.matches
      ? [el("button", { type: "button", className: "vm-back", role: "menuitem", tabIndex: -1, onclick: close }, icon("left", 16), el("span", null, of.name())), el("hr")]
      : [];
    side.ariaLabel = of.name();
    side.replaceChildren(...back, ...of.lines(pick));
  };
  const reset = () => {
    open = null;
    side.hidden = true;
    list.hidden = false;
  };
  function close(): void {
    if (!open) return;
    const { line } = open;
    reset();
    line.ariaExpanded = "false";
    line.focus();
  }
  /** Puts the side menu level with `line` (none at 600 px: in the menu's place), moved up to stay in the window. */
  const place = (line: HTMLButtonElement | null) => {
    side.style.top = side.style.maxHeight = "";
    if (!line) return;
    const top = list.offsetTop + line.offsetTop - parseFloat(getComputedStyle(side).paddingTop || "0");
    side.style.top = `${top}px`;
    const box = side.getBoundingClientRect();
    const over = box.bottom + SPARE - innerHeight;
    if (over <= 0) return;
    const up = Math.min(over, box.top - SPARE);
    side.style.top = `${top - Math.max(up, 0)}px`;
    if (up < over) side.style.maxHeight = `${innerHeight - 2 * SPARE - (box.height - side.clientHeight)}px`;
  };
  side.onkeydown = (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      step([...side.querySelectorAll<HTMLElement>("button")], event.key === "ArrowDown");
    } else if (event.key === "ArrowLeft" || event.key === "Escape") {
      event.preventDefault();
      close();
    }
  };
  return {
    node: side,
    open(of, line, focus = true) {
      if (open) open.line.ariaExpanded = "false";
      open = { of, line };
      line.ariaExpanded = "true";
      draw(of);
      side.hidden = false;
      const narrow = SMALL.matches;
      side.classList.toggle("vm-narrow", narrow);
      list.hidden = narrow;
      place(narrow ? null : line);
      if (focus) (side.querySelector<HTMLElement>(narrow ? ".vm-back" : "[aria-checked=true]") ?? side.querySelector<HTMLElement>("button"))?.focus();
    },
    close,
    reset,
    from: (line) => open?.line === line,
  };
}

/** The view button, with `className` for where it stands, and its menu for the screen `page` answers with at the time. */
export function viewButton(className: string, page: () => View | null | undefined): HTMLElement {
  const button = el("button", { type: "button", className, ariaLabel: wording("view"), title: wording("view"), ariaHasPopup: "menu" }, icon("eye", 16));
  const list = el("div", { className: "pop vmenu", role: "menu", ariaLabel: wording("view") });
  const side = sideMenu(list);
  onLanguage(() => (button.ariaLabel = button.title = list.ariaLabel = wording("view")));

  const shut = () => {
    menu.open(false);
    button.focus();
  };
  /** A line opening `of`'s side menu: its name, the one in use in grey and a chevron. */
  const more = (of: Side) => {
    const line = el(
      "button",
      { type: "button", className: "vm-more", role: "menuitem", ariaHasPopup: "menu", ariaExpanded: "false", tabIndex: -1 },
      el("span", null, of.name()),
      el("span", { className: "vm-val" }, of.now(), icon("right", 16)),
    );
    line.onclick = () => side.open(of, line);
    line.onpointerenter = () => !side.from(line) && !SMALL.matches && side.open(of, line, false);
    return line;
  };
  const switchLine = () => {
    const line = el(
      "button",
      { type: "button", className: "vm-more", role: "menuitemcheckbox", ariaChecked: String(compact()), tabIndex: -1 },
      el("span", null, wording("view-compact")),
      el("span", { className: "switch", ariaHidden: "true" }),
    );
    line.onclick = () => {
      setCompact(!compact());
      line.ariaChecked = String(compact());
    };
    return line;
  };
  const draw = () => {
    const views = page()?.views;
    const now = views?.now();
    list.replaceChildren(
      ...(views
        ? [
            el("div", { className: "sec", role: "presentation" }, views.heading()),
            ...views.list.map(([name, words]) => choice(words, name === now, () => (shut(), views.choose(name)))),
            el("hr"),
          ]
        : []),
      more(THEMES),
      switchLine(),
      el("hr"),
      more(TEXT_SETS),
    );
  };

  const panel = el("div", { className: "vm" }, list, side.node);
  const menu = opener(button, panel, () => {
    side.reset();
    draw();
    list.querySelector<HTMLElement>("[aria-checked=true], [role=menuitem]")?.focus();
  });
  list.onkeydown = (event) => {
    const at = document.activeElement;
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      step([...list.querySelectorAll<HTMLElement>("button")], event.key === "ArrowDown");
    } else if ((event.key === "ArrowRight" || event.key === "Enter") && at instanceof HTMLButtonElement && at.ariaHasPopup === "menu") {
      event.preventDefault();
      at.click();
    } else if (event.key === "Escape") {
      event.preventDefault();
      shut();
    }
  };
  return menu.node;
}
