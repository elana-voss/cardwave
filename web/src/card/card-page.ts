// A card's page's state (`newCard`), which its parts share (views/character.ts, card-modes.ts, card-box.ts, and the
// chat's split view, chat/split.ts), and what they all do with it: run a step after the saves that wait (`after`),
// save a change (`save`), tell its AI tools what of it they are given as context (`context`), make a new card (`make`), and read the card (`load`, `refresh`), its texts in the language in view (`language`, remembered per card by
// `languageKey`; card-languages.ts). The page sets `render` and `drawState`; the parts draw only from the state.
//
// Traps: saves go one after the other, each writing into `edit` when its turn comes; once none waits the card is
// read anew (`refresh`). What a text shows is read from `edit` by where it stands, as a save gives `edit` anew. A
// redraw of the whole page waits for the saves and is left out while something is being written (`.in-place`).
import { account } from "../account";
import { cardChats, cardExpressions, cardFigures, cardLorebooks, createCard, getCard, getCardEdit, libraryLorebooks, listPersonas, saveCardEdit, textDrafts } from "../api/client";
import type { CardContext } from "../api/generated/CardContext";
import type { CardDetail } from "../api/generated/CardDetail";
import type { CardEdit } from "../api/generated/CardEdit";
import type { CardLorebook } from "../api/generated/CardLorebook";
import type { Chat } from "../api/generated/Chat";
import type { CardFigures } from "../api/generated/CardFigures";
import type { ExpressionPack } from "../api/generated/ExpressionPack";
import type { EditCharacter } from "../api/generated/EditCharacter";
import type { EditText } from "../api/generated/EditText";
import type { Lorebook } from "../api/generated/Lorebook";
import type { Persona } from "../api/generated/Persona";
import type { CardPage } from "./card-block";
import type { Translating } from "./card-languages";
import { el, oneAtATime, reason } from "../dom";
import { remembered } from "../storage";
import { sameMode, usedIn } from "./modes";
import { wording } from "../language/language";

/** The card's one character (a card from before may have more): the one its page shows. */
export const SHOWN = 0;

/** A character's texts after First message and the box, in their order: the key, the name, what its empty text asks for. */
export const textKinds = () => ([
  ["description", wording("persona-form-description"), wording("card-page-the-description")],
  ["personality", wording("gen-personality"), wording("card-page-the-personality")],
  ["scenario", wording("card-page-scenario"), wording("card-page-the-scenario")],
  ["example_dialogue", wording("character-example-dialogue"), wording("card-page-example-dialogue")],
  ["system_prompt", wording("card-page-instructions-for-the-ai"), wording("card-page-the-system-prompt")],
  ["post_history", wording("card-page-instructions-after-the-chat"), wording("card-page-instructions-after-the-chat-2")],
] as const);
export type Kind = (ReturnType<typeof textKinds>)[number][0];

export interface Card {
  /** The card; none for a new card not made yet. */
  id: number | null;
  /** The card the page was opened on: none for a new card. */
  readonly given: number | null;
  /** The card's texts as written, as last saved. */
  edit: CardEdit;
  /** The card as its page shows it; none for a new card not made yet. */
  detail: CardDetail | null;
  chats: Chat[];
  lorebooks: CardLorebook[];
  /** The library's lorebooks in plain view, for the card to have attached. */
  library: Lorebook[];
  /** The name `{{user}}` reads as: the default persona's, else the stand-in name, as in a chat. */
  you: string;
  /** The card's expression pack, if it has one (card-expressions.ts). */
  expressions: ExpressionPack | null;
  /** The card's 3D figure and its modes' (card-figure.ts). */
  figures: CardFigures;
  /** Which of the character's greetings is in view. */
  greetingAt: number;
  /** The mode whose texts are in view, as last chosen; `inMode` is it as the card has it. */
  mode: string | null;
  /** The language whose texts are in view, by its code; none for the card's first (card-languages.ts). */
  language: string | null;
  /** The card's texts in its first language while another is in view, for "Translate from …". */
  original: CardEdit | null;
  /** A translation of the whole card being made or waiting for Keep all or Undo all. */
  translating: Translating | null;
  /** A greeting being added: shown after the others until it has words. */
  adding: boolean;
  /** Whether the first message being written has words, before leaving it saves them; null while it is not being written. */
  typed: boolean | null;
  /** Where "Saved" shows after a save of the card; none in the chat's split view. */
  savedLine?: HTMLElement;
  /** A new card's "More texts" opened. */
  more: boolean;
  /** Whether the page is in its Details view (views/character.ts), where every text shows its first lines. */
  details: boolean;
  /** A new card's character is named by its title until its name is written. */
  named: boolean;
  /** Whether the page was drawn before its card was made. */
  unmade: boolean;
  /** The picture file chosen for a new card not made yet, which it is made with (card-picture.ts). */
  pending: Blob | null;
  /** The saves, one after the other, and how many wait. */
  queue: Promise<void>;
  waiting: number;
  /** Which parts of the box show all their lines. */
  readonly all: { chats: boolean; lorebooks: boolean; expressions: boolean; figures: boolean };
  /** The parts of the box that show while empty, as the card menu's "Add …" asked for them; an empty part is left out otherwise. */
  readonly revealed: Set<"lorebooks" | "expressions" | "figures">;
  /** Draws the modes' dialog anew while it is open. */
  modesShown: (() => void) | null;
  readonly node: HTMLElement;
  readonly body: HTMLElement;
  readonly crumb: HTMLElement;
  readonly notice: HTMLElement;
  /** The card's chats and its lorebooks, as parts of one box. */
  readonly box: HTMLElement;
  /** The parts drawn anew after each save: the side column, the line it folds into, the buttons and the rule. */
  readonly side: HTMLElement;
  readonly fold: HTMLElement;
  readonly actions: HTMLElement;
  readonly rule: HTMLElement;
  attempt(action: () => Promise<void>): Promise<boolean>;
  /** What a text block is given of the page. */
  readonly page: CardPage;
  /** Aborted as the page is left: a text's AI tool on its way asks the model no more (`CardPage.gone`). */
  readonly leaving: AbortController;
  /** Draws the page anew, the control named `focus` having the focus then. */
  render(focus?: string | null): void;
  /** Draws the buttons, the side column, its folded line and the short rule, as the card is now. */
  drawState(): void;
}

