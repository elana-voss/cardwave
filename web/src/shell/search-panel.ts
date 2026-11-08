// Search Cardwave (board "Tabs · search"; docs/design.md "Tabs and search"): the magnifier (`searchButton`, in the
// title bar and in the narrow window's top bar) and Ctrl+K open one panel under the magnifier that shows, its field
// focused, searching as typed: the words' hits at once, then those by meaning too (`findAll`), and the app's pages
// and settings (find.ts), with the voices and languages of Settings › Voices as the server lists them when the
// panel opens (`voiceLabels`). Nothing typed, a grey line says what it searches; nothing found, that messages' words
// are not. Three hits a group, then "Show all [n]". A hit is a link, so a click opens it in the tab
// in view, and Ctrl+click and a middle-click in a new tab, as tabs.ts catches them; "Open in a new tab" and
// Ctrl+Enter are a Ctrl+click on it. The arrows move through the hits, Enter opens; Escape and a click outside
// close, and it opens again with its words. A hit that names a row or a setting has it scrolled to and marked a
// moment once its page is there (`reveal`), the page's own search emptied where that hides it.
// Traps: tabs.ts stops a Ctrl+click on the document before it comes down to the panel, so the panel hears a hit
// chosen on the window, first; a search answered after a newer one began is dropped. The magnifier's words are
// language.ts's.
import { cardThumbnailUrl, findAll, getVoice } from "../api/client";
import type { Hit } from "../api/generated/Hit";
import { el } from "../dom";
import { onLanguage, wording } from "../language/language";
import { initialOf } from "../format";
import { account, elsewhere } from "../account";
import { grouped, pageHits, shown, wordsOf, type Shown } from "./find";
import { icon } from "../icons";

/** How many hits a group shows before "Show all". */
const AT_ONCE = 3;
/** How long after the last key the search is asked, how long a hit's row is looked for on its page, how long it is marked, in milliseconds. */
const TYPING_MS = 150;
const LOOK_MS = 3000;
const MARKED_MS = 2000;

/** The words asked, kept while the app runs, and the groups shown whole. */
let words = "";
const whole = new Set<string>();
/** The search asked last, which a newer one ends. */
let asking: AbortController | null = null;
let typing = 0;
/** The names of the voices and languages Settings › Voices shows, asked when the panel opens; none where the server did not answer. */
let voiceLabels: Promise<string[]> = Promise.resolve([]);
const askVoices = () =>
  getVoice().then(
    ({ voices, languages }) => [...voices.map(({ name }) => name), ...languages.map(({ name }) => name)],
    (): string[] => [],
  );

/** What was found last, drawn anew by "Show all". */
let found: { hits: Shown[]; asked: string } = { hits: [], asked: "" };

const field = el("input", { type: "search", ariaLabel: wording("search"), placeholder: wording("search") });
const list = el("div", { className: "res", role: "listbox", ariaLabel: wording("setup-found") });
const panel = el("div", { className: "sp", role: "dialog", ariaLabel: wording("search"), hidden: true }, el("label", { className: "field search is-focus w100 bb" }, icon("search", 16), field), list);
// The labels drawn once, here, follow a change of language.
onLanguage(() => {
  field.ariaLabel = field.placeholder = wording("search");
  list.ariaLabel = wording("setup-found");
  panel.ariaLabel = wording("search");
});
/** Each magnifier's place, and the one the panel is open under. */
const places: HTMLElement[] = [];
let openUnder: HTMLElement | null = null;

/** A magnifier, with `className` for where it stands. */
export function searchButton(className: string): HTMLElement {
  const button = el("button", { type: "button", className: `${className} search-button`, ariaExpanded: "false" }, icon("search", 16));
  const said = () => {
    button.ariaLabel = wording("search");
    button.title = wording("search-keys");
  };
  said();
  onLanguage(said);
  const place = el("div", { className: "search-place rel flex f-none" }, button);
  button.onclick = () => show(openUnder === place ? null : place);
  if (!places.length) listen();
  places.push(place);
  return place;
}

