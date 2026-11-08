// A card's page, where it is written, and a new card, the same page empty: `#/library/{id}` (`characterView`)
// and `#/library/new` (`newCardView`). A card holds one character, the first of the server's list.
// Everything shown is edited where it stands (`inPlace`): a text (card-texts.ts, which the chat's split view
// shares), the title, summary, tags and the lines under About; leaving saves. The state and the saves are
// card-page.ts's, the modes card-modes.ts's (mode bar, mode tags, "Add a way to chat…", "Modes…"), the languages
// card-languages.ts's (language bar, "Translate the character…" and the translation shown until Keep all or Undo all), the
// picture card-picture.ts's (a file, "Make a picture", "Earlier pictures"), the box of chats and lorebooks
// card-box.ts's, the new card's other ways (generator, interview) card-ways.ts's, the AI tools for the whole card (the sparkle beside the card menu, and the line under the
// buttons) card-tools.ts's; this file makes the page and draws it (`render`, `drawState`). A new card is made at
// the first letter of its title. At 600 px the side column is one grey line (`.fold-line`). Its two views, chosen in
// the view menu and remembered (`VIEW`): Showcase, and Details (board CardDetails), the texts as lines.
import { cardThumbnailUrl, changeCard, deleteCard, setSummary } from "../api/client";
import { cardItems, starButton } from "../library/library-actions";
import type { CardEdit } from "../api/generated/CardEdit";
import type { EditCharacter } from "../api/generated/EditCharacter";
import { inPlace } from "../in-place";
import { addLines, drawBox } from "../card/card-box";
import { heroPicture, watchDrags } from "../card/card-picture";
import { languageBar, translateDialog, translationView } from "../card/card-languages";
import { addMode, askMode, modeBar, modesDialog } from "../card/card-modes";
import { otherWays } from "../card/card-ways";
import { after, load, modes, newCard, person, save, SHOWN, written, type Card } from "../card/card-page";
import { begin, firstMessage, reading } from "../card/card-texts";
import { wholeCard, type CardTools } from "../card/card-tools";
import { announce, el, noticeBox, titled, type View } from "../dom";
import { menu, type MenuItem } from "../dialogs";
import { comma, count as grouped, day } from "../format";
import { icon } from "../icons";
import { remember, remembered } from "../storage";
import { wording } from "../language/language";
import { cardTitle } from "../card-title";

/** The page's views, for the view menu, and where the one in use is kept. */
const views = (): [string, string][] => ([
  ["showcase", wording("character-showcase")],
  ["details", wording("character-details")],
]);
const VIEW = "card-view";

/** The page of the card `cardId`. */
export const characterView = (cardId: number): View => cardPage(cardId);

/** A new card: the card's page, empty, its title to be written first. */
export const newCardView = (): View => cardPage(null);

