// A card's texts as its page shows them, each written where it stands (`textBlock` of card-block.ts): First message
// with its greetings one at a time (`firstMessage`), and the texts under it in the card page's order (`reading`):
// Description to Instructions after the chat, the notes some messages back, the group chat greetings, Creator notes
// and Talkativeness. The card's page (views/character.ts) and the chat's split view (chat/split.ts) draw them from a
// card's state (card-page.ts); `begin` starts a chat with the character in view. Each text is given its place
// (`place` of card-tools.ts), by which the whole card's AI tools have its change wait.
import type { DepthText } from "../api/generated/DepthText";
import type { EditCharacter } from "../api/generated/EditCharacter";
import type { EditText } from "../api/generated/EditText";
import { textBlock, type Source } from "./card-block";
import { inPlace } from "../in-place";
import { firstName } from "./card-languages";
import { modeTagOf } from "./card-modes";
import { place } from "./card-tools";
import { after, inMode, person, save, SHOWN, textKinds, type Card, type Kind } from "./card-page";
import { announce, el } from "../dom";
import { icon, type IconName } from "../icons";
import { beginChat } from "../library/library-actions";
import { groupGreetingName, noteName, textName, usedIn } from "./modes";
import { wording } from "../language/language";

/** What a new card shows before "More texts", after First message. */
const FIRST: readonly Kind[] = ["description", "personality", "scenario"];

/** A talkativeness, from 0 to 1, as the whole percentage it shows. */
const percent = (talkativeness: number) => Math.round(talkativeness * 100);

/** Starts a chat with the character in view, opening with its greeting `greeting`. */
export const begin = (c: Card, greeting: number) =>
  c.attempt(async () => {
    await c.queue;
    const character = c.detail?.characters[SHOWN];
    if (c.detail && character) await beginChat([{ version_id: c.detail.card.version_id, character: character.id }], greeting);
  });

/** First message's head: the arrows through the greetings, which of them is in view, and "+" for one more; neither while no greeting has words. */
function flipper(c: Card, one: EditCharacter, at: number, count: number): HTMLElement {
  const flip = (by: number) =>
    after(c, () => {
      // After the last greeting comes the first again.
      c.greetingAt = (at + by + count) % count;
      c.render(by < 0 ? wording("card-texts-previous-greeting") : wording("card-texts-next-greeting"));
    });
  const step = (by: number, label: string, shape: IconName) =>
    el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: label, title: label, onclick: () => void flip(by) }, icon(shape, 16));
  const add = () =>
    after(c, () => {
      c.adding = true;
      c.greetingAt = one.greetings.length;
      c.render();
    });
  const written = one.greetings.some((greeting) => greeting.text.trim());
  return el(
    "div",
    { className: "flex ai-c g-2 ml-8" },
    ...(count > 1 ? [step(-1, wording("card-texts-previous-greeting"), "left"), el("span", { className: "meta count" }, wording("card-texts-greeting-at", { at: at + 1, count })), step(1, wording("card-texts-next-greeting"), "right")] : written ? [el("span", { className: "meta count" }, "1 / 1")] : []),
    !c.adding && written && el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-texts-add-greeting"), title: wording("card-texts-add-greeting"), onclick: () => void add() }, icon("plus", 16)),
  );
}

/** First message: its greetings one at a time, "+" for one more, and the button that starts a chat with it. */
export function firstMessage(c: Card, one: EditCharacter): HTMLElement {
  const count = one.greetings.length + (c.adding ? 1 : 0);
  c.greetingAt = Math.min(c.greetingAt, Math.max(0, count - 1));
  const at = c.greetingAt;
  const greeting = one.greetings[at] as EditText | undefined;
  const remove = () =>
    save(c, (card) => card.characters[SHOWN].greetings.splice(at, 1)).then(() =>
      after(c, () => {
        announce(wording("card-texts-greeting-deleted-earlier-versions"));
        c.render(wording("card-texts-add-greeting"));
      }),
    );
  const canStart = c.id !== null && !!greeting?.text.trim() && !!c.detail?.characters[SHOWN];
  return textBlock(c.page, {
    label: wording("card-texts-first-message"),
    what: wording("card-texts-the-first-message"),
    empty: wording("card-texts-first-message-empty"),
    read: () => person(c)?.greetings[at]?.text ?? "",
    reference: () => person(c)?.greetings[at]?.reference ?? null,
    source: sourceOf(c, (first) => first.greetings[at]?.text),
    at: greeting ? place("greetings", at) : undefined,
    write: (card, text) => {
      const list = card.characters[SHOWN].greetings;
      if (greeting && list[at]) list[at].text = text;
      else if (text) list.push({ reference: null, text });
      if (!greeting) c.adding = false;
    },
    greeting: true,
    // "New chat" is ready at the first letter, not only once leaving saves it.
    input: (text) => {
      const typed = !!text.trim();
      if (typed === c.typed) return;
      c.typed = typed;
      c.drawState();
    },
    head: [flipper(c, one, at, count)],
    tools: count > 1 && greeting ? [el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: wording("card-texts-delete-this-greeting"), title: wording("card-texts-delete-this-greeting"), onclick: () => void remove() }, icon("trash", 16))] : [],
    under: canStart && el("div", null, el("button", { type: "button", className: "btn btn-quiet btn-sm", onclick: () => begin(c, at) }, wording("card-texts-start-with-this-greeting"))),
    begun: c.adding && !greeting,
    // A greeting added is one of the others now.
    saved: () => {
      c.typed = null;
      void after(c, () => c.render());
    },
  });
}

