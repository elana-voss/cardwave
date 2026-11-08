// The view button, the eye, and its menu (boards "View menu · Characters", "View menu · Compact on", "View menu ·
// a page of one view"; docs/design.md "Tabs and search"): in the title bar between the chevron and the magnifier,
// and at 600 px in the narrow bar before Create (rail.ts). The menu, made anew each time it opens, holds the page's
// views (`View.views`), a rule, the themes, a rule and "Compact"; a page of one view has no views and no rule. A
// view or a theme chosen shows at once and closes the menu; Compact is ticked or unticked and the menu stays.
// Theme and Compact are theme.ts's, the same settings as Settings › Appearance's. Its words are language.ts's.
import { el, type View } from "../dom";
import { opener, step } from "../dialogs";
import { icon } from "../icons";
import { compact, setCompact, setTheme, theme, themes } from "../theme";
import { onLanguage, wording } from "../language/language";

/** A line of the menu: its words, ticked while `on`; `role` says whether it is one of a group or a tick of its own. */
function line(words: string, on: boolean, role: "menuitemradio" | "menuitemcheckbox", act: () => void): HTMLButtonElement {
  const tick = on ? icon("check", 16) : null;
  tick?.classList.add("chk");
  return el("button", { type: "button", role, ariaChecked: String(on), tabIndex: -1, onclick: act }, words, tick ?? "");
}

/** The view button, with `className` for where it stands, and its menu for the screen `page` answers with at the time. */
export function viewButton(className: string, page: () => View | null | undefined): HTMLElement {
  const button = el("button", { type: "button", className, ariaLabel: wording("view"), title: wording("view"), ariaHasPopup: "menu" }, icon("eye", 16));
  const list = el("div", { className: "pop vmenu", role: "menu", ariaLabel: wording("view") });
  onLanguage(() => (button.ariaLabel = button.title = list.ariaLabel = wording("view")));
  const shut = () => {
    menu.open(false);
    button.focus();
  };
  const draw = () => {
    const views = page()?.views;
    const now = views?.now();
    list.replaceChildren(
      ...(views ? [...views.list.map(([name, words]) => line(words, name === now, "menuitemradio", () => (shut(), views.choose(name)))), el("hr")] : []),
      ...themes().map(([name, words]) => line(words, name === theme(), "menuitemradio", () => (shut(), setTheme(name)))),
      el("hr"),
      line(wording("view-compact"), compact(), "menuitemcheckbox", () => {
        setCompact(!compact());
        draw();
        list.querySelector<HTMLElement>("[role=menuitemcheckbox]")?.focus();
      }),
    );
  };
  const menu = opener(button, list, () => {
    draw();
    list.querySelector<HTMLElement>("[aria-checked=true]")?.focus();
  });
  list.onkeydown = (event) => {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      step([...list.querySelectorAll<HTMLElement>("button")], event.key === "ArrowDown");
    } else if (event.key === "Escape") {
      event.preventDefault();
      shut();
    }
  };
  return menu.node;
}
