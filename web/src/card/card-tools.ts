// A card page's AI tools for the whole card (`wholeCard`): the sparkle beside the card menu opens a text's menu
// (`textTools()` of card-text.ts); Translate… and "Ask for a change…" ask first in the line under the header's
// buttons (`bar`), sent with Enter. The background model changes the card's texts with words one after the other
// (`rewrite`): every greeting, the texts of the mode in view, the notes at a depth, the greetings of a chat of
// several and Creator notes, of the language in view (`places`), each asked of as its own tools ask (`asked`:
// the same label, the card as context). Each change waits by its text's place (`at`, as
// card-texts.ts gives it to the text's block), shown inside the text by the block (card-block.ts, `WholeCard`)
// with Keep and Undo; the line says how many wait, with Keep all, one save, and Undo all.
// Traps: a place is a position (`greetings.2`), so a change waits only while its text reads as it was asked of
// (`then`) in the same language; a text changed meanwhile gets no change, or loses the one waiting. One tool runs
// at a time, and none while changes wait or a translation of the card shows.
import { rewrite } from "../api/client";
import type { CardEdit } from "../api/generated/CardEdit";
import type { EditText } from "../api/generated/EditText";
import { aiChange, asked, type Change, type WholeCard } from "./card-block";
import { inMode, save, SHOWN, textKinds, type Card } from "./card-page";
import { textTools } from "./card-text";
import { announce, changesBar, el, failure, reason } from "../dom";
import { menu } from "../dialogs";
import { groupGreetingName, noteName, textName, usedIn } from "./modes";
import { wording } from "../language/language";

/** The place on the card of its text `kind`, the `at`th of its kind where it has several. */
export const place = (kind: string, at?: number) => (at === undefined ? kind : `${kind}.${at}`);

/** A text the whole card's tools change: its place, what the model is told it is, how it is read and written. */
interface Place {
  at: string;
  what: string;
  read(card: CardEdit): string;
  write(card: CardEdit, text: string): void;
}

/** A change waiting for Keep, with the text as it was asked of and the language it is in. */
interface Waiting extends Change {
  then: string;
  language: string | null;
}

/** The card's texts the tools change, in the page's order: those of the mode in view (of every mode, `all`), every greeting. */
export function places(c: Card, all = false): Place[] {
  const one = c.edit.characters[SHOWN];
  if (!one) return [];
  const mode = inMode(c);
  // What the model is told a text is: its block's label (card-texts.ts), as its own tools tell it.
  const list = <K extends "greetings" | "group_greetings" | "depth_prompts" | (ReturnType<typeof textKinds>)[number][0]>(kind: K, what: (part: EditText, at: number, several: boolean) => string, used = true): Place[] => {
    const parts = one[kind] as EditText[];
    const several = (used ? parts.filter((part) => usedIn(part, mode)) : parts).length > 1;
    return parts.flatMap((part, at) =>
      used && !all && !usedIn(part, mode)
        ? []
        : [{ at: place(kind, at), what: what(part, at, several), read: (card) => (card.characters[SHOWN]?.[kind] as EditText[] | undefined)?.[at]?.text ?? "", write: (card, text) => void ((card.characters[SHOWN][kind] as EditText[])[at].text = text) }],
    );
  };
  return [
    ...list("greetings", () => wording("card-texts-first-message"), false),
    ...textKinds().flatMap(([kind, name]) => list(kind, (part, _, several) => textName(name, part, several))),
    ...list("depth_prompts", (_, at) => noteName(one.depth_prompts[at].depth)),
    ...list("group_greetings", (_, at, several) => groupGreetingName(at, several), false),
    { at: place("creator_notes"), what: wording("card-texts-creator-notes"), read: (card) => card.characters[SHOWN]?.creator_notes ?? "", write: (card, text) => void (card.characters[SHOWN].creator_notes = text) },
  ];
}

type Tool = (ReturnType<typeof textTools>)[number];

/** The whole card's AI tools of the card `c`: what its texts' blocks are given, the line under the buttons, the sparkle, and Stop. */
export interface CardTools {
  page: WholeCard;
  bar: HTMLElement;
  /** The sparkle, made anew with the card's buttons, of a card that is made. */
  button(): HTMLElement;
  /** Stops the tool that runs: the page is left. */
  stop(): void;
}

