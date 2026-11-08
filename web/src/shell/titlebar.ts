// The title bar, `#titlebar` (boards "Tabs · the tab bar" and "Tabs · all tabs"; docs/design.md "Tabs and
// search"): 36 px over the page, in the desktop app and in a browser; styles.css takes it away in a browser at
// 600 px and leaves the desktop app's window there its name and buttons alone. In it: the app's small name, which
// styles.css shows while the rail is folded; the tabs (tabs.ts), as many as `fit` lets show, the tab in view
// always among them (it moves to the last place shown); "+"; the empty room, at least `ROOM_LEAST`, which moves
// the desktop window and maximizes it on a double-click; the chevron's menu "All tabs"; the eye, the view menu
// (view-menu.ts); the magnifier (search-panel.ts); the desktop window's
// three buttons, asked of the program (desktop.ts). A tab is shown by a click (from the keyboard by Enter or
// Space), closed by its × or a middle-click, and dragged to another place. `bare` takes the tabs away where the
// rail is not (first run, the start screen), and in a browser the bar with them; `alone` (the desktop app's
// window of one page) has no tabs at all. Its words are language.ts's, set anew when the language changes.
// Traps: the bar measures itself to fit the tabs, so a bar that is not drawn (a browser at 600 px) is not
// fitted, which would move the tab in view to the first place; a drag ends in a click, which shows no tab.
import { el } from "../dom";
import { opener, step } from "../dialogs";
import { desktop, inDesktop } from "../desktop";
import { icon, type IconName } from "../icons";
import logo from "../logo.png";
import { searchButton } from "./search-panel";
import { viewButton } from "./view-menu";
import { fit, type Tab, type Tabs } from "./tabs";
import { onLanguage, wording } from "../language/language";

/** The least of the empty room beside "+", in pixels, and how far a tab is moved before it is dragged. */
const ROOM_LEAST = 48;
const DRAG_PX = 5;

export interface TitleBar {
  /** Takes the tabs away, and in a browser the bar, where the rail is not; gives them back. */
  bare(now: boolean): void;
}

/** A tab's round: its picture, or its page's drawing, also where the picture is none (a card without one answers 404). */
function round(t: Tab): HTMLElement {
  const drawing = () => el("span", { className: "ico" }, icon(t.shape, 16));
  if (!t.picture) return drawing();
  const picture = el("img", { className: "tico", src: t.picture, alt: "" });
  picture.onerror = () => picture.replaceWith(drawing());
  return picture;
}

const quiet = (label: string, title: string, shape: IconName) => el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm btn-bar", ariaLabel: label, title }, icon(shape, 16));

/** Enter and Space click `node`, a tab or a line of "All tabs", where it is itself the one focused. */
function clickedByKeys(node: HTMLElement): void {
  node.onkeydown = (event) => {
    if (event.target !== node || (event.key !== "Enter" && event.key !== " ")) return;
    event.preventDefault();
    node.click();
  };
}

/** A tab's × or that of its line in "All tabs". */
function closer(tabs: Tabs, t: Tab): HTMLButtonElement {
  return el(
    "button",
    {
      type: "button",
      className: "tx",
      ariaLabel: wording("tab-close"),
      title: wording("tab-close"),
      onclick: (event) => {
        event.stopPropagation();
        tabs.close(t);
      },
    },
    icon("close", 14),
  );
}

/** The desktop window's three buttons, asked of the program. */
function windowButtons(): HTMLElement {
  const button = (label: () => string, shape: IconName, command: "window_minimize" | "window_maximize" | "window_close") => {
    const made = el("button", { type: "button", className: command, onclick: () => void desktop(command).catch(() => {}) }, icon(shape, 16));
    const said = () => (made.ariaLabel = made.title = label());
    said();
    onLanguage(said);
    return made;
  };
  return el(
    "div",
    { className: "wc" },
    button(() => wording("window-minimize"), "minimize", "window_minimize"),
    button(() => wording("window-maximize"), "maximize", "window_maximize"),
    button(() => wording("window-close"), "close", "window_close"),
  );
}

/** The chevron and its menu "All tabs": every tab in the bar's order, the one in view marked. */
function allTabs(tabs: Tabs): { node: HTMLElement; redraw(): void; close(): void } {
  const chevron = quiet(wording("tabs-all"), wording("tabs-all"), "down");
  const list = el("div", { className: "tlist", role: "menu", ariaLabel: wording("tabs-all") });
  onLanguage(() => (chevron.ariaLabel = chevron.title = list.ariaLabel = wording("tabs-all")));
  const draw = () =>
    list.replaceChildren(
      ...tabs.list.map((t) => {
        const line = el("div", { className: "tl", role: "menuitem", ariaCurrent: String(t === tabs.now()), tabIndex: -1, title: t.title }, round(t), el("span", { className: "tt" }, t.title), closer(tabs, t));
        line.onclick = () => {
          all.open(false);
          tabs.show(t);
        };
        clickedByKeys(line);
        return line;
      }),
    );
  const all = opener(chevron, list, () => {
    draw();
    list.querySelector<HTMLElement>("[aria-current=true]")?.focus();
  });
  chevron.ariaHasPopup = "menu";
  list.onkeydown = (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      step([...list.querySelectorAll<HTMLElement>(".tl")], event.key === "ArrowDown");
    } else if (event.key === "Escape") {
      event.preventDefault();
      all.open(false);
      chevron.focus();
    }
  };
  return {
    node: all.node,
    redraw: () => {
      if (!list.hidden) draw();
    },
    close: () => all.open(false),
  };
}

/**
 * Lets the tab `node` be dragged along the bar: `place` is told where it was let go, after the click the drag
 * ends in, which `click` is then not told of.
 */
