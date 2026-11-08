// A card's languages on its page: the language bar over the texts (`languageBar`), which picks whose texts show,
// and the card menu's "Translate the character…" (`translateDialog`): the background model translates every text of the card's
// first language one by one (`/api/rewrite`), then its own lorebook where asked; meanwhile and after, the texts
// show the original and the translation side by side (`translationView`), kept or undone as a whole with Keep all
// and Undo all. A kept language is a card of that language in the same file (the server's ccv4/languages.rs).
// What a text of another language offers, "Translate from [first]", is card-block.ts's (`source`).
// Trap: the translation is of the first language's texts, also while another is in view (`c.original`).
import { getSettings, keepTranslation, listLanguages, rewrite, translateLore } from "../api/client";
import type { EditCharacter } from "../api/generated/EditCharacter";
import type { Language } from "../api/generated/Language";
import type { LoreText } from "../api/generated/LoreText";
import { after, languageKey, load, person, textKinds, type Card } from "./card-page";
import { markdown } from "./card-text";
import { groupGreetingName, noteName } from "./modes";
import { changesBar, el, failure, reason, segmented, selectField, switchBox } from "../dom";
import { formDialog } from "../dialogs";
import { remember } from "../storage";
import { languageName, wording } from "../language/language";

/** One text being translated: its name on the page, its block, its words and, once there, the translation. */
interface Pair {
  label: string;
  /** None for the creator notes, which the page has without their block. */
  reference: string | null;
  text: string;
  translated: string | null;
}

/** A translation of the whole card on its way, or waiting for Keep all or Undo all. */
export interface Translating {
  language: Language;
  /** The card's first language, as its page names it. */
  from: string;
  pairs: Pair[];
  /** Whether its own lorebook is translated too, and its entries once they are. */
  lorebook: boolean;
  lore: LoreText[] | null;
  stop: AbortController;
  done: boolean;
}

/** The card's texts in its first language, whatever language is in view. */
const firstTexts = (c: Card): EditCharacter | undefined => (c.language ? c.original?.characters[0] : person(c));

/** The name of the card's first language in the language in use (`inSentence`: inside a sentence); "Original" where the server cannot tell it. */
export const firstName = (c: Card, inSentence = false) => {
  const first = c.edit.languages?.[0];
  return first ? languageName(first.code, first.name, inSentence) : wording("card-languages-original");
};

/** The language bar over the texts: the switch of the card's languages, which picks whose texts show. None for a card in one. */
export function languageBar(c: Card): HTMLElement | null {
  const all = c.edit.languages ?? [];
  if (all.length < 2 || c.id === null || c.translating) return null;
  const card = c.id;
  const pick = (code: string) =>
    void after(c, async () => {
      c.language = code === all[0].code ? null : code;
      remember(languageKey(card), c.language ?? "");
      await load(c);
    });
  const now = c.language ?? all[0].code;
  return el(
    "div",
    { className: "flex f-col ai-e g-4 mode-bar" },
    el("div", { className: "flex ai-c g-8" }, el("span", { className: "meta" }, wording("settings-language")), segmented(wording("settings-language"), all.map((one): [string, string] => [one.code, languageName(one.code, one.name)]), now, pick)),
  );
}

/** The texts of `one` a translation translates, those with words, each named as the page names it. */
function pairsOf(one: EditCharacter): Pair[] {
  const pairs: Pair[] = [];
  const add = (label: string, reference: string | null, text: string) => {
    if (text.trim()) pairs.push({ label, reference, text, translated: null });
  };
  one.greetings.forEach((greeting, at) => add(one.greetings.length > 1 ? wording("card-languages-first-message", { at: at + 1 }) : wording("card-texts-first-message"), greeting.reference, greeting.text));
  for (const [kind, name] of textKinds()) one[kind].forEach((part, at) => add(one[kind].length > 1 ? wording("card-languages-numbered", { name, at: at + 1 }) : name, part.reference, part.text));
  for (const part of one.depth_prompts) add(noteName(part.depth), part.reference, part.text);
  one.group_greetings.forEach((greeting, at) => add(groupGreetingName(at, one.group_greetings.length > 1), greeting.reference, greeting.text));
  add(wording("card-texts-creator-notes"), null, one.creator_notes);
  return pairs;
}

/** Whether the card has a lorebook of its own with entries to translate. */
const ownLore = (c: Card) => c.lorebooks.some((book) => "reference" in book && book.entries > 0);

/**
 * "Translate the character": the language (the one the AI writes in first, the card's own languages left out) and,
 * where the card has its own lorebook, "Its lorebook too", on; Translate starts it.
 */