export function wholeCard(c: Card): CardTools {
  const waiting = new Map<string, Waiting>();
  const working = new Set<string>();
  const watched = new Map<string, () => void>();
  const bar = el("div", { className: "banner card-ai", role: "status", hidden: true });
  let stopping: AbortController | null = null;
  let sparkle: HTMLButtonElement | null = null;
  /** Keep all's save, until done: a tool started meanwhile would ask of the texts as they were. */
  let saving = false;

  /** Whether a change still holds: its text reads as it was asked of, in the language in view. */
  const holds = (at: string, change: Waiting) => change.language === c.language && places(c, true).find((one) => one.at === at)?.read(c.edit) === change.then;
  const redraw = (at: string) => watched.get(at)?.();
  /** The sparkle can be pressed while no tool runs, no change waits, Keep all is not saving and no translation shows. */
  const enable = () => {
    if (sparkle) sparkle.disabled = !!stopping || saving || waiting.size > 0 || !!c.translating;
  };

  /** The line: how many changes wait, with Keep all and Undo all; hidden while none do. While a tool runs it is its own. */
  const drawBar = () => {
    for (const [at, change] of waiting) if (!holds(at, change)) waiting.delete(at);
    enable();
    if (stopping) return;
    bar.hidden = waiting.size === 0;
    if (bar.hidden) return void bar.replaceChildren();
    bar.replaceChildren(...changesBar(wording("dom-texts-changed-by-ai", { count: waiting.size }), keepAll, undoAll));
  };

  /** Keep all: every change that holds, saved in one save. */
  const keepAll = () => {
    const kept = [...waiting].filter(([at, change]) => holds(at, change));
    waiting.clear();
    drawBar();
    if (!kept.length) return;
    saving = true;
    enable();
    void save(
      c,
      (card) => {
        for (const [at, change] of kept) {
          const one = places(c, true).find((p) => p.at === at);
          if (one && one.read(card) === change.then) one.write(card, change.text);
        }
        // The texts show their new words while they are saved.
        for (const [at] of kept) redraw(at);
      },
      kept[0][1].made,
    ).finally(() => {
      saving = false;
      enable();
    });
  };

  const undoAll = () => {
    const undone = [...waiting.keys()];
    waiting.clear();
    drawBar();
    for (const at of undone) redraw(at);
  };

  /** Runs `one`, given `given`, over the card's texts with words, one after the other; their changes wait for Keep. */
  const run = async (one: Tool, given: string) => {
    const language = c.language;
    const texts = places(c).filter((p) => p.read(c.edit).trim());
    if (!texts.length) {
      drawBar();
      return announce(wording("card-tools-the-card-has-no"));
    }
    const stop = new AbortController();
    stopping = stop;
    enable();
    for (const p of texts) working.add(p.at);
    for (const p of texts) redraw(p.at);
    const { said, made } = aiChange(one.tool, one.name, given);
    let failed = false;
    for (const [done, p] of texts.entries()) {
      if (stop.signal.aborted) break;
      bar.replaceChildren(el("span", null, wording("card-tools-of-texts", { working: one.working, done: done + 1, count: texts.length })), el("button", { type: "button", className: "btn btn-secondary", onclick: () => stop.abort() }, wording("gen-stop")));
      bar.hidden = false;
      const then = p.read(c.edit);
      try {
        const changed = (await rewrite(asked(c.page, then, one.tool, p.what, given), stop.signal)).text;
        // Changed meanwhile, or in another language now: the answer is of words no longer there.
        if (changed !== then && c.language === language && p.read(c.edit) === then) waiting.set(p.at, { text: changed, said, made, then, language });
      } catch (error) {
        if (!stop.signal.aborted) c.notice.replaceChildren(failure(reason(error)));
        failed = true;
        break;
      } finally {
        working.delete(p.at);
        redraw(p.at);
      }
    }
    stopping = null;
    const left = [...working];
    working.clear();
    for (const at of left) redraw(at);
    drawBar();
    if (!failed && !stop.signal.aborted && waiting.size === 0) announce(wording("card-tools-no-changes"));
  };

  /** Translate… and "Ask for a change…": the line asks first, sent with Enter. */
  const ask = (one: Tool) => {
    const question = one.asks ?? "";
    const line = el("input", { type: "text", className: "field f-grow minw0", ariaLabel: question, placeholder: question, autocomplete: "off" });
    line.onkeydown = (event) => {
      if (event.key === "Escape" && !event.isComposing) {
        event.preventDefault();
        return drawBar();
      }
      if (event.key !== "Enter" || event.isComposing || !line.value.trim()) return;
      event.preventDefault();
      void run(one, line.value.trim());
    };
    bar.replaceChildren(line, el("button", { type: "button", className: "btn btn-secondary", onclick: drawBar }, wording("common-cancel")));
    bar.hidden = false;
    line.focus();
  };

  return {
    bar,
    page: {
      offer: (at, now) => {
        if (working.has(at)) return "working";
        const change = waiting.get(at);
        if (!change) return null;
        if (change.language === c.language && change.then === now) return change;
        waiting.delete(at);
        drawBar();
        return null;
      },
      settle: (at) => {
        waiting.delete(at);
        drawBar();
      },
      watch: (at, redraw) => void watched.set(at, redraw),
    },
    button: () => {
      const items = textTools().map((one) => ({
        label: one.name,
        shape: one.shape,
        apart: one.tool === "ask",
        action: () => (stopping ? undefined : one.asks ? ask(one) : void run(one, "")),
      }));
      const node = menu(wording("card-tools-ai-tools-for-the"), items, "sparkle", 20);
      sparkle = node.querySelector("button");
      enable();
      return node;
    },
    stop: () => stopping?.abort(),
  };
}