/** Opens the panel under the magnifier of `place`, or closes it. */
function show(place: HTMLElement | null): void {
  for (const one of places) one.querySelector("button")!.ariaExpanded = String(one === place);
  openUnder = place;
  panel.hidden = !place;
  if (!place) return;
  place.append(panel);
  voiceLabels = askVoices();
  field.value = words;
  field.focus();
  field.select();
  void search();
}

/** Asks for what the words find: their own hits first, then with those by meaning, each drawn as it comes. */
async function search(): Promise<void> {
  asking?.abort();
  const asked = words;
  whole.clear();
  if (!wordsOf(asked).length) return void list.replaceChildren(el("p", { className: "meta m0" }, wording("search-panel-what")));
  const now = (asking = new AbortController());
  // Another account's search leaves out what is this computer's account's alone.
  const local = (await account().catch(() => undefined))?.local ?? !elsewhere;
  const pages = pageHits(asked, { "#/settings/voices": await voiceLabels }, local);
  if (now.signal.aborted) return;
  for (const meaning of [false, true]) {
    // A search that fails or is ended shows what the one before found; a newer one draws its own.
    const hits = await findAll(asked, meaning, now.signal).catch((): Hit[] | null => null);
    if (now.signal.aborted) return;
    if (hits || !meaning) draw({ hits: [...(hits ?? []).map(shown), ...pages], asked });
  }
}

/** Draws what was found, by group, the hit chosen before still chosen where it is among them, else the first. */
function draw(now: typeof found): void {
  const chosen = keyOf(list.querySelector<HTMLElement>(".hit.is-hover"));
  found = now;
  const groups = grouped(now.hits);
  if (!groups.length)
    return void list.replaceChildren(
      el("p", { className: "meta m0" }, wording("search-panel-nothing-found-for", { asked: now.asked })),
      el("p", { className: "meta m0" }, wording("search-panel-not-messages")),
    );
  list.replaceChildren(
    ...groups.map(([heading, hits]) => {
      const shownAll = whole.has(heading) || hits.length <= AT_ONCE;
      const more = el("button", { type: "button", className: "more", onclick: () => (whole.add(heading), draw(found)) }, wording("search-panel-show-all", { count: hits.length }));
      return el("div", { role: "group", ariaLabel: heading }, el("div", { className: "grp" }, heading), ...(shownAll ? hits : hits.slice(0, AT_ONCE)).map(hitNode), shownAll ? "" : more);
    }),
  );
  const nodes = [...list.querySelectorAll<HTMLElement>(".hit")];
  choose(nodes.find((node) => keyOf(node) === chosen) ?? nodes[0]);
}

/** What tells a hit from the others: its page and its name, as many hits open one list (the personas, the memories). */
const keyOf = (node: HTMLElement | null) => node && `${node.querySelector("a")!.getAttribute("href")} ${node.querySelector("b")!.textContent}`;

/** The kinds whose hit without art has its name's initial in its round; the others their kind's icon. */
const LETTERED = new Set<Shown["kind"]>(["character", "chat", "persona"]);

/** A hit: its round, its name over its grey line, and "Open in a new tab". */
function hitNode(hit: Shown): HTMLElement {
  const round =
    hit.picture !== null
      ? el("img", { className: "hpic", src: cardThumbnailUrl(hit.picture, "row"), alt: "" })
      : LETTERED.has(hit.kind)
        ? el("span", { className: "initial", ariaHidden: "true" }, initialOf(hit.name))
        : el("span", { className: "hico" }, icon(hit.shape, 14));
  const link = el("a", { className: "ink-link flex ai-c g-10 f-grow minw0", href: hit.address, tabIndex: -1 }, round, el("span", { className: "ht" }, el("b", null, hit.name), el("span", null, hit.line)));
  if (hit.reveal) link.dataset.reveal = hit.reveal;
  const out = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm nt", ariaLabel: wording("search-panel-open-in-a-new"), title: wording("search-panel-open-in-a-new"), tabIndex: -1, onclick: () => inNewTab(link) }, icon("newtab", 16));
  const node = el("div", { className: "hit", role: "option" }, link, out);
  node.onpointerenter = () => choose(node);
  return node;
}