function cardPage(given: number | null): View {
  const crumb = el("span", { className: "cut" });
  // "Saved" after each save, as nothing else says the card is kept.
  const saved = el("span", { className: "meta saved" });
  const notice = noticeBox();
  const body = el("div", { className: "page-wide" });
  const node = el(
    "section",
    { className: "main main-card" },
    el("header", { className: "pbar" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/library" }, wording("page-characters")), "/", crumb), saved),
    notice,
    given === null && otherWays(),
    body,
  );
  const c = newCard(given, { node, body, crumb, notice });
  c.savedLine = saved;
  c.details = remembered(VIEW) === "details";
  const tools = wholeCard(c);
  /** Details' facts line, tags and content level, drawn anew after each save as the side column is. */
  const about = el("div", { className: "cdv-about" });
  c.page.whole = tools.page;
  c.render = (focus = null) => render(c, tools, sizes, about, focus);
  c.drawState = () => drawState(c, tools, about);
  const attempt = c.attempt;
  const sizes = new ResizeObserver(() => fit(c));
  watchDrags(c);
  void attempt(() => load(c));
  return {
    node: node,
    views: {
      list: views(),
      now: () => (c.details ? "details" : "showcase"),
      choose: (chosen) => {
        c.details = chosen === "details";
        remember(VIEW, chosen);
        void after(c, () => c.render());
      },
    },
    // A translation or a tool on its way asks the model no more once the page is left.
    left: () => {
      c.translating?.stop.abort();
      tools.stop();
      c.leaving.abort();
    },
    // The card described by the worker model meanwhile, or changed in another window, or a chat of it (its box): it
    // is read anew, and a text being written stays as it is (`load`).
    onEvent: (event) => {
      if (event.type === "descriptions" && c.id !== null && (event.card_id === null || event.card_id === c.id)) void after(c, () => load(c));
      if (event.type === "card" && event.id === c.id) void after(c, () => load(c));
      if ((event.type === "chat" || event.type === "trash") && c.id !== null) void after(c, () => load(c));
    },
    onConnected: () => void (c.id !== null && after(c, () => load(c))),
  };
}

/** The column of tags stays in view while the page is read; one higher than the window goes along with the page. */
function fit(c: Card): void {
  const side = c.body.querySelector<HTMLElement>(".side");
  side?.classList.toggle("long", side.offsetHeight + 2 * parseFloat(getComputedStyle(side).top) > c.node.clientHeight);
}

/** Whether the card is new and has nothing but its title: it can be discarded; one opened from the library goes to the Trash. */
const onlyTitle = (c: Card) => c.given === null && c.edit.characters.every((one) => !written(one));

/** Discards the new card: it goes for good, as nothing but its title was written. */
const discard = (c: Card) =>
  c.attempt(async () => {
    await c.queue;
    const made = c.id;
    if (made !== null) {
      await changeCard(made, { trashed: true });
      await deleteCard(made);
    }
    location.hash = "#/library";
  });

/** The buttons, the side column, its folded line and the short rule, as the card is now. */
function drawState(c: Card, tools: CardTools, about: HTMLElement): void {
  const one = person(c);
  const texts = c.edit.characters.some(written);
  c.crumb.textContent = c.edit.title || wording("page-new-card");
  titled(c.node, c.crumb.textContent, c.detail ? cardThumbnailUrl(c.detail.card.version_id, "row") : null);
  c.rule.hidden = !texts;
  c.node.querySelector<HTMLElement>(".card-ways")?.toggleAttribute("hidden", c.id !== null);
  const tokens = c.detail?.characters[SHOWN]?.facts.permanent_tokens;
  const tags = c.detail?.tags ?? c.edit.tags;
  c.fold.textContent = [one?.name && wording("character-as", { name: one.name }), c.edit.creator && wording("character-by-2", { creator: c.edit.creator }), tags.join(comma()), tokens !== undefined && texts && tokensSaid(tokens)].filter(Boolean).join(" · ");
  drawActions(c, one, tools);
  // What is being written in the column is not drawn over.
  if (c.details) {
    if (!about.querySelector(".in-place")) drawAbout(c, one, texts, tokens, tags, about);
  } else if (!c.side.querySelector(".in-place")) drawSide(c, one, texts, tokens, tags);
  fit(c);
}

/** How many tokens the card's texts take, in the words of the language in use. */
const tokensSaid = (count: number) => wording("character-tokens", { count, shown: grouped(count) });

/** The side column: Tags, About and Facts, each line written where it stands. */
function drawSide(c: Card, one: EditCharacter | undefined, texts: boolean, tokens: number | undefined, tags: string[]): void {
  const facts = texts && tokens !== undefined ? tokensSaid(tokens) : null;
  const tagsLine = tagsField(c, el("p"), tags, () => tags.flatMap((tag, at) => (at ? [el("br"), tag] : [tag])));
  const { name, creator } = aboutFields(c, one);
  const edited = c.detail?.edited_at;
  c.side.replaceChildren(
    el("div", null, el("h3", null, wording("sort-filter-tags")), tagsLine),
    el("div", null, el("h3", null, wording("character-about")), el("p", null, ...(one ? [wording("character-as-2"), name, el("br")] : []), wording("character-by"), creator, edited != null && el("br"), edited != null && wording("character-edited", { day: day(edited) }))),
    ...(facts ? [el("div", { className: "facts" }, el("h3", null, wording("character-facts")), el("p", null, facts))] : []),
  );
}

/** The card's content level and content terms as chips, a level in words (the server's "sfw" and the like); none when it has none. */
export function contentPills(content: string[]): HTMLElement | false {
  const levels = new Map([
    ["sfw", wording("character-rating-sfw")],
    ["suggestive", wording("character-rating-suggestive")],
    ["nsfw", wording("character-rating-nsfw")],
    ["nsfw-extreme", wording("character-rating-nsfw-extreme")],
  ]);
  return content.length > 0 && el("div", { className: "pills", ariaLabel: wording("lorebook-entry-content") }, ...content.map((term) => el("span", { className: "pill pill-tag" }, levels.get(term) ?? term)));
}

/** Details' grey line "Plays [name] · by [creator] · edited [day] · [n] tokens", and the tags and content level as chips, each written where it stands. */
function drawAbout(c: Card, one: EditCharacter | undefined, texts: boolean, tokens: number | undefined, tags: string[], about: HTMLElement): void {
  const { name, creator } = aboutFields(c, one);
  const edited = c.detail?.edited_at;
  const parts: (string | HTMLElement)[][] = [...(one ? [[wording("character-as-2"), name]] : []), [wording("character-by"), creator], ...(edited != null ? [[wording("character-edited", { day: day(edited) })]] : []), ...(texts && tokens !== undefined ? [[tokensSaid(tokens)]] : [])];
  const chips = tagsField(c, el("div", { className: "pills cdv-tags" }), tags, () => tags.map((tag) => el("span", { className: "pill pill-tag" }, tag)));
  const content = c.detail?.content ?? [];
  about.replaceChildren(
    el("p", { className: "meta m0 cdv-facts" }, ...parts.flatMap((part, at) => (at ? [" · ", ...part] : part))),
    el("div", { className: "cdv-chips" }, chips, contentPills(content)),
  );
}

/** The card's tags written in `node`, shown as `shown` draws them, or "add tags" without one. */
function tagsField<T extends HTMLElement>(c: Card, node: T, tags: string[], shown: () => (HTMLElement | string)[]): T {
  inPlace(node, {
    label: wording("character-tags-separated-by-commas"),
    value: () => c.edit.tags.join(", "),
    show: () => (tags.length ? shown() : [el("span", { className: "textbtn" }, icon("plus", 16), wording("character-add-tags"))]),
    // Typed, the tags are told apart by commas alone; nothing between two commas is no tag.
    commit: (text) => void save(c, (card) => (card.tags = text.split(",").map((tag) => tag.trim()).filter((tag) => tag !== ""))),
  });
  return node;
}

/** The character's name in chats and the card's creator, each written where it stands. */
function aboutFields(c: Card, one: EditCharacter | undefined): { name: HTMLElement; creator: HTMLElement } {
  const name = el("span");
  inPlace(name, {
    label: wording("character-name-in-the-chat"),
    value: () => one?.name ?? "",
    show: () => [one?.name || el("span", { className: "c-faint" }, wording("character-name"))],
    commit: (text) =>
      void save(c, (card) => {
        c.named = true;
        card.characters[SHOWN].name = text.trim();
      }),
  });
  const creator = el("span");
  inPlace(creator, {
    label: wording("character-creator"),
    value: () => c.edit.creator,
    show: () => [c.edit.creator || el("span", { className: "c-faint" }, wording("character-creator-2"))],
    commit: (text) => void save(c, (card) => (card.creator = text.trim())),
  });
  return { name, creator };
}

/** "Continue" or "New chat", the AI tools for the whole card, and the card menu. */
function drawActions(c: Card, one: EditCharacter | undefined, tools: CardTools): void {
  const card = c.detail?.card;
  const [last] = c.chats;
  const character = c.detail?.characters[SHOWN];
  // A new card is chatted with once it has a title and a first message, also one being written (`typed`).
  const ready = !!character && c.id !== null && (c.typed === true || !!one?.greetings.some((greeting) => greeting.text.trim()));
  // Details' buttons are of the body's size.
  const lg = c.details ? "" : " btn-lg";
  const primary = last
    ? el("button", { type: "button", className: `btn btn-primary${lg}`, onclick: () => (location.hash = `#/chats/${last.id}`) }, icon("chat", 16), wording("character-continue-chat"))
    : el("button", { type: "button", className: `${ready ? "btn btn-primary" : "btn btn-secondary"}${lg}`, disabled: !ready, title: ready ? undefined : wording("character-new-chat-needs"), onclick: () => begin(c, 0) }, icon("chat-plus", 16), wording("create-new-chat"));
  let items: MenuItem[] = [];
  if (card) {
    const remove = () =>
      c.attempt(async () => {
        await changeCard(card.id, { trashed: true });
        const back = async () => {
          await changeCard(card.id, { trashed: false });
          location.hash = `#/library/${card.id}`;
        };
        // The notice goes along to the library, where the card no longer is.
        announce(wording("library-actions-done-trashed", { title: cardTitle(card.title) }), back, true);
        location.hash = "#/library";
      });
    items = cardItems(card, c.attempt, () => load(c), remove, character);
    // A mode's line: a card without modes asks the first one's name, one with modes opens them.
    const many = modes(c).length > 0;
    items.unshift({ label: many ? wording("character-modes") : wording("character-add-mode"), shape: many ? "edit" : "modes", sub: many ? undefined : wording("character-add-mode-sub"), action: () => (many ? modesDialog(c) : askMode(c, wording("card-modes-add-mode"), "", (name) => addMode(c, name))) });
    if (character) items.splice(1, 0, { label: wording("character-translate-card"), shape: "globe", action: () => translateDialog(c) });
    // The box's empty parts are left out: their "Add …" is here.
    items.splice(character ? 2 : 1, 0, ...addLines(c));
    if (character && last) items.unshift({ label: wording("create-new-chat"), shape: "chat-plus", action: () => begin(c, 0) });
  }
  const discardItem: MenuItem = { label: wording("character-discard-card"), shape: "trash", danger: true, apart: true, action: () => discard(c) };
  if (onlyTitle(c)) items = [...items.slice(0, card ? -1 : 0), discardItem];
  c.actions.replaceChildren(primary, ...(one && card ? [tools.button()] : []), menu(wording("character-card-menu"), items));
}

/** Gives the card its title, and a new card's character too while its name is not written. */
const retitle = (c: Card, card: CardEdit, title: string) => {
  card.title = title;
  if (!c.named && card.characters[0]) card.characters[0].name = title;
};

/** The title, written where it stands; a new card is made at its first letter. */
function title(c: Card, className = "hero-title"): HTMLElement {
  const heading = el("h1", { className });
  inPlace(heading, {
    label: wording("character-title"),
    placeholder: wording("character-name-the-card"),
    value: () => c.edit.title,
    show: () => [c.edit.title || el("span", { className: "c-faint" }, wording("character-name-the-card"))],
    input: (text) => {
      if (c.id === null && !c.waiting && text.trim()) void save(c, (card) => retitle(c, card, text.trim()));
    },
    // A card keeps a title: one taken out is not saved.
    commit: (text) => {
      if (text.trim()) void save(c, (card) => retitle(c, card, text.trim()));
    },
  });
  return heading;
}

/** The summary of a described card, written where it stands. */
function summary(c: Card, className = "hero-sum logline"): HTMLElement | null {
  if (!c.detail?.summary || c.id === null) return null;
  const card = c.id;
  let words = c.detail.summary;
  const line = el("p", { className });
  inPlace(line, {
    label: wording("character-summary"),
    multiline: true,
    value: () => words,
    show: () => [words],
    commit: (text) => {
      if (!text.trim()) return;
      words = text.trim();
      // The page drawn anew has it before the card is read again.
      if (c.detail) c.detail.summary = words;
      void after(c, () => setSummary(card, words));
    },
  });
  return line;
}

/**
 * The lines under the title in both views: archived, being described, the summary (its class `lead`), `between`,
 * "this card has no character", the buttons and the whole card's AI tools' bar; `meta` the class of the plain lines.
 */
function heroLines(c: Card, one: EditCharacter | undefined, tools: CardTools, meta: string, lead?: string, between?: HTMLElement | false | null): (HTMLElement | false | null | undefined)[] {
  const card = c.detail?.card;
  return [
    card?.archived && el("p", { className: meta }, wording("add-character-archived")),
    card?.describing && el("p", { className: meta }, wording("character-describing")),
    summary(c, lead),
    between,
    !one && el("p", { className: meta }, wording("add-character-holds-no-character")),
    c.actions,
    tools.bar,
  ];
}

/** Draws the page anew, the control named `focus` having the focus then. */
function render(c: Card, tools: CardTools, sizes: ResizeObserver, about: HTMLElement, focus: string | null): void {
  const card = c.detail?.card;
  if (card?.trashed) {
    c.crumb.textContent = cardTitle(card.title);
    const restore = () =>
      c.attempt(async () => {
        await changeCard(card.id, { trashed: false });
        await load(c);
      });
    c.body.replaceChildren(el("p", null, wording("character-this-card-is-in"), el("button", { type: "button", className: "btn btn-secondary", onclick: restore }, wording("label-settings-restore"))));
    return;
  }
  const one = person(c);
  // A new card shows its first texts until another has words or "More texts" is pressed.
  const whole = c.given !== null || c.more || written({ ...one!, greetings: [], description: [], personality: [], scenario: [] });
  const moreButton = !whole && el("button", { type: "button", className: "textbtn as-s more-texts" }, icon("plus", 16), wording("character-more-texts"));
  if (moreButton) moreButton.onclick = () => void after(c, () => ((c.more = true), c.render(wording("character-example-dialogue"))));
  if (card) drawBox(c);
  const detail = c.detail;
  const star = (size: number) => card && starButton(card, (favorite) => changeCard(card.id, { favorite }), c.attempt, size);
  if (c.details)
    c.body.replaceChildren(
      el(
        "div",
        { className: "cdv" },
        el("div", { className: "cdv-side" }, heroPicture(c), card && c.box),
        el(
          "div",
          { className: "cdv-main" },
          el(
            "div",
            { className: "cdv-info" },
            el("div", { className: "cdv-title" }, title(c, "t-display m0"), star(18)),
            about,
            ...heroLines(c, one, tools, "meta m0", "t-lead m0 logline"),
          ),
          // A translation being made or kept shows its texts in the texts' place, not as lines (card-languages.ts).
          ...(c.translating ? translationView(c, c.translating) : [languageBar(c), modeBar(c), el("div", { className: "cdv-texts" }, one && firstMessage(c, one), ...reading(c, one, whole)), moreButton]),
        ),
      ),
    );
  else
    c.body.replaceChildren(
      el(
        "div",
        { className: "hero" },
        heroPicture(c),
        el(
          "div",
          { className: "hero-text" },
          el("div", { className: "hero-name" }, title(c), star(20)),
          c.rule,
          ...heroLines(c, one, tools, "meta", undefined, detail && contentPills(detail.content)),
          c.fold,
        ),
      ),
      el(
        "div",
        { className: "cols" },
        c.side,
        el(
          "div",
          { className: "reading minw0 flex f-col g-28" },
          // A translation being made or kept shows its texts in the texts' place (card-languages.ts).
          ...(c.translating ? translationView(c, c.translating) : [languageBar(c), modeBar(c), one && firstMessage(c, one), card && c.box, ...reading(c, one, whole), moreButton]),
        ),
      ),
    );
  drawState(c, tools, about);
  sizes.disconnect();
  for (const watched of [c.node, c.side]) sizes.observe(watched);
  if (focus) [...c.body.querySelectorAll<HTMLElement>("button")].find((button) => (button.ariaLabel ?? button.textContent) === focus)?.focus();
}