export function translateDialog(c: Card): void {
  const notice = el("div", { className: "note" });
  const has = (c.edit.languages ?? []).map((one) => one.code);
  let offered: Language[] = [];
  const field = selectField([], "", () => {}, { id: "translate-language", ariaLabel: wording("settings-language"), disabled: true });
  const lorebook = switchBox({ checked: true, id: "translate-lore" });
  const box = formDialog(
    c.node,
    wording("card-languages-translate-the-card"),
    [
      el("label", { className: "label", htmlFor: "translate-language" }, wording("settings-language")),
      field.node,
      ownLore(c) && el("label", { className: "flex ai-c jc-sb g-12" }, el("span", null, wording("card-languages-its-lorebook-too")), lorebook),
      notice,
    ],
    async () => {
      const language = offered.find((one) => one.code === field.value);
      if (!language) throw new Error(wording("card-languages-choose-a-language"));
      box.close();
      void translate(c, language, ownLore(c) && lorebook.checked);
    },
    wording("card-languages-translate"),
  );
  void Promise.all([listLanguages(), getSettings()]).then(
    ([languages, settings]) => {
      offered = languages.filter((one) => !has.includes(one.code));
      field.offer(offered.map((one) => ({ value: one.code, label: languageName(one.code, one.name) })));
      field.value = offered.some((one) => one.code === settings.language) ? settings.language : (offered[0]?.code ?? "");
      field.field.disabled = false;
      field.field.focus();
    },
    (error: unknown) => notice.replaceChildren(failure(reason(error))),
  );
}

/** Translates the card's texts one by one into `language`, then its lorebook where asked; the page shows each as it comes. */
async function translate(c: Card, language: Language, lorebook: boolean): Promise<void> {
  const one = firstTexts(c);
  if (!one || c.id === null) return;
  const card = c.id;
  const now: Translating = { language, from: firstName(c), pairs: pairsOf(one), lorebook, lore: null, stop: new AbortController(), done: false };
  c.translating = now;
  c.render();
  try {
    for (const pair of now.pairs) {
      pair.translated = (await rewrite({ text: pair.text, tool: "translate", what: pair.label, given: language.name }, now.stop.signal)).text;
      if (c.translating === now) c.render();
    }
    if (lorebook) now.lore = await translateLore(card, language.code, now.stop.signal);
    now.done = true;
  } catch (error) {
    if (c.translating !== now) return;
    c.translating = null;
    if (!now.stop.signal.aborted) c.notice.replaceChildren(failure(reason(error)));
  }
  if (c.translating === now) c.render();
}

/** Keep all: the card holds the language from now on, and its texts show. */
function keepAll(c: Card, now: Translating): void {
  const card = c.id;
  if (card === null) return;
  void c.attempt(async () => {
    await c.queue;
    await keepTranslation(card, {
      version: c.edit.version,
      language: now.language.code,
      texts: now.pairs.flatMap((pair) => (pair.reference && pair.translated !== null ? [{ reference: pair.reference, text: pair.translated }] : [])),
      creator_notes: now.pairs.find((pair) => pair.reference === null)?.translated ?? undefined,
      lore: now.lore ?? [],
    });
    c.translating = null;
    c.language = now.language.code;
    remember(languageKey(card), c.language);
    await load(c);
  });
}

/** Undo all, and Stop: the card stays as it was. */
function undoAll(c: Card, now: Translating): void {
  now.stop.abort();
  c.translating = null;
  c.render();
}

/** Words marked new: each part of the Markdown's text inside an `ins`, as the board draws a translation. */
function marked(nodes: HTMLElement[]): HTMLElement[] {
  for (const node of nodes) {
    if (node.tagName === "UL" || node.tagName === "OL") {
      marked([...node.children] as HTMLElement[]);
      continue;
    }
    const ins = el("ins", { className: "ch" });
    ins.append(...node.childNodes);
    node.append(ins);
  }
  return nodes;
}

/** The banner over the texts: how far the translation is, with Stop, then Keep all and Undo all. */
function banner(c: Card, now: Translating): HTMLElement {
  const count = now.pairs.length;
  const texts = wording("card-languages-texts", { count });
  if (!now.done) {
    const ready = now.pairs.filter((pair) => pair.translated !== null).length;
    const doing = ready < count ? wording("card-languages-of", { ready, texts }) : wording("card-languages-its-lorebook");
    return el("div", { className: "banner", role: "status" }, el("span", null, wording("card-languages-translating-into", { name: languageName(now.language.code, now.language.name, true), doing })), el("button", { type: "button", className: "btn btn-secondary", onclick: () => undoAll(c, now) }, wording("gen-stop")));
  }
  const entries = now.lore?.length ? wording("card-languages-and-entries", { count: now.lore.length }) : "";
  const said = wording("card-languages-translated-into-keep-the", { name: languageName(now.language.code, now.language.name, true), texts, entries });
  return el("div", { className: "banner", role: "status" }, ...changesBar(said, () => keepAll(c, now), () => undoAll(c, now)));
}

/** The texts while a translation is shown: each its original and its translation side by side, the latter dimmed until it comes. */
export function translationView(c: Card, now: Translating): HTMLElement[] {
  const side = (name: string, shown: HTMLElement) => el("div", null, el("p", { className: "lang" }, name), shown);
  return [
    banner(c, now),
    ...now.pairs.map((pair) =>
      el(
        "section",
        { className: "tb", ariaLabel: pair.label },
        el("div", { className: "tb-head" }, el("h2", { className: "tb-name" }, pair.label)),
        el(
          "div",
          { className: "tb-body" },
          el(
            "div",
            { className: "tr" },
            side(now.from, el("div", { className: "md" }, ...markdown(pair.text))),
            side(languageName(now.language.code, now.language.name), pair.translated === null ? el("div", { className: "md working" }, ...markdown(pair.text)) : el("div", { className: "md" }, ...marked(markdown(pair.translated)))),
          ),
        ),
      ),
    ),
  ];
}