/** Marks `node` as the hit chosen, which Enter opens. */
function choose(node: HTMLElement | undefined): void {
  for (const one of list.querySelectorAll(".hit.is-hover")) {
    one.classList.remove("is-hover");
    one.removeAttribute("aria-selected");
  }
  node?.classList.add("is-hover");
  node?.setAttribute("aria-selected", "true");
}

/** Opens a hit's page in a new tab, as a Ctrl+click on its link does (tabs.ts). */
const inNewTab = (link: HTMLAnchorElement) => link.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true, ctrlKey: true }));

/** The panel's keys, Ctrl+K, a click outside, and a hit chosen, which closes the panel and has its row shown. */
function listen(): void {
  field.oninput = () => {
    words = field.value;
    clearTimeout(typing);
    typing = window.setTimeout(() => void search(), TYPING_MS);
  };
  panel.onkeydown = (event) => {
    const nodes = [...list.querySelectorAll<HTMLElement>(".hit")];
    const now = list.querySelector<HTMLElement>(".hit.is-hover");
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      const at = now ? nodes.indexOf(now) : -1;
      choose(nodes[Math.min(nodes.length - 1, Math.max(0, at + (event.key === "ArrowDown" ? 1 : -1)))]);
      list.querySelector(".is-hover")?.scrollIntoView({ block: "nearest" });
    } else if (event.key === "Enter" && now) {
      const link = now.querySelector("a")!;
      if (event.ctrlKey || event.metaKey) inNewTab(link);
      else link.click();
    } else if (event.key === "Escape") {
      const button = openUnder?.querySelector("button");
      show(null);
      button?.focus();
    } else return;
    event.preventDefault();
  };
  document.addEventListener("pointerdown", (event) => openUnder && !openUnder.contains(event.target as Node) && show(null));
  document.addEventListener("keydown", (event) => {
    if (!(event.ctrlKey || event.metaKey) || event.altKey || event.shiftKey || event.key.toLowerCase() !== "k") return;
    event.preventDefault();
    // The magnifier that shows: the title bar's, or in a narrow window the top bar's.
    const place = places.find((one) => one.offsetParent !== null);
    if (place) show(place);
  });
  const chosen = (event: MouseEvent) => {
    const link = event.target instanceof Element ? event.target.closest<HTMLAnchorElement>(".hit > a") : null;
    if (!link || !panel.contains(link) || (event.type === "auxclick" && event.button !== 1)) return;
    show(null);
    reveal(link.getAttribute("href")!, link.dataset.reveal);
  };
  window.addEventListener("click", chosen, true);
  window.addEventListener("auxclick", chosen, true);
}

/**
 * Once the page at `address` shows, scrolls to its row or setting called `text` and marks it a moment; where the
 * page's own search hides it, that search is emptied. Looked for `LOOK_MS` at most, as a page draws as its answers come.
 */
function reveal(address: string, text: string | undefined): void {
  if (!text) return;
  const end = Date.now() + LOOK_MS;
  let emptied = false;
  const look = () => {
    const view = document.querySelector<HTMLElement>("#view");
    if (location.hash === address && view) {
      const target = [...view.querySelectorAll<HTMLElement>(".row-title, .item-label")].find((node) => node.textContent?.trim() === text);
      const row = target?.closest<HTMLElement>(".row, .item") ?? target;
      if (row) {
        row.scrollIntoView({ block: "center" });
        row.classList.add("found");
        return void setTimeout(() => row.classList.remove("found"), MARKED_MS);
      }
      const own = view.querySelector<HTMLInputElement>("input[type=search]");
      if (own?.value && !emptied) {
        emptied = true;
        own.value = "";
        own.dispatchEvent(new Event("input"));
      }
    }
    if (Date.now() < end) setTimeout(look, 100);
  };
  setTimeout(look);
}
