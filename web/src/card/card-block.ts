// A card's text on its page, written where it stands (`textBlock`): its Markdown rendered, its clock listing its
// drafts (`draftsMenu`), its sparkle the AI tools (`aiTools`) that have the background model change it, kept as a
// draft; a text in another language than the card's first is offered "Translate from …" (`source`), written where
// it stands by `inPlace` (in-place.ts). What a block needs of its page (the card, its saves, its
// drafts, where a failure is told) it is given as a `CardPage`, of a card (`CardEdit`) or of what else holds
// such texts: a lorebook entry's Content (lorebook-entry.ts). A text given its place (`at`) shows the change the
// whole card's AI tools (`CardPage.whole`, card-tools.ts) have waiting for it, with Keep and Undo (`offer`). A
// draft, a tool's change and that one all show against the text by `against`; the two lists open by `popOpen`.
// Trap: what a text shows is held in its block while its save waits (`put`), as the page's card has it only once
// saved.
import { rewrite } from "../api/client";
import type { AiTool } from "../api/generated/AiTool";
import type { CardContext } from "../api/generated/CardContext";
import type { CardEdit } from "../api/generated/CardEdit";
import type { Rewrite } from "../api/generated/Rewrite";
import type { TextDraft } from "../api/generated/TextDraft";
import type { TextDrafts } from "../api/generated/TextDrafts";
import { textTools, madeBy, marked, markdown, named, type Names } from "./card-text";
import { el, escapeFree, failure, reason } from "../dom";
import { dayAt, dayMonth } from "../format";
import { icon } from "../icons";
import { inPlace } from "../in-place";
import { wording } from "../language/language";

/** What a text block is given of its page: of a card's, a change is made to a `CardEdit`. */
export interface CardPage<T = CardEdit> {
  /** The card's ID (or what else holds the text); none while a new card is not made, which has no drafts and no AI tools. */
  card(): number | null;
  /** Saves a change of the card after the saves before it, its drafts made by `made`; answers whether it was saved. */
  save(change: (card: T) => void, made?: string): Promise<boolean>;
  /** The drafts of the text `reference`, asked only where `card` is not none. */
  drafts(reference: string): Promise<TextDrafts>;
  /** Runs `action`, its failure told on the page, one at a time. */
  attempt(action: () => Promise<void>): Promise<boolean>;
  /** Where the page tells a failure. */
  notice: HTMLElement;
  /** Aborted as the page is left, which stops a text's AI tool on its way. */
  gone: AbortSignal;
  /** The texts opened with "Show all". */
  opened: Set<string>;
  /** Whether every text shows its first lines until "Show all" (the card page's Details view); else those asked to (`clamp`). */
  short?(): boolean;
  /** Puts a greeting taken out of the card back, as its last, and shows it. */
  restoreGreeting?(text: string): Promise<void>;
  /** The name a text of the page (its reference, else its label) keeps its unsaved words by; none, none are kept. */
  unsaved?(text: string): string | null;
  /** The whole card's AI tools, on a card's page alone. */
  whole?: WholeCard;
  /** What of the card a text's AI tool is given as context; none for what is not a card. */
  context?(): CardContext;
  /** The names `{{char}}` and `{{user}}` read as; none, they show as written. */
  names?(): Names;
}

/** What a text's AI tool asks of the server, alone as within the whole card's tools (card-tools.ts), so the two agree. */
export const asked = (page: Pick<CardPage, "context">, text: string, tool: AiTool, what: string, given: string): Rewrite => ({ text, tool, what, given: given || undefined, card: page.context?.() });

/** A change of a text by an AI tool: the text as changed, what its foot says of it, what makes its draft. */
export interface Change {
  text: string;
  said: string;
  made: string;
}

/** What the whole card's AI tools (card-tools.ts) have for a text, by its place on the card (`at`). */
export interface WholeCard {
  /** The change waiting for the text at `at`, which reads `now`; "working" while it is still to be changed. */
  offer(at: string, now: string): Change | "working" | null;
  /** The change of the text at `at`, kept or undone, waits no more. */
  settle(at: string): void;
  /** Has `redraw` called when what waits for the text at `at` changes. */
  watch(at: string, redraw: () => void): void;
}

/** A text's words in the card's first language (`from`), to be translated into the one in view (`into`). */
export interface Source {
  from: string;
  text: string;
  into: string;
}