/**
 * A card's state, of the card `given` (none for a new card), drawn into `parts.body` under `parts.node`, where
 * `parts.notice` tells what failed; who draws it sets `render` and `drawState`.
 */
export function newCard(given: number | null, parts: Pick<Card, "node" | "body" | "crumb" | "notice">): Card {
  const attempt = oneAtATime(parts.notice);
  const leaving = new AbortController();
  const c: Card = {
    id: given,
    given,
    edit: blank(""),
    detail: null,
    chats: [],
    lorebooks: [],
    library: [],
    you: wording("card-user-stand-in"),
    expressions: null,
    figures: { figure: null, modes: [] },
    greetingAt: 0,
    mode: null,
    language: null,
    original: null,
    translating: null,
    adding: false,
    typed: null,
    more: false,
    details: false,
    named: given !== null,
    unmade: given === null,
    pending: null,
    queue: Promise.resolve(),
    waiting: 0,
    all: { chats: false, lorebooks: false, expressions: false, figures: false },
    revealed: new Set(),
    modesShown: null,
    ...parts,
    box: el("div", { className: "gbox box" }),
    side: el("aside", { className: "side", ariaLabel: wording("card-page-card-info") }),
    fold: el("p", { className: "fold-line" }),
    actions: el("div", { className: "hero-acts" }),
    rule: el("span", { className: "short-rule" }),
    attempt,
    leaving,
    page: {
      card: () => c.id,
      context: () => context(c),
      unsaved: (text) => (c.id === null ? null : `card.${c.id}.${c.language ?? ""}.${text}`),
      save: (change, made) => save(c, change, made),
      // Asked only of a card that is made (`CardPage.drafts`).
      drafts: (reference) => textDrafts(c.id ?? 0, reference),
      attempt,
      notice: parts.notice,
      gone: leaving.signal,
      opened: new Set(),
      short: () => c.details,
      names: () => ({ char: person(c)?.name || c.detail?.card.names[0] || "", user: c.you }),
      restoreGreeting: async (text) => {
        await save(c, (card) => card.characters[SHOWN].greetings.push({ reference: null, text }), "restored");
        await after(c, () => {
          c.greetingAt = Math.max(0, (person(c)?.greetings.length ?? 1) - 1);
          c.render();
        });
      },
    },
    // Set by who draws the card.
    render: () => {},
    drawState: () => {},
  };
  return c;
}

/** What of the card a text's AI tools are given as context: the name, and the texts of the mode in view, in the language in view. */
export function context(c: Card): CardContext {
  const one = person(c);
  const text = (parts: EditText[] | undefined) =>
    (parts ?? [])
      .filter((part) => usedIn(part, inMode(c)) && part.text.trim())
      .map((part) => part.text.trim())
      .join("\n\n");
  return { name: one?.name ?? "", description: text(one?.description), personality: text(one?.personality), scenario: text(one?.scenario) };
}

/** A card with nothing but who made it: a new card's page. */
export function blank(creator: string): CardEdit {
  const none = (): EditText[] => [{ reference: null, text: "" }];
  const one: EditCharacter = {
    id: "",
    label: "",
    name: "",
    name_block: null,
    greetings: [],
    group_greetings: [],
    description: none(),
    personality: none(),
    scenario: none(),
    example_dialogue: none(),
    system_prompt: none(),
    post_history: none(),
    depth_prompts: [],
    creator_notes: "",
    talkativeness: 0.5,
  };
  return { version: 0, title: "", tags: [], creator, characters: [one] };
}

/** Whether a character has any text written. */
export const written = (one: EditCharacter | undefined) =>
  !!one && (one.greetings.some((greeting) => greeting.text.trim()) || textKinds().some(([kind]) => one[kind].some((part) => part.text.trim())) || !!one.creator_notes.trim());

