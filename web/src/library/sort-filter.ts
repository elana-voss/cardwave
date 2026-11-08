// "Sort and filter" over the library's list: a panel that slides in from the
// right, with the list's order and the tags of its cards as pills. What is
// chosen in it counts once "Apply" is pressed: the list then has that order
// and shows the cards that have every tag chosen. The list of chats has it
// without tags, as "Sort".
//
// `sortFilter` is the button and the panel it opens, a `sheet` of dialogs.ts, and takes any list's orders; with
// `read` it is "Sort and filter", with the tags `read` answers, and without it "Sort", the orders alone. A
// button that says a choice is made behind it has the class `on`: tags chosen, or, where there are none to
// choose, another order than the list's own, which is the first of its orders.
// `tagsPart` is the panel's part "Tags", which only a list with tags has.
import type { TagCount } from "../api/generated/TagCount";
import { el, latest, noticeBox, pill, searchField } from "../dom";
import { sheet } from "../dialogs";
import { icon } from "../icons";
import { wording } from "../language/language";

/** With more tags than this to choose from, they can be searched. */
const FIND_FROM = 8;

/** What a list is asked for that the panel sets: its order, and where its items have tags, those they have to have. */
interface Sorting<S extends string> {
  sort: S;
  tags?: string[];
}

/**
 * The button "Sort and filter" and the panel it opens over `home`: the
 * `sorts` as pills, of which one is chosen, and the tags `read` answers with
 * for the tags chosen in the panel, each a pill to press. A tag that would
 * leave no card cannot be pressed. "Apply" makes the choice `asked`'s and
 * tells `changed`; closed any other way, the panel changes nothing. "Clear
 * all" unpresses every tag. While `asked` has tags, the button says so.
 *
 * While `waits` answers, the list has another order: the Sort's pills cannot be pressed and its words say why.
 *
 * Without `read` the list has no tags: button and panel are called "Sort",
 * "Clear all" goes back to the list's own order, the first of `sorts`, and the
 * button says while another one is chosen.
 */
export function sortFilter<S extends string>(
  home: HTMLElement,
  sorts: [S, string][],
  asked: Sorting<S>,
  changed: () => void,
  read?: (tags: string[]) => Promise<TagCount[]>,
  waits?: () => string | undefined,
): HTMLButtonElement {
  const button = el("button", { type: "button", className: "btn btn-secondary btn-icon", ariaHasPopup: "dialog", ariaExpanded: "false", onclick: open }, icon("sliders"));
  const name = read ? wording("sort-filter-sort-and-filter") : wording("sort-filter-sort");
  /** The list's own order. */
  const [own] = sorts[0];

  /** The button says whether a choice is made behind it: how many tags, or which order that is not the list's own. */
  function mark(): void {
    const count = asked.tags?.length ?? 0;
    const order = !read && asked.sort !== own ? sorts.find(([value]) => value === asked.sort)?.[1] : undefined;
    button.classList.toggle("on", count > 0 || order !== undefined);
    const chosen = count ? wording("sort-filter-tags-chosen", { count }) : order ? wording("sort-filter-by", { order }) : "";
    button.ariaLabel = button.title = chosen ? wording("sort-filter-name-chosen", { name, chosen }) : name;
  }

  function open(): void {
    /** The order chosen in the panel, which "Apply" makes the list's. */
    let sort = asked.sort;

    /** Makes `value` the panel's order, which its pills say. */
    const order = (value: S) => {
      sort = value;
      for (const [at, node] of orders.entries()) node.ariaPressed = String(sorts[at][0] === value);
      if (!tagged) clear.disabled = sort === own;
    };
    const orders = sorts.map(([value, label]) => pill(label, value === sort, () => order(value)));
    const why = waits?.();
    if (why) for (const one of orders) one.disabled = true;

    const apply = el("button", { type: "button", className: "btn btn-primary" }, wording("sort-filter-apply"));
    const clear = el("button", { type: "button", className: "btn btn-secondary", disabled: true }, wording("sort-filter-clear-all"));
    const tagged = read && tagsPart(read, asked.tags ?? [], clear, () => box.querySelector("button")?.focus());
    if (!tagged) clear.disabled = sort === own;
    // With nothing left to clear it cannot be pressed, so the focus goes on to what is done next.
    clear.onclick = () => {
      if (tagged) tagged.clear();
      else order(own);
      apply.focus();
    };
    const box = sheet(
      home,
      name,
      el(
        "div",
        { className: "sort-sheet" },
        el("section", { className: "flex f-col g-10" }, el("span", { className: "fs-small semi" }, wording("sort-filter-sort-by")), el("div", { className: "pills", role: "group", ariaLabel: wording("sort-filter-sort-by") }, ...orders), why && el("span", { className: "meta" }, why)),
        tagged && tagged.node,
      ),
      el("footer", null, clear, apply),
    );
    button.ariaExpanded = "true";
    box.addEventListener("close", () => (button.ariaExpanded = "false"));

    apply.onclick = () => {
      asked.sort = sort;
      if (tagged) asked.tags?.splice(0, asked.tags.length, ...tagged.chosen());
      mark();
      box.close();
      changed();
    };
  }

  mark();
  return button;
}