/** What a change by `name` given `given` is called in the text's foot, and what made its draft (`madeBy` of card-text.ts). */
export function aiChange(tool: AiTool, name: string, given: string): { said: string; made: string } {
  if (tool === "translate") return { said: wording("card-block-translated-into", { given }), made: "translated" };
  if (tool === "ask") return { said: wording("card-block-changed-as-asked"), made: "ask" };
  return { said: name, made: tool };
}

/** What a text block shows and how it is saved; see `textBlock`. */
interface BlockSpec<T> {
  label: string;
  what: string;
  /** What it says while empty, where "Empty · click to write [what]" is not all it needs to say. */
  empty?: string;
  /** Told each change while it is being written, before leaving it saves it. */
  input?: (text: string) => void;
  /** What the AI tools tell the model the text is; its label where none is said. */
  about?: string;
  read: () => string;
  write: (card: T, text: string) => void;
  reference?: () => string | null;
  head?: (HTMLElement | null | false)[];
  tools?: HTMLElement[];
  clamp?: boolean;
  greeting?: boolean;
  under?: HTMLElement | null | false;
  begun?: boolean;
  saved?: () => void;
  /** In a language not the card's first: the text there, its language's name and this one's, for "Translate from …". */
  source?: () => Source | null;
  /** Its place on the card, for the whole card's AI tools (`CardPage.whole`). */
  at?: string;
}

/** A text block's parts and what it shows, which its drafts (`draftsMenu`) and AI tools (`aiTools`) work on. */
interface Block {
  section: HTMLElement;
  content: HTMLElement;
  foot: HTMLElement;
  /** Its AI tools' button; none while the card is not made. */
  ai: HTMLButtonElement | null;
  /** Its drafts' button; none without a reference or while the card is not made. */
  clock: HTMLButtonElement | null;
  /** The text as it shows. */
  now(): string;
  /** Saves `text` as the text, "restored" for an earlier draft gone back to, an AI tool's key for its change. */
  put(text: string, made?: string): Promise<boolean>;
  /** What the text shows (`shown`). */
  show(): HTMLElement[];
}

/**
 * A text of the card: its name and tools over it, its Markdown rendered, an
 * empty one asking for `what`. `read` is it as saved, `write` saves it into a
 * card. With a block (`reference`), the clock lists its drafts; a greeting's
 * list has the greetings taken out of the card too.
 */
export function textBlock<T = CardEdit>(page: CardPage<T>, spec: BlockSpec<T>): HTMLElement {
  /** What it shows, held from its leaving until the card is read anew. */
  let held: string | null = null;
  const exists = page.card() !== null;
  const button = (label: string, shape: "clock" | "sparkle") =>
    el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm", ariaLabel: label, title: label, ariaExpanded: "false" }, icon(shape, 16));
  const clamp = spec.clamp || !!page.short?.();
  const b: Block = {
    section: el("section", { className: "tb", ariaLabel: spec.label }),
    content: el("div", { className: "tb-body" }),
    foot: el("div", { className: "tb-foot", hidden: true }),
    clock: spec.reference && exists ? button(wording("card-block-earlier-versions-of", { label: spec.label }), "clock") : null,
    ai: exists ? button(wording("card-block-ai-tools-for", { label: spec.label }), "sparkle") : null,
    now: () => held ?? spec.read(),
    put: async (text, made) => {
      held = text;
      const saved = await page.save((card) => spec.write(card, text), made);
      held = null;
      if (!b.section.classList.contains("is-edit")) b.content.replaceChildren(...b.show());
      return saved;
    },
    show: () => shown(page, b, spec, clamp),
  };
  const { section, content, foot } = b;
  section.append(
    el("div", { className: "tb-head" }, el("h2", { className: "tb-name" }, spec.label), ...(spec.head ?? []), el("div", { className: "tb-tools" }, ...(spec.tools ?? []), b.ai, b.clock)),
    content,
    foot,
  );
  // What the whole card's tools have for it shows as it comes, unless it is being written or its own tools are open.
  if (spec.at && page.whole)
    page.whole.watch(spec.at, () => {
      if (!section.classList.contains("is-edit") && (!section.classList.contains("is-open") || section.classList.contains("offered"))) content.replaceChildren(...b.show());
    });
  const allButton = el("button", { type: "button", className: "textbtn", hidden: true }, wording("card-block-show-all"));
  allButton.onclick = () => {
    page.opened.add(spec.label);
    content.querySelector(".md")?.classList.remove("clamp");
    allButton.hidden = true;
  };
  /** "Show all" is there while a long text is cut off. */
  const clamped = () => {
    const md = content.querySelector<HTMLElement>(".md.clamp");
    allButton.hidden = !md || md.scrollHeight <= md.clientHeight + 1;
  };
  const start = inPlace(content, {
    label: spec.label,
    multiline: true,
    value: b.now,
    show: b.show,
    input: spec.input,
    commit: async (text) => {
      const saved = await b.put(text.trim());
      spec.saved?.();
      return saved;
    },
    blocked: () => section.classList.contains("is-open"),
    keep: () => page.unsaved?.(spec.reference?.() ?? spec.label) ?? null,
    editing: (on) => {
      section.classList.toggle("is-edit", on);
      if (!on) requestAnimationFrame(clamped);
    },
  });
  if (clamp) section.append(el("div", null, allButton));
  if (spec.under) section.append(spec.under);
  requestAnimationFrame(clamped);
  if (b.clock && spec.reference) draftsMenu(page, b, b.clock, spec.reference, spec.greeting ?? false);
  if (b.ai) aiTools(page, b, b.ai, spec.about ?? spec.label, spec.source);
  if (spec.begun) requestAnimationFrame(start);
  return section;
}

