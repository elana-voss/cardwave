// "Add a character": the window in which characters of the library's cards are picked, to join a chat or, as
// "New chat", to start one with one character or with several, or as "Companion" to pick the companion.
//
// `addCharacterDialog` is the window, which the "+" of the chat's message field opens, `newChatDialog` the
// same window as "Create" opens it, called "New chat", and `companionDialog` as the companion's "Change
// character" opens it. Both are `open`: a search over the library's cards,
// `.pick-tools` over `.pick-list`, in a `dialog` with the class `adding`; a `Picking` says the window's words.
// A card holds one character, which a line's button picks (read by `getCard`, as the list does not have its ID);
// a card with someone in the chat is read for it beforehand (`firsts`), as one from before may have had several.
// In "New chat" a line has "+" before "Chat": "Chat" starts a chat with that
// character at once, "+" takes it for a chat of several (`taken`, in the order taken), and from then on every
// line has "Add" and the window's foot (`.pick-foot`) shows who is taken, each a pill that takes it out again,
// and "Start chat"; the first taken is the one the chat is called after and greets. Taking draws the lines anew
// from the cards read last (`draw`), which a search reads again (`load`). Under its search "New chat" says who the
// user is in the chat, "as [persona]" with "Change" (`personaLine`).
// A pick is told with the card's newest version, which has the character picked. A chat that does not start says
// why in the window, which stays open with what was taken; a failure of a card's line begins with the card's title.
import { getCard, listCards, listPersonas } from "../api/client";
import type { Persona } from "../api/generated/Persona";
import type { CardSummary } from "../api/generated/CardSummary";
import { el, latest, oneAtATime, searchField } from "../dom";
import { dialog, menuOn, type MenuItem } from "../dialogs";
import { icon } from "../icons";
import { cover } from "./library-actions";
import { readList, type Asked, type Way } from "./list-screen";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";
import { comma } from "../format";

/** What the list says when the library has no card. */
const noCards = () => (wording("add-character-the-library-has-no"));

/** A character in a chat, or taken for one: its card and its ID in the card. */
interface Member {
  card_id: number;
  character: string;
}

/** A character picked: its card, its ID in the card, the card's newest version, which has it, and its name. */
export interface CharacterPick {
  cardId: number;
  character: string;
  versionId: number;
  name: string;
}

/** What the window is for, in its words: its name, and what stands in a line's buttons' place where the card has nobody left to give. */
interface Picking {
  title: string;
  spent: string;
  /** The ways to a character, which the list offers while the library has none; each closes the window. */
  ways?: Way[];
}

const adding = (): Picking => ({ title: wording("add-character-add-a-character"), spent: wording("add-character-in-this-chat") });
const newChat = (): Picking => ({ title: wording("create-new-chat"), spent: wording("add-character-added") });
const companion = (): Picking => ({ title: wording("companion"), spent: wording("add-character-added") });

/**
 * Opens the window over the screen `home`: a search and under it the
 * library's cards, as the library lists them, each with "Add". Who is in the
 * chat already, its `cast`, is not offered again. The window closes with the pick, which `add` is told:
 * a card, the character's ID in it, and the card's newest version, which has
 * that character.
 */
export function addCharacterDialog(home: HTMLElement, cast: Member[], add: (cardId: number, character: string, versionId: number) => void): void {
  const box = open(home, adding(), cast, (pick) => {
    box.close();
    add(pick.cardId, pick.character, pick.versionId);
  });
}

/** Opens the window "Companion" over the screen `home`: it closes with the pick, which `take` is told. */
export function companionDialog(home: HTMLElement, take: (pick: CharacterPick) => void): void {
  const box = open(home, companion(), [], (pick) => {
    box.close();
    take(pick);
  });
}

/**
 * Opens the window "New chat" over the screen `home`: the character picked by
 * a line's "Chat" starts a chat by `start`, alone, and those taken by "+" and
 * "Add" start one together by "Start chat", in the order taken. The window
 * closes once `start` has started it, and says why where it has not.
 */
export function newChatDialog(home: HTMLElement, start: (picks: CharacterPick[], persona: number | null) => Promise<void>, ways: Way[] = []): void {
  const user = personaLine();
  const box = open(
    home,
    { ...newChat(), ways },
    [],
    undefined,
    async (picks) => {
      await start(picks, user.chosen());
      box.close();
    },
    user.node,
  );
}