/** The character in view. */
export const person = (c: Card) => c.edit.characters[SHOWN] as EditCharacter | undefined;
/** The card's modes, and the one in view: the one chosen, else the card's first; none without modes. */
export const modes = (c: Card) => c.edit.modes ?? [];
export const inMode = (c: Card) => modes(c).find((one) => sameMode(one, c.mode ?? "")) ?? modes(c)[0] ?? null;

/** Runs `step` after the saves that wait. */
export function after(c: Card, step: () => Promise<void> | void): Promise<void> {
  c.queue = c.queue.then(step).catch(async (error: unknown) => {
    // What the page shows is the card as it is.
    if (c.id !== null) await load(c).catch(() => undefined);
    c.notice.replaceChildren(el("p", { className: "error c-danger m0", role: "alert" }, reason(error)));
  });
  return c.queue;
}

/**
 * Writes `change` into the card when the saves before it are done, and saves
 * it: a new card not made yet keeps it until it is. `made` "restored" for an
 * earlier draft gone back to. Answers whether it was saved; why not is told on the page.
 */
export async function save(c: Card, change: (card: CardEdit) => void, made?: string): Promise<boolean> {
  c.waiting++;
  let saved = false;
  await after(c, async () => {
    try {
      change(c.edit);
      if (c.id !== null) c.edit.version = (await saveCardEdit(c.id, c.edit, made)).number;
      else if (c.edit.title.trim()) await make(c);
      saved = true;
      if (c.id !== null && c.savedLine) c.savedLine.textContent = wording("character-saved");
    } finally {
      c.waiting--;
    }
    c.notice.replaceChildren();
    if (!c.waiting && c.id !== null) await refresh(c);
    // A card just made has its box and star once nothing is being written.
    if (c.unmade && c.detail && !c.body.querySelector(".in-place")) {
      c.unmade = false;
      c.render();
    } else c.drawState();
  });
  return saved;
}

/** Makes the new card of what its page holds, and shows it under its own address. */
async function make(c: Card): Promise<void> {
  const edit = c.edit;
  const [one] = edit.characters;
  const made = await createCard(
    {
      title: edit.title.trim(),
      tags: edit.tags,
      creator: edit.creator,
      name: one.name.trim() || edit.title.trim(),
      greetings: one.greetings.map((greeting) => greeting.text).filter((text) => text.trim()),
      description: one.description[0].text,
      personality: one.personality[0].text,
      scenario: one.scenario[0].text,
      example_dialogue: one.example_dialogue[0].text,
      creator_notes: one.creator_notes,
      system_prompt: one.system_prompt[0]?.text,
      post_history: one.post_history[0]?.text,
      talkativeness: one.talkativeness,
    },
    c.pending,
  );
  c.pending = null;
  c.id = made.card_id;
  // The page stays as it is, under the card's address; a save after this one is of the card as made.
  history.replaceState(null, "", `#/library/${c.id}`);
  c.edit = await getCardEdit(c.id);
}

/** Where the language in view of the card `id` is remembered, per card and in this browser alone. */
export const languageKey = (id: number) => `cardwave.card-language.${id}`;

/** Reads the card as saved, for the parts drawn after a save. */
async function refresh(c: Card): Promise<void> {
  if (c.id === null) return;
  [c.edit, c.detail] = await Promise.all([getCardEdit(c.id, c.language), getCard(c.id)]);
}

/** Reads the card's texts in the language in view, and its first language's beside them where that is another. */
async function texts(c: Card, card: number): Promise<void> {
  c.edit = await getCardEdit(card, c.language);
  // A language no longer there is the card's first.
  c.language = c.edit.language ?? null;
  c.original = c.language ? await getCardEdit(card) : null;
}

/** Reads the card, its chats, lorebooks, expressions and figures and the library's lorebooks; a new card is empty but for who makes it. */
export async function load(c: Card): Promise<void> {
  if (c.id === null) {
    c.edit = blank(await account().then(({ name }) => name, () => ""));
    c.render();
    c.body.querySelector<HTMLElement>(".hero-text h1")?.focus();
    return;
  }
  const card = c.id;
  c.language ??= remembered(languageKey(card));
  let personas: Persona[];
  [c.detail, c.chats, c.lorebooks, c.library, c.expressions, c.figures, personas] = await Promise.all([
    getCard(card),
    cardChats(card),
    cardLorebooks(card),
    libraryLorebooks(),
    cardExpressions(card),
    cardFigures(card),
    listPersonas(),
  ]);
  c.you = personas.find((persona) => persona.is_default)?.name || wording("card-user-stand-in");
  // A card in the Trash has no texts to write.
  if (c.detail.card.trashed) c.edit = blank("");
  else await texts(c, card);
  // Nothing being written is drawn over, but in a card in the Trash nothing is written.
  if (c.detail.card.trashed || !c.body.querySelector(".in-place")) c.render();
  else c.drawState();
}