/** What the text shows: the whole card's change waiting for it (`offer`), else its Markdown, cut to its first lines where `clamp` says so until "Show all", else what to write. */
function shown<T>(page: CardPage<T>, b: Block, spec: BlockSpec<T>, clamp: boolean): HTMLElement[] {
  const { section, content, foot, ai, clock } = b;
  const text = b.now();
  const offered = spec.at && page.whole && !section.classList.contains("is-edit") ? page.whole.offer(spec.at, text) : null;
  if (offered && offered !== "working") return [offer(page, b, spec.at ?? "", text, offered)];
  if (section.classList.contains("offered")) {
    section.classList.remove("offered", "is-open");
    foot.hidden = true;
    content.tabIndex = 0;
    if (clock) clock.disabled = false;
  }
  // An empty text has nothing for the AI tools to change.
  if (ai && !section.classList.contains("is-open")) ai.disabled = !text.trim();
  if (!text.trim()) return [el("p", { className: "empty" }, spec.empty ?? wording("card-block-empty-click-to-write", { what: spec.what }))];
  // Grey while the whole card's tools have still to change it.
  const md = el("div", { className: offered ? "md working" : "md" }, ...markdown(page.names ? named(text, page.names()) : text));
  if (clamp && !page.opened.has(spec.label)) md.classList.add("clamp");
  return [md];
}

/** The whole card's change of the text at `at`, inside it against `text`, with Keep and Undo; neither tool opens meanwhile. */
function offer<T>(page: CardPage<T>, b: Block, at: string, text: string, change: Change): HTMLElement {
  b.section.classList.add("offered", "is-open");
  if (b.ai) b.ai.disabled = true;
  if (b.clock) b.clock.disabled = true;
  const keep = () => {
    page.whole?.settle(at);
    // `put` holds the new text at once, so the text shows it while it is saved.
    void b.put(change.text, change.made);
    b.content.replaceChildren(...b.show());
  };
  const undo = () => {
    page.whole?.settle(at);
    b.content.replaceChildren(...b.show());
  };
  return against(b, text, change.text, changeSaid(change.said), [wording("card-block-keep"), keep], [wording("card-block-undo"), undo]);
}

/**
 * `then` inside the text against `now` (`marked`), the text taking no focus meanwhile; under it, its foot says
 * `said` of it, given how many changes it has, over a primary and a secondary button, each its label and action.
 */
function against(b: Block, now: string, then: string, said: (count: number) => string, primary: [string, () => void], secondary: [string, () => void]): HTMLElement {
  const { count, words } = marked(now, then);
  b.content.tabIndex = -1;
  b.foot.replaceChildren(
    el("span", { className: "meta" }, said(count)),
    el("button", { type: "button", className: "btn btn-primary", onclick: primary[1] }, primary[0]),
    el("button", { type: "button", className: "btn btn-secondary", onclick: secondary[1] }, secondary[0]),
  );
  b.foot.hidden = false;
  return el("div", { className: "md changes" }, el("p", null, ...words));
}

/** What a text's foot says of a change by `said`, with how many changes it has. */
const changeSaid = (said: string) => (count: number) => wording("card-block-change-said", { said, counted: wording("card-block-changes", { count }) });

