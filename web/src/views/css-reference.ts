// The page "Cardwave's CSS" (board "Cardwave's CSS"), at `#/settings/advanced/css` with the path "Settings /
// Advanced / Cardwave's CSS": what the user's own CSS (../settings/own-css.ts) can use. A line on what it is; Variables,
// every variable of the stylesheet's `:root` with its light and its dark value (`variables`), searched by name
// as typed; Class names, the main ones with what they style (`CLASSES`); Snippets, each a short override with
// "Copy" (`SNIPPETS`). The variables are read from the stylesheet the page has (`rootRule`), the user's own CSS
// left out, so the page never goes stale; css-reference.test.ts checks that every class name and every name a
// snippet uses is in styles.css. The dialog "Your own CSS" opens it in a window of its own.
import { wording } from "../language/language";
import { copyText, el, group, noticeBox, oneAtATime, searchField, type View } from "../dom";
import { isOwnCss } from "../settings/own-css";

/** A variable with its value in the light theme and in the dark one, which are the same where it has one. */
export interface Variable {
  name: string;
  light: string;
  dark: string;
}

/** The main names the app's look goes by, with what each styles. */
export const CLASSES: { name: string; about: () => string }[] = [
  { name: ".rail", about: () => wording("cssref-rail") },
  { name: ".main", about: () => wording("cssref-main") },
  { name: ".crumbs", about: () => wording("cssref-crumbs") },
  { name: ".group", about: () => wording("cssref-group") },
  { name: ".item", about: () => wording("cssref-item") },
  { name: ".row", about: () => wording("cssref-row") },
  { name: ".tile", about: () => wording("cssref-tile") },
  { name: ".msg", about: () => wording("cssref-msg") },
  { name: ".bubble", about: () => wording("cssref-bubble") },
  { name: ".composer", about: () => wording("cssref-composer") },
  { name: ".dialog", about: () => wording("cssref-dialog") },
  { name: ".btn-primary", about: () => wording("cssref-btn-primary") },
  { name: ".switch", about: () => wording("cssref-switch") },
  { name: ".pill", about: () => wording("cssref-pill") },
  { name: ".notice", about: () => wording("cssref-notice") },
];

/** Short overrides, each to be copied with one press. */
export const SNIPPETS: { title: () => string; css: string }[] = [
  { title: () => wording("cssref-snippet-green"), css: ":root { --accent: #2E7D32; --accent-hover: #1B5E20; }" },
  { title: () => wording("cssref-snippet-square"), css: ".bubble { border-radius: 6px; }" },
  { title: () => wording("cssref-snippet-larger"), css: ":root { --fs-body: 15px; }" },
  { title: () => wording("cssref-snippet-wider"), css: "dialog.dialog { width: 480px; }" },
  { title: () => wording("cssref-snippet-tighter"), css: ".page-col { gap: var(--s16); }" },
  { title: () => wording("cssref-snippet-black"), css: ":root { --page: light-dark(#FFFFFF, #000000); }" },
];

/** `value` with each `light-dark(light, dark)` in it as its argument `which`: 0 the light one, 1 the dark one. */
function themed(value: string, which: 0 | 1): string {
  const at = value.indexOf("light-dark(");
  if (at < 0) return value;
  const start = at + "light-dark(".length;
  let depth = 0;
  let comma = -1;
  for (let index = start; index < value.length; index++) {
    const sign = value[index];
    if (sign === "(") depth++;
    else if (sign === ")" && depth-- === 0) {
      const chosen = which === 0 ? value.slice(start, comma) : value.slice(comma + 1, index);
      return value.slice(0, at) + chosen.trim() + themed(value.slice(index + 1), which);
    } else if (sign === "," && depth === 0) comma = index;
  }
  return value;
}

/** The variables a rule's text sets (`:root { --bg: light-dark(#fff, #141414); … }`), in its order; one set twice counts as the later. */
export function variables(rule: string): Variable[] {
  const all = new Map<string, Variable>();
  for (const [, name, value] of rule.matchAll(/(--[\w-]+)\s*:\s*([^;}]*)/g)) {
    const text = value!.trim();
    all.delete(name!);
    all.set(name!, { name: name!, light: themed(text, 0), dark: themed(text, 1) });
  }
  return [...all.values()];
}

/** The text of the app's stylesheet's rules `:root` that set the variables, as the browser has them, in their order. */
function rootRule(): string {
  const texts: string[] = [];
  for (const sheet of document.styleSheets) {
    if (isOwnCss(sheet)) continue;
    for (const rule of sheet.cssRules) {
      if (rule instanceof CSSStyleRule && rule.selectorText === ":root" && rule.cssText.includes("--")) texts.push(rule.cssText);
    }
  }
  return texts.join(" ");
}

/** The variables whose name holds what was typed, whatever its case; all where nothing was. */
const found = (all: Variable[], typed: string) => all.filter(({ name }) => name.includes(typed.trim().toLowerCase()));

/** A line of a box: a name in mono over what it says. */
const line = (name: string, about: string) => el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label mono" }, name), el("span", { className: "meta" }, about)));

export function cssReferenceView(): View {
  const all = variables(rootRule());
  const asked = { q: "" };
  const lines = el("div", { className: "group mt-10" });
  const draw = () => {
    const shown = found(all, asked.q);
    lines.replaceChildren(
      ...(shown.length
        ? shown.map(({ name, light, dark }) => line(name, light === dark ? light : wording("cssref-in-dark", { light, dark })))
        : [el("div", { className: "item meta" }, wording("cssref-none"))]),
    );
  };
  draw();
  const snippet = ({ title: titled, css }: (typeof SNIPPETS)[number]) => {
    const title = titled();
    const notice = noticeBox();
    const attempt = oneAtATime(notice);
    const copy = el("button", { type: "button", className: "btn btn-quiet btn-fit", ariaLabel: wording("cssref-copy-of", { title }), onclick: () => attempt(() => copyText(css, wording("cssref-copied"))) }, wording("cssref-copy"));
    return el("div", { className: "flex f-col g-8" }, el("div", { className: "flex ai-c jc-sb" }, el("span", { className: "semi" }, title), copy), notice, el("pre", { className: "code mono" }, css));
  };
  const node = el(
    "section",
    { className: "main main-form" },
    el(
      "header",
      { className: "pbar" },
      el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("a", { href: "#/settings/advanced" }, wording("page-advanced")), "/", el("b", null, wording("page-css"))),
    ),
    el(
      "div",
      { className: "page-col mt-12" },
      el("p", { className: "m0" }, wording("cssref-about-1"), el("span", { className: "mono" }, ":root"), wording("cssref-about-2")),
      group(wording("cssref-variables"), null, searchField(wording("cssref-search"), wording("cssref-find"), asked, draw), lines, el("p", { className: "hint mt-8" }, wording("cssref-all", { count: String(all.length) }))),
      group(wording("cssref-classes"), null, el("div", { className: "group" }, ...CLASSES.map(({ name, about }) => line(name, about())))),
      group(wording("cssref-snippets"), null, ...SNIPPETS.map(snippet)),
    ),
  );
  return { node: node };
}