/**
 * The panel's part "Tags": the tags `read` answers as pills, those of `first`
 * pressed, read anew at every choice. `clear`, the panel's "Clear all", can be
 * pressed while a tag is chosen, and `lost` takes the focus where no tag can.
 * Answers the part, the tags chosen in it, and what unpresses them all.
 */
function tagsPart(read: (tags: string[]) => Promise<TagCount[]>, first: string[], clear: HTMLButtonElement, lost: () => void): { node: HTMLElement; chosen(): string[]; clear(): void } {
  let tags = [...first];
  /** The tags as they are drawn. */
  let lines: { tag: string; node: HTMLButtonElement }[] = [];
  /** Where the focus goes once the tags asked for are drawn; each time they are asked for says it anew. */
  let after = () => {};

  const find = searchField(wording("sort-filter-find-a-tag"), wording("sort-filter-find-a-tag"), { q: "" }, narrow);
  const field = find.querySelector("input")!;
  // Hidden until there are tags enough to look through.
  find.hidden = true;
  const notice = noticeBox();
  const nothing = el("p", { className: "hint", hidden: true });
  const list = el("div", { className: "pills", role: "group", ariaLabel: wording("sort-filter-tags") });

  /** Shows the tags that have the letters typed, in any case. */
  function narrow(): void {
    const typed = field.value.trim();
    for (const { tag, node } of lines) node.hidden = !tag.toLowerCase().includes(typed.toLowerCase());
    nothing.textContent = lines.length ? wording("sort-filter-no-tags-match", { typed }) : wording("sort-filter-no-tags-to-choose");
    nothing.hidden = lines.some(({ node }) => !node.hidden);
  }

  /** Reads the tags anew: a choice changes which of them still have a card. */
  const fill = latest(
    notice,
    () => read(tags),
    (found) => {
      // As the server writes them now, which is how their pills are called: a tag is given up by its pill's name.
      tags = found.filter((tag) => tag.chosen).map(({ tag }) => tag);
      clear.disabled = tags.length === 0;
      lines = found.map(({ tag, cards, chosen }) => {
        const node = pill(tag, chosen, () => choose(chosen ? tags.filter((other) => other !== tag) : [...tags, tag], () => focus(tag)));
        // One that would leave no card cannot be pressed; one that is chosen can always be given up.
        node.disabled = cards === 0 && !chosen;
        return { tag, node };
      });
      find.hidden = lines.length <= FIND_FROM;
      list.replaceChildren(...lines.map(({ node }) => node));
      narrow();
      // A panel closed in the meantime is out of the page, and what is in it takes no focus.
      after();
    },
  );

  /**
   * Puts the focus on the pill of the tag `held`. Where that cannot be
   * pressed any more, or is gone, it goes into the field, else to the first
   * tag that can be pressed, else where `lost` puts it: never to nothing.
   */
  function focus(held: string): void {
    const own = lines.find(({ tag, node }) => tag === held && !node.disabled)?.node;
    const first = lines.find(({ node }) => !node.hidden && !node.disabled)?.node;
    const next = own ?? (find.hidden ? first : field);
    if (next) next.focus();
    else lost();
  }

  /** Makes `chosen` the panel's choice of tags, and says where the focus goes when the tags are drawn anew. */
  function choose(chosen: string[], then: () => void): void {
    tags = chosen;
    clear.disabled = tags.length === 0;
    // At once, before the server has said which tags are left: the pills say what was pressed.
    for (const { tag, node } of lines) node.ariaPressed = String(tags.includes(tag));
    after = then;
    void fill();
  }

  void fill();
  return {
    node: el("section", { className: "flex f-col g-10" }, el("span", { className: "fs-small semi" }, wording("sort-filter-tags")), el("span", { className: "meta" }, wording("sort-filter-tags-every")), find, notice, list, nothing),
    chosen: () => tags,
    clear: () => choose([], () => {}),
  };
}
