// The user's own CSS (milestone 71, board "Your own CSS"): kept with the settings (`own_css`), it stands in a
// `<style>` after the app's stylesheet (`style`, the last in the head), so it wins where it weighs as much. The
// app (main.ts) and the companion's window show it at start and read it anew when the settings change elsewhere
// (`readOwnCss`). Settings › Advanced's last box (`ownCssGroup`) says how many lines it has, and "Edit" opens
// the dialog of 820 px whose mono field restyles the app as typed (`previewing`); Save keeps it, while Cancel,
// Escape, the × and leaving the page take the app back to what was saved. The dialog's link opens the page
// "Cardwave's CSS" in a window of its own (`openPage`), so the dialog and what is typed in it stay.
import { wording } from "../language/language";
import { changeSettings, getSettings } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import { el, group, item, newest } from "../dom";
import { formDialog } from "../dialogs";
import { openPage } from "../desktop";
import { LABELS } from "../setting-labels";

/** The address of the page "Cardwave's CSS" (views/css-reference.ts). */
export const CSS_PAGE = "#/settings/advanced/css";

/** The readings of the CSS kept: one that answers after a newer one, or after a save, is not taken. */
const order = newest();

/** The CSS kept, and what the dialog's field holds while it is open. */
let saved = "";
let previewing: string | null = null;

/** The `<style>` that holds the user's CSS, made the first time it is asked for, after every stylesheet the page has. */
let style: HTMLStyleElement | null = null;

/** Whether `sheet` is the user's own CSS, which the page "Cardwave's CSS" leaves out. */
export const isOwnCss = (sheet: CSSStyleSheet) => sheet.ownerNode !== null && sheet.ownerNode === style;

function draw(): void {
  style ??= document.head.appendChild(el("style", { id: "own-css" }));
  style.textContent = previewing ?? saved;
}

/** Shows `css` as the CSS kept, read (`mine`, its reading's number) or saved; while the dialog is open its field's CSS stays shown. */
export function showOwnCss(css: string, mine?: number): void {
  if (!order.take(mine)) return;
  saved = css;
  draw();
}

/**
 * Reads the CSS kept anew, or takes it from the settings `read` (the start's), and shows it. Where the server does not
 * answer, what shows stays: nothing to tell.
 */
export function readOwnCss(read?: Promise<Settings>): Promise<void> {
  const mine = order.ask();
  return (read ?? getSettings()).then((settings) => showOwnCss(settings.own_css, mine), () => {});
}

/** What the line says of the CSS: "None", or how many lines it has. */
export function linesOf(css: string): string {
  const text = css.trimEnd();
  if (!text.trim()) return wording("css-none");
  const lines = text.split("\n").length;
  return wording("css-lines", { count: lines });
}

/**
 * The last box of Settings › Advanced: the line "Your own CSS" with "Edit". `home` is the page the dialog
 * stands in; `read` says the line anew from the CSS kept, and `left` closes the dialog, taking its CSS back.
 */
export function ownCssGroup(home: () => HTMLElement): { node: HTMLElement; read(): void; left(): void } {
  const says = el("span", { className: "meta" });
  const say = () => (says.textContent = wording("css-about", { lines: linesOf(saved) }));
  const read = () => void readOwnCss().then(say);
  let open: HTMLDialogElement | null = null;
  const edit = () => {
    const field = el("textarea", { className: "field mono own-css-field w100 bb", ariaLabel: LABELS.advanced.css, rows: 18, spellcheck: false, value: saved });
    field.oninput = () => {
      previewing = field.value;
      draw();
    };
    const link = el("button", { type: "button", className: "textbtn fs-small", onclick: () => openPage(CSS_PAGE) }, wording("page-css"));
    const hint = el("p", { className: "hint m0" }, wording("css-hint") + " ", link);
    const box = formDialog(home(), LABELS.advanced.css, [hint, field], async () => {
      showOwnCss((await changeSettings({ own_css: field.value })).own_css);
      previewing = null;
      say();
      box.close();
    });
    box.classList.add("own-css-dialog");
    // Closed without Save, the app has the CSS kept again.
    box.addEventListener("close", () => {
      previewing = null;
      open = null;
      draw();
    });
    open = box;
    field.focus();
  };
  say();
  read();
  const node = group(
    null,
    null,
    el("div", { className: "group" }, item(LABELS.advanced.css, says, el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("css-edit-own"), onclick: edit }, wording("css-edit")))),
  );
  return { node, read, left: () => open?.close() };
}