/**
 * The line of "New chat" saying who the user is in the chat it starts: grey "as [persona]" and "Change", whose
 * menu has the personas in plain view, and "User", nobody in particular, while none is the default (the server
 * starts a chat without a persona with the default). At first the default, else "User". Hidden without personas.
 * `chosen` is the persona's ID, `null` for the default or nobody.
 */
function personaLine(): { node: HTMLElement; chosen: () => number | null } {
  const node = el("div", { className: "pick-as flex ai-c g-8 meta", hidden: true });
  let personas: Persona[] = [];
  let chosen: Persona | null = null;
  const draw = () => {
    const nobody = !personas.some((one) => one.is_default);
    const items: MenuItem[] = [
      ...(nobody ? [{ label: wording("card-user-stand-in"), chosen: chosen === null, action: () => pick(null) }] : []),
      ...personas.map((one) => ({ label: one.name, chosen: one === chosen, action: () => pick(one) })),
    ];
    const change = el("button", { type: "button", className: "textbtn" }, wording("add-character-change"));
    // A dialog would cut a menu off at its edge: it places itself in the window.
    node.replaceChildren(el("span", null, wording("library-as", { names: chosen?.name ?? wording("card-user-stand-in") })), menuOn(change, items, true));
  };
  const pick = (one: Persona | null) => {
    chosen = one;
    draw();
    node.querySelector("button")?.focus();
  };
  // Without the personas the line stays hidden, and the chat starts as the server starts it.
  listPersonas()
    .then((read) => {
      personas = read.filter((one) => !one.trashed);
      chosen = personas.find((one) => one.is_default) ?? null;
      node.hidden = personas.length === 0;
      draw();
    })
    .catch(() => undefined);
  return { node, chosen: () => chosen?.id ?? null };
}

/** A card's line: its cover, title, the names it goes by where they differ, whether it is archived, its logline, and at the side `side`. */
function cardLine(card: CardSummary, side: HTMLElement | string): HTMLElement {
  const names = card.names.join(comma());
  return el(
    "li",
    { className: "row card-row item g-14 item-dlg" },
    cover(card.version_id, "cover-sm"),
    el(
      "div",
      { className: "row-text item-text" },
      el(
        "div",
        { className: "row-head flex ai-b g-8 wrap" },
        el("span", { className: "row-title ttl" }, cardTitle(card.title)),
        names !== "" && names !== card.title && el("span", { className: "meta" }, wording("library-as", { names })),
        card.archived && el("span", { className: "meta" }, wording("add-character-archived")),
      ),
      // Its logline, one grey line, so that characters of like names are told apart.
      card.excerpt && el("span", { className: "meta ellipsis" }, card.excerpt),
    ),
    typeof side === "string" ? el("span", { className: "meta spent" }, side) : side,
  );
}

/**
 * The window, as `as` words it. A pick is given to `take`, or, where the
 * window starts a chat, to `start` alone by a line's "Chat", or taken for a
 * chat of several by its "+".
 */