/**
 * Opens `list` under the text of `b`, its `button` expanded: a press outside the text closes it, as Escape does
 * with the focus back on the button (`close(true)`). Answers what ends the listening, which `close` aborts.
 */
function popOpen(b: Block, button: HTMLButtonElement, list: HTMLElement, close: (back: boolean) => void): AbortController {
  b.section.append(list);
  button.ariaExpanded = "true";
  const listening = new AbortController();
  document.addEventListener("pointerdown", (event) => !b.section.contains(event.target as Node) && close(false), { signal: listening.signal });
  b.section.addEventListener(
    "keydown",
    (event) => {
      if (!escapeFree(event)) return;
      event.preventDefault();
      close(true);
    },
    { signal: listening.signal },
  );
  return listening;
}

/**
 * The clock of a text: its drafts, the newest first, in a list under it (a greeting's with those taken out of
 * the card). One pressed shows in the text against it as it is, with "Restore this version" and Cancel under it;
 * the list stays open to go through them. Escape, Cancel and a press outside show the text as it is.
 */
function draftsMenu<T>(page: CardPage<T>, b: Block, clock: HTMLButtonElement, reference: () => string | null, greeting: boolean): void {
  const { section, content, foot } = b;
  const list = el("div", { className: "pop drafts", role: "menu", ariaLabel: clock.ariaLabel ?? "" });
  let listening: AbortController | null = null;
  const close = (back: boolean) => {
    list.remove();
    foot.hidden = true;
    clock.ariaExpanded = "false";
    section.classList.remove("is-open");
    listening?.abort();
    listening = null;
    content.replaceChildren(...b.show());
    content.tabIndex = 0;
    if (back) clock.focus();
  };
  const line = (top: Node | string, under: string, action: () => void) =>
    el("button", { type: "button", role: "menuitem", className: "two", onclick: action }, el("span", { className: "l1" }, top), el("span", { className: "sub" }, under));
  /** Shows `then` against the text, from the list's line `chosen`, with what brings it back. */
  const view = (chosen: HTMLElement, then: string, said: string, back: () => Promise<unknown>) => {
    for (const other of list.querySelectorAll("[aria-checked]")) other.removeAttribute("aria-checked");
    chosen.ariaChecked = "true";
    const restore = () => {
      close(true);
      void back();
    };
    content.replaceChildren(against(b, b.now(), then, () => said, [wording("card-block-restore-this-version"), restore], [wording("common-cancel"), () => close(true)]));
  };
  const fill = (drafts: TextDraft[], deleted: TextDraft[], file?: string) => {
    // The imported draft says its day and the file it came in, where the card kept the file's name.
    const under = (draft: TextDraft) => (draft.made === "imported" && file ? `${dayMonth(draft.saved)} · ${file}` : dayAt(draft.saved));
    const lines = drafts.map((draft, at) => {
      if (at === 0) return line(el("span", null, wording("card-block-now")), wording("card-block-text", { madeBy: madeBy(draft.made), under: under(draft) }), () => close(false));
      const chosen: HTMLElement = line(madeBy(draft.made), under(draft), () =>
        view(chosen, draft.text, wording("card-block-version-of", { when: dayAt(draft.saved) }), () => b.put(draft.text, "restored")),
      );
      return chosen;
    });
    const first = lines[0]?.querySelector(".l1");
    first?.append(icon("check", 16));
    const gone = deleted.map((draft) => {
      const chosen: HTMLElement = line(wording("card-block-deleted-greeting"), dayAt(draft.saved), () =>
        view(chosen, draft.text, wording("card-block-deleted-greeting-of", { when: dayAt(draft.saved) }), async () => page.restoreGreeting?.(draft.text)),
      );
      return chosen;
    });
    list.replaceChildren(
      ...(lines.length ? lines : [el("p", { className: "sub none" }, wording("card-block-no-earlier-versions-yet"))]),
      ...(greeting && gone.length ? [el("hr"), ...gone] : []),
    );
  };
  clock.onclick = () => {
    if (listening) return close(true);
    const of = reference();
    const card = page.card();
    list.replaceChildren(el("p", { className: "sub none" }, of ? "…" : wording("card-block-no-earlier-versions-yet")));
    listening = popOpen(b, clock, list, close);
    section.classList.add("is-open");
    if (of && card !== null)
      void page.attempt(async () => {
        const { drafts, deleted, file } = await page.drafts(of);
        fill(drafts, deleted, file);
      });
  };
}

