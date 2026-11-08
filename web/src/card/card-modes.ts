// A card's modes on its page: the mode bar over the texts (`modeBar`), which picks whose texts show; each text's
// mode tag (`modeTagOf`), whose menu sets which modes use it; and the card menu's "Add a way to chat…" (`askMode`) or
// "Modes…" (`modesDialog`), with Rename, Make default and Remove. None of it shows on a card without modes.
import type { CardEdit } from "../api/generated/CardEdit";
import type { EditText } from "../api/generated/EditText";
import { after, inMode, modes, person, save, SHOWN, type Card, type Kind } from "./card-page";
import { el, segmented } from "../dom";
import { dialog, formDialog, menuOn } from "../dialogs";
import { icon } from "../icons";
import { addedMode, firstMode, modeTag, pressMode, removeMode, renameMode, sameMode } from "./modes";
import { wording } from "../language/language";
import { comma } from "../format";

/**
 * The mode tag of the text `at` of `kind`, named `label`: which modes use it, in its menu's words. Its menu sets
 * them: All modes, a line per mode, and "A text for each mode", which leaves it to the mode in view, so that each
 * other mode shows an empty one to write. None without modes, or for a text not written yet.
 */
export function modeTagOf(c: Card, kind: Kind | "depth_prompts", at: number, label: string): HTMLElement | null {
  const all = modes(c);
  const now = inMode(c);
  const part = person(c)?.[kind][at];
  if (!all.length || !part || c.id === null || now === null) return null;
  const set = (change: (own: EditText) => void) =>
    void save(c, (card) => {
      const own: EditText | undefined = card.characters[SHOWN][kind][at];
      if (own) change(own);
    }).then(() => after(c, () => c.render()));
  const others = all.filter((one) => !sameMode(one, now));
  const button = el("button", { type: "button", className: "mtag", ariaLabel: wording("card-modes-modes-of", { label, modeTag: modeTag(part) }) }, modeTag(part), icon("down", 14));
  const tag = menuOn(button, [
    { label: wording("card-modes-all-modes"), chosen: !part.modes?.length, action: () => set((own) => pressMode(own, null, all)) },
    ...all.map((one) => ({ label: wording("card-modes-only", { one }), chosen: !!part.modes?.some((other) => sameMode(one, other)), action: () => set((own) => pressMode(own, one, all)) })),
    {
      label: wording("card-modes-a-text-for-each"),
      sub: wording("card-modes-adds-an-empty-for", { label, join: others.join(comma()) }),
      apart: true,
      hidden: !others.length,
      action: () => set((own) => (own.modes = [now])),
    },
  ]);
  tag.classList.add("mtag-menu");
  return tag;
}

/** The mode bar over the texts: the switch of the card's modes, which picks whose texts show. None without modes. */
export function modeBar(c: Card): HTMLElement | null {
  const now = inMode(c);
  if (now === null || c.id === null) return null;
  const pick = (chosen: string) =>
    void after(c, () => {
      c.mode = chosen;
      c.render(chosen);
    });
  return el(
    "div",
    { className: "flex f-col ai-e g-4 mode-bar" },
    el("div", { className: "flex ai-c g-8" }, el("span", { className: "meta" }, wording("card-modes-mode")), segmented(wording("card-modes-mode"), modes(c).map((one): [string, string] => [one, one]), now, pick)),
    el("span", { className: "meta fs-caption" }, wording("card-modes-the-texts-below-are")),
  );
}

/** The default mode's name where the first way to chat is added: the card's own texts are it. */
const firstName = () => wording("card-modes-first-default");

/** Adds the mode `name` to the card; the first added comes beside the card's own texts as the default (`addedMode`). */
export const addMode = (c: Card, name: string) => changeModes(c, (card) => addedMode(card, name, firstName()));

/** Saves a change of the card's modes, made in all its texts, and draws the page and the modes' dialog anew. */
const changeModes = (c: Card, change: (card: CardEdit) => void) =>
  void save(c, change).then(() =>
    after(c, () => {
      c.modesShown?.();
      c.render();
    }),
  );

/** Asks a mode's name in a dialog called `title`, holding `name` first; `done` is told a name no other mode has. */
export function askMode(c: Card, title: string, name: string, done: (typed: string) => void): void {
  const field = el("input", { id: "mode-name", className: "field", value: name, required: true, autocomplete: "off", maxLength: 40 });
  const box = formDialog(
    c.node,
    title,
    [el("label", { htmlFor: field.id }, wording("common-name")), field],
    async () => {
      const typed = field.value.trim();
      if (!typed) throw new Error(wording("card-modes-a-mode-needs-a"));
      const taken = modes(c).length ? modes(c) : [firstName()];
      if (taken.some((one) => sameMode(one, typed) && !sameMode(one, name))) throw new Error(wording("card-modes-the-card-has-a", { typed }));
      box.close();
      done(typed);
    },
    name ? wording("common-save") : wording("account-add-button"),
  );
  field.focus();
}

/**
 * The card's modes in a dialog, the default first: each with Rename, Make default and Remove, which leaves a
 * text used in it alone in all modes; "Add a way to chat" under them.
 */
export function modesDialog(c: Card): void {
  const list = el("ul", { className: "rows-plain modes-list" });
  const rename = (from: string) =>
    askMode(c, wording("card-modes-rename-mode"), from, (to) =>
      changeModes(c, (card) => {
        if (sameMode(c.mode ?? "", from)) c.mode = to;
        renameMode(card, from, to);
      }),
    );
  const fill = () =>
    list.replaceChildren(
      ...modes(c).map((one, at) =>
        el(
          "li",
          { className: "item item-compact" },
          el("span", { className: "f-grow mode-name" }, one, at === 0 && el("span", { className: "meta" }, wording("card-modes-default"))),
          el("button", { type: "button", className: "btn btn-quiet", onclick: () => rename(one) }, wording("voices-rename")),
          at > 0 && el("button", { type: "button", className: "btn btn-quiet", onclick: () => changeModes(c, (card) => firstMode(card, one)) }, wording("card-modes-make-default")),
          el("button", { type: "button", className: "btn btn-quiet c-danger", onclick: () => changeModes(c, (card) => removeMode(card, one)) }, wording("mcp-remove")),
        ),
      ),
    );
  fill();
  c.modesShown = fill;
  const add = el("button", { type: "button", className: "btn btn-secondary", onclick: () => askMode(c, wording("card-modes-add-mode"), "", (name) => addMode(c, name)) }, icon("plus", 16), wording("card-modes-add-mode"));
  const box = dialog(
    c.node,
    wording("card-modes-modes"),
    el("div", { className: "flex f-col g-12" }, list, el("p", { className: "meta" }, wording("card-modes-a-chat-starts-in")), el("div", { className: "flex g-8" }, add)),
  );
  box.addEventListener("close", () => (c.modesShown = null));
}