function open(home: HTMLElement, as: Picking, cast: Member[], take?: (pick: CharacterPick) => void, start?: (picks: CharacterPick[]) => Promise<void>, line?: HTMLElement): HTMLDialogElement {
  const asked: Asked = { q: "", show: "all" };
  const notice = el("div", { className: "note" });
  const list = el("ul", { className: "pick-list rows-plain" });
  const attempt = oneAtATime(notice);
  /** Taken for a chat of several, in the order taken. */
  const taken: CharacterPick[] = [];
  let cards: CardSummary[] = [];
  let none: string | null = null;
  const members = (): Member[] => [...cast, ...taken.map((pick) => ({ card_id: pick.cardId, character: pick.character }))];
  /** The character of each card read: of a card from before, a chat may have another of its characters. */
  const firsts = new Map<number, string>();
  /** Whether the card's character is in the chat, or taken. */
  const here = (cardId: number) => members().some((one) => one.card_id === cardId && one.character === (firsts.get(cardId) ?? one.character));
  /** Whether characters are being taken for a chat of several, so that every line takes. */
  const gathering = () => taken.length > 0;
  const search = searchField(wording("add-character-search-characters"), wording("add-character-name-or-tag"), asked, () => void load(), "w100 bb");
  const typing = () => search.querySelector("input")?.focus();

  /** The pick of a card's character, which takes it, starts the chat with it alone, or takes it for a chat of several. */
  function picked(pick: CharacterPick, starts: boolean): Promise<void> | void {
    if (take) return take(pick);
    if (starts) return start!([pick]);
    taken.push(pick);
    draw();
    typing();
  }

  function row(card: CardSummary): HTMLElement {
    const choose = (starts: boolean) =>
      attempt(async () => {
        const {
          card: read,
          characters: [one],
        } = await getCard(card.id);
        if (!one) throw new Error(wording("add-character-holds-no-character"));
        firsts.set(card.id, one.id);
        await picked({ cardId: card.id, character: one.id, versionId: read.version_id, name: one.label }, starts);
      }, cardTitle(card.title));
    const actions =
      start && !gathering()
        ? el(
            "span",
            { className: "pick-buttons flex ai-c g-4" },
            el("button", { type: "button", className: "quiet icon btn btn-quiet btn-icon", ariaLabel: wording("add-character-add-to-the-chat-2", { title: cardTitle(card.title) }), title: wording("add-character-add-to-the-chat"), onclick: () => choose(false) }, icon("plus")),
            el("button", { type: "button", className: "btn btn-secondary btn-short", ariaLabel: wording("add-character-chat-with", { title: cardTitle(card.title) }), onclick: () => choose(true) }, wording("page-chat")),
          )
        : el("button", { type: "button", className: "btn btn-secondary", ariaLabel: wording("add-character-add", { title: cardTitle(card.title) }), onclick: () => choose(false) }, wording("account-add-button"));
    // A card whose character is in the chat, or taken, has none left to give.
    return cardLine(card, here(card.id) ? as.spent : actions);
  }

  // The foot of "New chat" while characters are taken: each a pill that takes it out, and "Start chat".
  const pills = el("span", { className: "choices flex ai-c g-8 wrap f-grow meta", role: "group", ariaLabel: wording("add-character-in-the-new-chat") });
  const begin = el("button", { type: "button", className: "primary btn btn-primary", onclick: () => attempt(() => start!([...taken])) }, wording("add-character-start-chat"));
  const foot = el("footer", { className: "pick-foot dfoot ai-c", hidden: true }, pills, begin);

  /** Takes the `at`th character taken out again; the focus goes to the pill in its place, else the one before it, else the search. */
  function untake(at: number): void {
    taken.splice(at, 1);
    draw();
    (pills.querySelectorAll<HTMLElement>("button")[Math.min(at, taken.length - 1)] ?? search.querySelector("input"))?.focus();
  }

  /** Draws the lines of the cards read last, and the foot. */
  function draw(): void {
    // An empty library has the ways to a character beside its words.
    const ways = none === noCards() ? (as.ways ?? []).map((way) => el("button", { type: "button", className: "btn btn-secondary btn-short", onclick: () => (box.close(), way.go()) }, way.label)) : [];
    list.replaceChildren(...cards.map(row), ...(none ? [el("li", { className: "row meta empty flex ai-c g-8 wrap" }, el("span", { className: "f-grow" }, none), ...ways)] : []));
    foot.hidden = !gathering();
    pills.replaceChildren(
      wording("add-character-with"),
      ...taken.map((pick, at) => el("button", { type: "button", className: "pill g-6", ariaLabel: wording("add-character-remove", { name: pick.name }), onclick: () => untake(at) }, pick.name, icon("close", 14))),
    );
  }

  const load = latest(
    notice,
    async () => {
      const read = await readList(listCards, wording("library-characters"), asked, noCards());
      const unread = [...new Set(cast.map((one) => one.card_id))].filter((cardId) => !firsts.has(cardId) && read[0].some((card) => card.id === cardId));
      await Promise.all(unread.map(async (cardId) => firsts.set(cardId, (await getCard(cardId)).characters[0]?.id ?? "")));
      return read;
    },
    ([found, empty]) => {
      [cards, none] = [found, empty];
      draw();
    },
  );
  const box = dialog(home, as.title, el("div", { className: "pick-tools dlg-body" }, search, line ?? "", notice), list, foot);
  box.classList.add("adding");
  typing();
  void load();
  return box;
}