type ToolEntry = (ReturnType<typeof textTools>)[number];

/** The menu's lines: one per tool, with a rule before "Ask for a change…"; a tool that asks first goes to `ask`. */
function toolLines(run: (one: ToolEntry, given: string, from?: string) => unknown, ask: (one: ToolEntry, question: string) => void, source?: () => Source | null): HTMLElement[] {
  return textTools().flatMap((one) => {
    const line = el("button", { type: "button", role: "menuitem", onclick: () => (one.asks ? ask(one, one.asks) : void run(one, "")) }, one.name, icon(one.shape, 16));
    // A text of another language has its first language's words to translate from (card-languages.ts).
    const there = one.tool === "translate" ? source?.() : null;
    const again = there && el("button", { type: "button", role: "menuitem", onclick: () => void run(one, there.into, there.text) }, wording("card-block-translate-from", { from: there.from }), icon(one.shape, 16));
    return one.tool === "ask" ? [el("hr"), line] : again ? [again, line] : [line];
  });
}

/**
 * The AI tools of a text (`textTools()`): a menu beside the column, level under the button, covering none of the
 * text; Translate… and "Ask for a change…" ask in it first, in a line sent with Enter. While the background model
 * works the text is grey and Stop leaves it as it was; its change shows inside the text against it (`against`),
 * with Keep, which saves it as a draft named after the tool, and Undo. Neither button can be pressed meanwhile.
 */
function aiTools<T>(page: CardPage<T>, b: Block, button: HTMLButtonElement, label: string, source?: () => Source | null): void {
  const { section, content, foot, clock } = b;
  const list = el("div", { className: "pop ai", role: "menu", ariaLabel: button.ariaLabel ?? "" });
  let listening: AbortController | null = null;
  /** Whether the tools are taken: their menu open (where the button closes it), the model writing or its change shown. */
  const busy = (on: boolean) => {
    section.classList.toggle("is-open", on);
    button.disabled = (on && !listening) || !b.now().trim();
    if (clock) clock.disabled = on;
  };
  const shut = () => {
    list.remove();
    button.ariaExpanded = "false";
    listening?.abort();
    listening = null;
  };
  const close = (back: boolean) => {
    shut();
    busy(false);
    if (back) button.focus();
  };
  /** Shows the text as it is again. */
  const end = () => {
    busy(false);
    foot.hidden = true;
    content.replaceChildren(...b.show());
    content.tabIndex = 0;
  };
  /** Runs the tool `one`, given `given`, on the text or, for "Translate from …", on `from`'s words. */
  const run = async (one: ToolEntry, given: string, from?: string) => {
    shut();
    busy(true);
    const text = b.now();
    const stopping = new AbortController();
    content.querySelector(".md, .empty")?.classList.add("working");
    content.tabIndex = -1;
    foot.replaceChildren(el("span", { className: "meta" }, one.working), el("button", { type: "button", className: "btn btn-secondary", onclick: () => stopping.abort() }, wording("gen-stop")));
    foot.hidden = false;
    let changed: string;
    try {
      changed = (await rewrite(asked(page, from ?? text, one.tool, label, given), AbortSignal.any([stopping.signal, page.gone]))).text;
    } catch (error) {
      end();
      if (!stopping.signal.aborted && !page.gone.aborted) page.notice.replaceChildren(failure(reason(error)));
      return;
    }
    const { said, made } = aiChange(one.tool, one.name, given);
    const keep = () => {
      // `put` holds the new text at once, so the text shows it while it is saved.
      void b.put(changed, made);
      end();
    };
    content.replaceChildren(against(b, text, changed, changeSaid(said), [wording("card-block-keep"), keep], [wording("card-block-undo"), end]));
  };
  const ask = (one: ToolEntry, question: string) => {
    const line = el("input", { type: "text", className: "field f-grow minw0", ariaLabel: question, placeholder: question, autocomplete: "off" });
    line.onkeydown = (event) => {
      if (event.key !== "Enter" || !line.value.trim()) return;
      event.preventDefault();
      void run(one, line.value.trim());
    };
    list.replaceChildren(line);
    line.focus();
  };
  button.onclick = () => {
    if (listening) return close(true);
    if (section.classList.contains("is-open")) return;
    list.replaceChildren(...toolLines(run, ask, source));
    listening = popOpen(b, button, list, close);
    busy(true);
  };
}