/**
 * What "Translate from …" of a text translates while another language than the card's first is in view: `pick`'s
 * text of the first language's character, where it has words.
 */
function sourceOf(c: Card, pick: (first: EditCharacter) => string | undefined): () => Source | null {
  return () => {
    const into = c.edit.languages?.find((one) => one.code === c.language)?.name;
    const first = c.original?.characters[SHOWN];
    const text = first && pick(first);
    return into && text?.trim() ? { from: firstName(c, true), text, into } : null;
  };
}

/**
 * The card's texts of `kind` used in the mode in view: mostly one; several where it has a block for each part. A
 * kind without one in view has an empty text to write, used in this mode where texts of it are in others; a note
 * at a depth (`depth_prompts`, named by its depth) has none.
 */
function texts(c: Card, one: EditCharacter, kind: Kind | "depth_prompts", name: string, what: string): HTMLElement[] {
  const now = inMode(c);
  const all: EditText[] = one[kind];
  const inView = all.flatMap((part, at) => (usedIn(part, now) ? [{ part, at }] : []));
  if (!inView.length && kind !== "depth_prompts") inView.push({ part: { reference: null, text: "", modes: all.length && now !== null ? [now] : [] }, at: all.length });
  const several = inView.length > 1;
  return inView.map(({ part, at }) => {
    const label = kind === "depth_prompts" ? noteName((part as DepthText).depth) : textName(name, part, several);
    return textBlock(c.page, {
      label,
      what,
      read: () => person(c)?.[kind][at]?.text ?? "",
      reference: () => person(c)?.[kind][at]?.reference ?? null,
      source: sourceOf(c, (first) => first[kind][at]?.text),
      at: at < all.length ? place(kind, at) : undefined,
      clamp: true,
      head: [modeTagOf(c, kind, at, label)],
      // A text written where the kind had none in view is one of the card's now, with its tag.
      saved: at === all.length ? () => void after(c, () => c.render()) : undefined,
      write: (card, text) => {
        const list: EditText[] = card.characters[SHOWN][kind];
        const own = list[at];
        if (own) own.text = text;
        else if (text) list.push({ ...part, text });
      },
    });
  });
}

/** The greetings of a chat of several, where the card has them: each a text, taken off when emptied. */
function groupGreetings(c: Card, one: EditCharacter): HTMLElement[] {
  const several = one.group_greetings.length > 1;
  return one.group_greetings.map((_, at) =>
    textBlock(c.page, {
      label: groupGreetingName(at, several),
      what: wording("card-texts-the-greeting"),
      read: () => person(c)?.group_greetings[at]?.text ?? "",
      reference: () => person(c)?.group_greetings[at]?.reference ?? null,
      source: sourceOf(c, (first) => first.group_greetings[at]?.text),
      at: place("group_greetings", at),
      clamp: true,
      write: (card, text) => {
        const own = card.characters[SHOWN].group_greetings[at];
        if (own) own.text = text;
      },
    }),
  );
}

/** The character's talkativeness, a whole percentage written where it stands. */
function talkativeness(c: Card, one: EditCharacter): HTMLElement {
  const section = el("section", { className: "tb", ariaLabel: wording("card-texts-talkativeness") }, el("div", { className: "tb-head" }, el("h2", { className: "tb-name" }, wording("card-texts-talkativeness"))));
  const content = el("div", { className: "tb-body" });
  let held: number | null = null;
  const talk = () => person(c)?.talkativeness ?? one.talkativeness;
  inPlace(content, {
    label: wording("card-texts-talkativeness-in-percent-from"),
    value: () => String(percent(held ?? talk())),
    show: () => [el("div", { className: "md" }, el("p", null, wording("card-texts-talkativeness-said", { percent: percent(held ?? talk()) })))],
    editing: (on) => section.classList.toggle("is-edit", on),
    commit: (text) => {
      const typed = Number(text.trim());
      if (!text.trim() || !Number.isInteger(typed) || typed < 0 || typed > 100) return;
      // Typed back to what it was, it is what it was, which may say more than a whole percentage (0.333 is 33).
      const value = percent(talk()) === typed ? talk() : typed / 100;
      held = value;
      void save(c, (card) => (card.characters[SHOWN].talkativeness = value)).then(() => (held = null));
    },
  });
  section.append(content);
  return section;
}

/** The texts under First message and the box: those of a new card until "More texts", then all. */
export function reading(c: Card, one: EditCharacter | undefined, whole: boolean): (HTMLElement | null | false | undefined)[] {
  if (!one) return [];
  const shown = textKinds().filter(([kind]) => whole || FIRST.includes(kind)).flatMap(([kind, name, what]) => texts(c, one, kind, name, what));
  if (!whole) return shown;
  return [
    ...shown,
    ...texts(c, one, "depth_prompts", wording("card-texts-note"), wording("card-texts-the-note")),
    ...groupGreetings(c, one),
    textBlock(c.page, {
      label: wording("card-texts-creator-notes"),
      what: wording("card-texts-notes-for-those-who"),
      read: () => person(c)?.creator_notes ?? "",
      source: sourceOf(c, (first) => first.creator_notes),
      at: place("creator_notes"),
      write: (edited, text) => (edited.characters[SHOWN].creator_notes = text),
    }),
    talkativeness(c, one),
  ];
}