function draggable(node: HTMLElement, click: () => void, place: (x: number) => void): void {
  let dragged = false;
  node.onclick = () => !dragged && click();
  node.onpointerdown = (down) => {
    if (down.button !== 0 || (down.target as Element).closest(".tx")) return;
    let moving = false;
    node.setPointerCapture(down.pointerId);
    node.onpointermove = (move) => {
      const by = move.clientX - down.clientX;
      if (!moving && Math.abs(by) < DRAG_PX) return;
      moving = true;
      node.classList.add("dragged");
      node.style.translate = `${by}px 0`;
    };
    node.onpointerup = node.onpointercancel = (up) => {
      node.onpointermove = node.onpointerup = node.onpointercancel = null;
      if (!moving) return;
      dragged = true;
      setTimeout(() => {
        dragged = false;
        node.style.translate = "";
        node.classList.remove("dragged");
        place(up.clientX);
      });
    };
  };
}

/** Makes the title bar for `tabs`; `alone` for a window of one page. */
export function makeTitleBar(tabs: Tabs, alone = false): TitleBar {
  const bar = document.querySelector<HTMLElement>("#titlebar")!;
  const desktopped = inDesktop();
  if (desktopped) document.body.dataset.desktop = "";
  const called = document.createTextNode(wording("app-name"));
  const name = el("span", { className: "name titlebar-name" }, el("img", { className: "logo-sm", src: logo, alt: "" }), called);
  const strip = el("div", { className: "tabs", role: "tablist", ariaLabel: wording("tabs") });
  const plus = quiet(wording("tab-new"), desktopped ? wording("tab-new-keys") : wording("tab-new"), "plus");
  plus.onclick = () => tabs.newTab();
  const all = allTabs(tabs);
  const view = viewButton("btn btn-quiet btn-icon btn-sm btn-bar", () => tabs.now().view);
  const search = searchButton("btn btn-quiet btn-icon btn-sm btn-bar");
  const buttons = desktopped ? windowButtons() : null;
  bar.replaceChildren(name, strip, plus, el("div", { className: "tab-drag" }), el("div", { className: "wtabs" }, all.node, view, search), buttons ?? "");
  bar.classList.toggle("alone", alone);
  bar.hidden = false;
  if (desktopped) {
    bar.onmousedown = (event) => {
      if (event.button !== 0 || (event.target as Element).closest("button, input, [role=tab], [role=menu], [role=dialog]")) return;
      void desktop(event.detail === 2 ? "window_maximize" : "window_drag").catch(() => {});
    };
  }

  /** A tab in the bar, `width` wide: a click shows it, a middle-click closes it, and it is dragged to another place. */
  function tabNode(t: Tab, width: number): HTMLElement {
    const now = t === tabs.now();
    const node = el("div", { className: "wtab", role: "tab", ariaSelected: String(now), tabIndex: 0, title: t.title }, round(t), el("span", { className: "tt" }, t.title), closer(tabs, t));
    node.style.width = `${width}px`;
    clickedByKeys(node);
    node.onmousedown = (event) => event.button === 1 && event.preventDefault();
    node.onauxclick = (event) => {
      if (event.button !== 1) return;
      event.preventDefault();
      tabs.close(t);
    };
    // Its place is that of the tabs whose middle is left of where it was let go.
    const place = (x: number) => tabs.move(t, [...strip.querySelectorAll(".wtab")].filter((other) => other !== node && other.getBoundingClientRect().left + other.getBoundingClientRect().width / 2 < x).length);
    draggable(node, () => tabs.show(t), place);
    return node;
  }

  /**
   * The room the tabs have: the bar's, but for its other children as drawn (margins too), the gaps between the
   * children shown and the least of the empty room. The children are measured, not named: "All tabs", the eye and
   * the magnifier sit in one box with its own gaps and margin.
   */
  function roomOf(): number {
    const style = getComputedStyle(bar);
    const shown = [...bar.children].filter((part) => part.getBoundingClientRect().width > 0 || part === strip);
    const taken = shown
      .filter((part) => part !== strip && !part.classList.contains("tab-drag"))
      .reduce((sum, part) => {
        const own = getComputedStyle(part);
        return sum + part.getBoundingClientRect().width + (parseFloat(own.marginLeft) || 0) + (parseFloat(own.marginRight) || 0);
      }, 0);
    const gaps = (parseFloat(style.columnGap) || 0) * Math.max(0, shown.length - 1);
    return bar.clientWidth - (parseFloat(style.paddingLeft) || 0) - (parseFloat(style.paddingRight) || 0) - taken - gaps - ROOM_LEAST;
  }

  function draw(): void {
    if (alone || !bar.clientWidth) return;
    const { width, shown } = fit(roomOf(), tabs.list.length);
    // The tab in view always shows: taken from "All tabs", it moves to the last place shown, which draws the bar anew.
    if (tabs.list.indexOf(tabs.now()) >= shown) return tabs.move(tabs.now(), shown - 1);
    strip.replaceChildren(...tabs.list.slice(0, shown).flatMap((t, at) => [at ? el("span", { className: "tdiv", ariaHidden: "true" }) : "", tabNode(t, width)]));
    all.redraw();
  }

  tabs.watch(draw);
  onLanguage(() => {
    called.textContent = wording("app-name");
    strip.ariaLabel = wording("tabs");
    plus.ariaLabel = wording("tab-new");
    plus.title = desktopped ? wording("tab-new-keys") : wording("tab-new");
    draw();
  });
  const sizes = new ResizeObserver(() => draw());
  sizes.observe(bar);
  sizes.observe(name);
  draw();
  return {
    bare(now) {
      document.body.toggleAttribute("data-bare", now);
      if (now) all.close();
    },
  };
}
