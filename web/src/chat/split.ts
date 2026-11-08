// The split view (board "Split view"): from 1200 px, the card of one of the chat's characters beside the chat, in
// the side panel's place, its texts written as on the card page (card-texts.ts, of a card's state, card-page.ts).
// Its head: the card's picture, its title, "Changes are used from the next reply", "Open card page" and ×; in a chat
// of several a field chooses whose card. The divider is dragged, each side at least 420 px (`SIDE`, and styles.css's
// `.with-split`), and the width is remembered (`WIDTH`); views/chat.ts opens and closes it.
//
// Traps: a card's state is made anew only when another card is shown, so that a text being written stays; one
// left behind still saves what waits, but no longer draws (`current`) and tells its failures in its own notice, which
// is no longer in view. The mode in view follows the chat's mode in use, as it changes (`modeShown`).
import { cardImageUrl } from "../api/client";
import type { ChatCharacter } from "../api/generated/ChatCharacter";
import { languageBar } from "../card/card-languages";
import { modeBar } from "../card/card-modes";
import { after, load, newCard, person, type Card } from "../card/card-page";
import { firstMessage, reading } from "../card/card-texts";
import { el, noticeBox, selectField, type Select } from "../dom";
import { remember, remembered } from "../storage";
import { icon } from "../icons";
import { firstJoined } from "./panel";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";

/** Each side's least width, in px. */
const SIDE = 420;
/** The editor's width once its divider was dragged, in px, is kept under this name. */
const WIDTH = "chat-split-width";

export interface Split {
  node: HTMLElement;
  /** Its ×, "Hide card editor". */
  close: HTMLButtonElement;
  /** Shows the card of the character chosen among `characters` (the first joined, until another is chosen), in the chat's `mode` in use. */
  show(characters: ChatCharacter[], mode: string | null): void;
}

/** The split view of the chat whose screen is `room`, which it is laid out in. */
export function splitView(room: HTMLElement): Split {
  const picture = el("img", { alt: "" });
  const title = el("div", { className: "semi split-title" });
  const open = el("a", { className: "textbtn medium split-open", href: "#/library" }, wording("split-open-card-page"));
  const close = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("split-hide-card-editor"), title: wording("split-hide-card-editor") }, icon("close", 16));
  const choose = el("div", { className: "split-choose", hidden: true });
  const noticePlace = el("div");
  const body = el("div", { className: "reading minw0 flex f-col split-texts" });
  const divider = el("div", { className: "split-divider", ariaHidden: "true" });
  const node = el(
    "section",
    { className: "split-pane minw0 flex f-col", ariaLabel: wording("split-card-editor"), hidden: true },
    divider,
    el("div", { className: "split-head flex ai-c g-12" }, picture, el("div", { className: "f-grow minw0" }, title, el("div", { className: "meta" }, wording("split-changes-are-used-from"))), open, close),
    choose,
    noticePlace,
    el("div", { className: "split-scroll" }, body),
  );
  drag(room, divider);

  let current: Card | null = null;
  let chosen: number | null = null;
  let select: Select | null = null;
  let modeShown: string | null = null;
  let last: { characters: ChatCharacter[]; mode: string | null } = { characters: [], mode: null };

  /** The card's state for the card `id`, drawn here while it is the one shown. */
  const make = (id: number, mode: string | null): Card => {
    const notice = noticeBox();
    noticePlace.replaceChildren(notice);
    const c = newCard(id, { node, body, crumb: title, notice });
    c.mode = mode;
    c.render = (focus = null) => {
      if (c === current) render(c, focus);
    };
    c.drawState = () => {
      if (c === current) head(c);
    };
    return c;
  };
  const head = (c: Card) => {
    const card = c.detail?.card;
    title.textContent = card ? cardTitle(card.title) : "";
    picture.hidden = !card;
    if (card) picture.src = cardImageUrl(card.version_id);
    open.href = `#/library/${c.id}`;
  };
  const render = (c: Card, focus: string | null) => {
    head(c);
    const one = person(c);
    const parts = c.detail?.card.trashed ? [el("p", { className: "meta" }, wording("split-this-card-is-in"))] : [languageBar(c), modeBar(c), one && firstMessage(c, one), ...reading(c, one, true)];
    body.replaceChildren(...parts.filter((part): part is HTMLElement => !!part));
    if (focus) [...body.querySelectorAll<HTMLElement>("button")].find((button) => (button.ariaLabel ?? button.textContent) === focus)?.focus();
  };

  const show = (characters: ChatCharacter[], mode: string | null) => {
    last = { characters, mode };
    const one = characters.find((character) => character.id === chosen) ?? firstJoined(characters);
    if (!one) return;
    chosen = one.id;
    const choices = characters.map((character) => ({ value: String(character.id), label: character.name }));
    if (characters.length < 2) select = null;
    else if (!select) {
      select = selectField(choices, String(chosen), (value) => ((chosen = Number(value)), show(last.characters, last.mode)), { ariaLabel: wording("voices-character") });
      choose.replaceChildren(select.node);
    } else {
      select.offer(choices);
      select.value = String(chosen);
    }
    choose.hidden = !select;
    if (current?.id === one.card_id) {
      if (mode === modeShown) return;
      // A text being written is not drawn over; the mode shows once it is left.
      const c = current;
      modeShown = c.mode = mode;
      if (!body.querySelector(".in-place")) void after(c, () => c.render());
      return;
    }
    body.replaceChildren();
    modeShown = mode;
    const c = make(one.card_id, mode);
    current = c;
    head(c);
    void c.attempt(() => load(c));
  };
  return { node, close, show };
}

/** The divider dragged sets the editor's width within `room`, each side at least `SIDE`; it is kept when let go. */
function drag(room: HTMLElement, divider: HTMLElement): void {
  const size = (px: number) => room.style.setProperty("--split-width", `clamp(${SIDE}px, ${px}px, calc(100% - ${SIDE}px))`);
  const kept = Number(remembered(WIDTH));
  if (kept > 0) size(kept);
  divider.onpointerdown = (event) => {
    event.preventDefault();
    divider.setPointerCapture(event.pointerId);
    const bounds = room.getBoundingClientRect();
    let px = 0;
    divider.onpointermove = (move) => {
      px = Math.round(Math.min(Math.max(bounds.right - move.clientX, SIDE), bounds.width - SIDE));
      size(px);
    };
    divider.onpointerup = divider.onpointercancel = () => {
      divider.onpointermove = divider.onpointerup = divider.onpointercancel = null;
      if (px) remember(WIDTH, String(px));
    };
  };
}
