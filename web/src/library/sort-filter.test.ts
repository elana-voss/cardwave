// What the panel "Sort and filter" decides, without a browser: what is chosen in it and when that counts,
// which tags can be pressed, what a late or a failed answer changes, and where the focus goes. The tags it is
// answered with are the test's own. How the panel looks and what the list does with it is the browser tests'.
//
// `filter` gives the panel a list's choice and holds each asking for the tags until the test answers it;
// `sorter` is the panel of a list without tags, "Sort".
import { afterEach, expect, test, vi } from "vitest";
import type { TagCount } from "../api/generated/TagCount";
import { el } from "../dom";
import { sortFilter } from "./sort-filter";

afterEach(() => {
  vi.useRealTimers();
  document.body.replaceChildren();
});

const SORTS: [string, string][] = [
  ["recent", "Recently added"],
  ["name", "Name"],
];
const tag = (name: string, cards = 1, chosen = false): TagCount => ({ tag: name, cards, chosen });
/** As many tags as told, none chosen. */
const many = (count: number) => Array.from({ length: count }, (_, at) => tag(`tag-${at + 1}`));

/** Lets what waits for an answer that has come go on. */
const settled = () => new Promise((done) => setTimeout(done));

/** An answer to the panel's asking for the tags, given when the test says. */
interface Asking {
  /** The tags chosen that it was asked with. */
  tags: string[];
  answer(found: TagCount[]): Promise<void>;
  fail(error: Error): Promise<void>;
}

/**
 * The button over a list that was asked for `asked`, with what the panel shows once it is open. Each asking for
 * the tags waits in `askings` until the test answers it.
 */
function filter(asked = { sort: "recent", tags: [] as string[] }) {
  const home = el("div");
  document.body.append(home);
  const askings: Asking[] = [];
  const changed = vi.fn();
  const read = (tags: string[]) =>
    new Promise<TagCount[]>((resolve, reject) => {
      const after = <T>(settle: (value: T) => void) => async (value: T) => {
        settle(value);
        await settled();
      };
      askings.push({ tags: [...tags], answer: after(resolve), fail: after(reject) });
    });
  const button = sortFilter(home, SORTS, asked, changed, read);
  home.append(button);

  const box = () => home.querySelector("dialog");
  const part = (at: number) => box()!.querySelectorAll(".sort-sheet > section")[at];
  const pills = () => [...part(1).querySelectorAll<HTMLButtonElement>(".pills .pill")];
  const named = (pill: HTMLButtonElement) => pill.textContent ?? "";
  return {
    asked,
    askings,
    changed,
    button,
    box,
    open: () => button.click(),
    /** The newest asking, which is the one the panel waits for. */
    asking: () => askings.at(-1)!,
    orders: () => [...part(0).querySelectorAll<HTMLButtonElement>(".pill")],
    pills,
    pill: (name: string) => pills().find((pill) => named(pill) === name)!,
    shown: () => pills().filter((pill) => !pill.hidden).map(named),
    pressed: () => pills().filter((pill) => pill.ariaPressed === "true").map(named),
    greyed: () => pills().filter((pill) => pill.disabled).map(named),
    finder: () => part(1).querySelector<HTMLElement>(".search")!,
    field: () => part(1).querySelector<HTMLInputElement>(".search input")!,
    nothing: () => part(1).querySelector<HTMLElement>("p.hint")!,
    alert: () => box()!.querySelector('[role="alert"]')?.textContent ?? null,
    apply: () => box()!.querySelector<HTMLButtonElement>("footer .btn-primary")!,
    clear: () => box()!.querySelector<HTMLButtonElement>("footer button:not(.btn-primary)")!,
    close: () => box()!.querySelector<HTMLButtonElement>("header button")!,
  };
}

test("the button says whether tags are chosen, and how many", () => {
  const none = filter().button;
  expect(none.ariaLabel).toBe("Sort and filter");
  expect(none.classList.contains("on")).toBe(false);
  const one = filter({ sort: "recent", tags: ["sea"] }).button;
  expect(one.ariaLabel).toBe("Sort and filter: 1 tag chosen");
  expect(one.title).toBe(one.ariaLabel);
  expect(one.classList.contains("on")).toBe(true);
  expect(filter({ sort: "recent", tags: ["sea", "reeds"] }).button.ariaLabel).toBe("Sort and filter: 2 tags chosen");
});

test("the panel has the orders with the list's pressed, and asks for the tags with those the list has: the chosen are pressed, and one that would leave no card cannot be", async () => {
  const panel = filter({ sort: "name", tags: ["sea"] });
  panel.open();
  expect(panel.button.ariaExpanded).toBe("true");
  expect(panel.orders().map((order) => [order.textContent, order.ariaPressed])).toEqual([
    ["Recently added", "false"],
    ["Name", "true"],
  ]);
  expect(panel.askings.map((asking) => asking.tags)).toEqual([["sea"]]);
  // Until the tags have come there is no pill, nothing is said of tags, and there is nothing to clear.
  expect(panel.pills()).toEqual([]);
  expect(panel.nothing().hidden).toBe(true);
  expect(panel.clear().disabled).toBe(true);

  await panel.asking().answer([tag("sea", 2, true), tag("reeds", 1), tag("peak", 0), tag("gone", 0, true)]);
  expect(panel.shown()).toEqual(["sea", "reeds", "peak", "gone"]);
  expect(panel.pressed()).toEqual(["sea", "gone"]);
  // A tag chosen that no card has any more can still be given up.
  expect(panel.greyed()).toEqual(["peak"]);
  expect(panel.clear().disabled).toBe(false);
  expect(panel.nothing().hidden).toBe(true);
});

test("an order pressed is the one pressed, and counts with Apply, as the tags do: the list is told once", async () => {
  const panel = filter();
  const tags = panel.asked.tags;
  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds")]);
  panel.orders()[1].click();
  expect(panel.orders().map((order) => order.ariaPressed)).toEqual(["false", "true"]);
  panel.pill("reeds").click();
  await panel.asking().answer([tag("sea"), tag("reeds", 1, true)]);
  // Nothing counts before Apply.
  expect(panel.asked).toEqual({ sort: "recent", tags: [] });
  expect(panel.changed).not.toHaveBeenCalled();

  panel.apply().click();
  expect(panel.asked).toEqual({ sort: "name", tags: ["reeds"] });
  // The list's own tags are changed, not replaced: who holds them sees the choice.
  expect(panel.asked.tags).toBe(tags);
  expect(panel.changed).toHaveBeenCalledTimes(1);
  expect(panel.box()).toBeNull();
  expect(panel.button.ariaExpanded).toBe("false");
  expect(panel.button.ariaLabel).toBe("Sort and filter: 1 tag chosen");
  expect(panel.button.classList.contains("on")).toBe(true);
});

test("what is chosen in the panel and not applied is dropped when it closes, and the panel opens with the list's choice again", async () => {
  const panel = filter({ sort: "recent", tags: ["sea"] });
  panel.open();
  await panel.asking().answer([tag("sea", 1, true), tag("reeds")]);
  panel.orders()[1].click();
  panel.pill("reeds").click();
  await panel.asking().answer([tag("sea", 1, true), tag("reeds", 1, true)]);
  panel.close().click();
  expect(panel.box()).toBeNull();
  expect(panel.button.ariaExpanded).toBe("false");
  expect(panel.asked).toEqual({ sort: "recent", tags: ["sea"] });
  expect(panel.changed).not.toHaveBeenCalled();
  expect(panel.button.ariaLabel).toBe("Sort and filter: 1 tag chosen");

  panel.open();
  expect(panel.asking().tags).toEqual(["sea"]);
  expect(panel.orders().map((order) => order.ariaPressed)).toEqual(["true", "false"]);
});

test("a tag pressed says so at once, and the tags are asked for anew with the choice it leaves", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds"), tag("peak")]);
  panel.pill("sea").click();
  // Before the server has said which tags are left.
  expect(panel.pressed()).toEqual(["sea"]);
  expect(panel.clear().disabled).toBe(false);
  expect(panel.asking().tags).toEqual(["sea"]);
  await panel.asking().answer([tag("sea", 1, true), tag("reeds"), tag("peak", 0)]);
  expect(panel.greyed()).toEqual(["peak"]);

  panel.pill("reeds").click();
  expect(panel.asking().tags).toEqual(["sea", "reeds"]);
  await panel.asking().answer([tag("sea", 1, true), tag("reeds", 1, true), tag("peak", 0)]);
  // Pressed again, a tag is given up.
  panel.pill("sea").click();
  expect(panel.pressed()).toEqual(["reeds"]);
  expect(panel.asking().tags).toEqual(["reeds"]);
});

test("Clear all unpresses every tag and leaves the order; with nothing left to clear it cannot be pressed, and the focus is on Apply", async () => {
  const panel = filter({ sort: "name", tags: ["sea", "reeds"] });
  panel.open();
  await panel.asking().answer([tag("sea", 1, true), tag("reeds", 1, true), tag("peak", 0)]);
  panel.clear().click();
  expect(panel.pressed()).toEqual([]);
  expect(panel.asking().tags).toEqual([]);
  expect(panel.clear().disabled).toBe(true);
  expect(document.activeElement).toBe(panel.apply());
  await panel.asking().answer([tag("sea"), tag("reeds"), tag("peak")]);
  expect(panel.greyed()).toEqual([]);
  expect(panel.orders().map((order) => order.ariaPressed)).toEqual(["false", "true"]);
  // The list has its tags until Apply.
  expect(panel.asked.tags).toEqual(["sea", "reeds"]);
  panel.apply().click();
  expect(panel.asked).toEqual({ sort: "name", tags: [] });
  expect(panel.button.ariaLabel).toBe("Sort and filter");
  expect(panel.button.classList.contains("on")).toBe(false);
});

test("eight tags are few and nine are many: many have a field that finds one, by what is typed in any case", async () => {
  const few = filter();
  few.open();
  await few.asking().answer(many(8));
  expect(few.finder().hidden).toBe(true);
  few.close().click();

  vi.useFakeTimers();
  const panel = filter();
  panel.open();
  panel.asking().answer([...many(8), tag("Tern")]);
  await vi.advanceTimersByTimeAsync(0);
  expect(panel.finder().hidden).toBe(false);
  expect(panel.shown()).toHaveLength(9);

  /** Types into the field and waits out the pause after which it searches. */
  const type = async (text: string) => {
    panel.field().value = text;
    panel.field().dispatchEvent(new Event("input"));
    await vi.advanceTimersByTimeAsync(200);
  };
  await type("TAG-1");
  expect(panel.shown()).toEqual(["tag-1"]);
  expect(panel.nothing().hidden).toBe(true);
  await type(" tern ");
  expect(panel.shown()).toEqual(["Tern"]);
  await type("qq");
  expect(panel.shown()).toEqual([]);
  expect(panel.nothing().hidden).toBe(false);
  expect(panel.nothing().textContent).toBe("No tags match “qq”.");
  await type("");
  expect(panel.shown()).toHaveLength(9);
  expect(panel.nothing().hidden).toBe(true);
});

test("the tags found stay the ones in view when the tags are read anew, and a library without tags says so", async () => {
  vi.useFakeTimers();
  const panel = filter();
  panel.open();
  panel.asking().answer([...many(9), tag("Tern")]);
  await vi.advanceTimersByTimeAsync(0);
  panel.field().value = "tag-1";
  panel.field().dispatchEvent(new Event("input"));
  await vi.advanceTimersByTimeAsync(200);
  panel.pill("tag-1").click();
  panel.asking().answer([tag("tag-1", 1, true), ...many(9).slice(1), tag("Tern")]);
  await vi.advanceTimersByTimeAsync(0);
  expect(panel.shown()).toEqual(["tag-1"]);
  expect(panel.pressed()).toEqual(["tag-1"]);
  vi.useRealTimers();

  const empty = filter();
  empty.open();
  await empty.asking().answer([]);
  expect(empty.nothing().hidden).toBe(false);
  expect(empty.nothing().textContent).toBe("No tags to choose from.");
  expect(empty.finder().hidden).toBe(true);
});

test("tags answered late never replace a newer answer", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds"), tag("peak"), tag("dune")]);
  panel.pill("sea").click();
  const first = panel.asking();
  panel.pill("reeds").click();
  const second = panel.asking();
  expect([first.tags, second.tags]).toEqual([["sea"], ["sea", "reeds"]]);

  // The answer to the second press comes first; the first press's, which would grey no tag, comes after it.
  await second.answer([tag("sea", 1, true), tag("reeds", 1, true), tag("peak", 0), tag("dune", 0)]);
  expect(panel.greyed()).toEqual(["peak", "dune"]);
  await first.answer([tag("sea", 2, true), tag("reeds"), tag("peak"), tag("dune")]);
  expect(panel.greyed()).toEqual(["peak", "dune"]);
  expect(panel.pressed()).toEqual(["sea", "reeds"]);
});

test("tags that cannot be read say why, and are read the next time the panel opens", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().fail(new Error("the tags are away"));
  expect(panel.alert()).toBe("The tags are away");
  expect(panel.pills()).toEqual([]);
  panel.close().click();

  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds")]);
  expect(panel.shown()).toEqual(["sea", "reeds"]);
  expect(panel.alert()).toBeNull();
});

test("a tag pressed while the tags cannot be read is chosen all the same: its pill says so, and Apply gives it to the list", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds")]);
  panel.pill("reeds").click();
  await panel.asking().fail(new Error("the tags are away"));
  expect(panel.alert()).toBe("The tags are away");
  expect(panel.pressed()).toEqual(["reeds"]);
  expect(panel.clear().disabled).toBe(false);
  panel.apply().click();
  expect(panel.asked.tags).toEqual(["reeds"]);
  expect(panel.button.ariaLabel).toBe("Sort and filter: 1 tag chosen");
});

test("a tag is given up by the name its pill has, also where the server writes it otherwise than it was chosen", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("nightwatch"), tag("sea")]);
  panel.pill("nightwatch").click();
  // As it would when most cards have come to write the tag so.
  await panel.asking().answer([tag("Nightwatch", 2, true), tag("sea")]);
  expect(panel.pressed()).toEqual(["Nightwatch"]);

  panel.pill("Nightwatch").click();
  expect(panel.asking().tags).toEqual([]);
  expect(panel.pressed()).toEqual([]);
  expect(panel.clear().disabled).toBe(true);
});

test("a tag chosen under the name the server gives it is the one applied", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("nightwatch")]);
  panel.pill("nightwatch").click();
  await panel.asking().answer([tag("Nightwatch", 2, true)]);
  panel.apply().click();
  expect(panel.asked.tags).toEqual(["Nightwatch"]);
});

test("when the tags are drawn anew the focus is on the tag pressed; where that cannot be pressed any more, or is gone, on the first that can", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer([tag("sea"), tag("reeds"), tag("peak")]);
  panel.pill("reeds").click();
  await panel.asking().answer([tag("sea"), tag("reeds", 1, true), tag("peak")]);
  expect(document.activeElement).toBe(panel.pill("reeds"));

  // Given up, no card has it any more: it cannot be pressed again.
  panel.pill("reeds").click();
  await panel.asking().answer([tag("sea", 0), tag("reeds", 0), tag("peak")]);
  expect(panel.greyed()).toEqual(["sea", "reeds"]);
  expect(document.activeElement).toBe(panel.pill("peak"));

  // Given up, it is gone.
  panel.pill("peak").click();
  await panel.asking().answer([tag("sea", 0), tag("peak", 1, true)]);
  panel.pill("peak").click();
  await panel.asking().answer([tag("sea")]);
  expect(document.activeElement).toBe(panel.pill("sea"));
});

test("with a field to find tags in, the focus goes there from a tag that cannot be pressed any more; with no tag left, to the ×", async () => {
  const panel = filter();
  panel.open();
  await panel.asking().answer(many(9));
  panel.pill("tag-3").click();
  await panel.asking().answer(many(9).map((one) => (one.tag === "tag-3" ? tag("tag-3", 1, true) : one)));
  panel.pill("tag-3").click();
  await panel.asking().answer(many(9).map((one) => (one.tag === "tag-3" ? tag("tag-3", 0) : one)));
  expect(panel.pill("tag-3").disabled).toBe(true);
  expect(document.activeElement).toBe(panel.field());

  const last = filter();
  last.open();
  await last.asking().answer([tag("sea", 1, true)]);
  last.pill("sea").click();
  await last.asking().answer([]);
  expect(last.nothing().textContent).toBe("No tags to choose from.");
  expect(document.activeElement).toBe(last.close());
});

/** The button over a list without tags, which was asked for the order `sort`, and what its panel shows once it is open. */
function sorter(sort = "recent") {
  const home = el("div");
  document.body.append(home);
  const asked = { sort };
  const changed = vi.fn();
  const button = sortFilter(home, SORTS, asked, changed);
  home.append(button);
  const box = () => home.querySelector("dialog");
  return {
    asked,
    changed,
    button,
    box,
    orders: () => [...box()!.querySelectorAll<HTMLButtonElement>(".pill")],
    pressed: () => [...box()!.querySelectorAll<HTMLButtonElement>(".pill")].filter((pill) => pill.ariaPressed === "true").map((pill) => pill.textContent),
    apply: () => box()!.querySelector<HTMLButtonElement>("footer .btn-primary")!,
    clear: () => box()!.querySelector<HTMLButtonElement>("footer button:not(.btn-primary)")!,
  };
}

test("a list without tags has the panel as Sort: the orders alone, and nothing is asked for", () => {
  const panel = sorter();
  expect(panel.button.ariaLabel).toBe("Sort");
  expect(panel.button.classList.contains("on")).toBe(false);
  panel.button.click();
  expect(panel.box()!.ariaLabel).toBe("Sort");
  expect(panel.box()!.querySelectorAll(".sort-sheet > section")).toHaveLength(1);
  // No tags are read, so nothing can fail to be.
  expect(panel.box()!.querySelector('[role="alert"]')).toBeNull();
  expect(panel.orders().map((pill) => pill.textContent)).toEqual(["Recently added", "Name"]);
  expect(panel.pressed()).toEqual(["Recently added"]);
});

test("Sort says while another order than the list's own is chosen, once it is applied", () => {
  const panel = sorter();
  panel.button.click();
  panel.orders()[1].click();
  // Not before Apply.
  expect(panel.button.classList.contains("on")).toBe(false);
  panel.apply().click();
  expect(panel.asked.sort).toBe("name");
  expect(panel.changed).toHaveBeenCalledTimes(1);
  expect(panel.button.classList.contains("on")).toBe(true);
  expect(panel.button.ariaLabel).toBe("Sort: by Name");
});

test("in Sort, Clear all goes back to the list's own order, and cannot be pressed while that is the one chosen", () => {
  const panel = sorter("name");
  expect(panel.button.classList.contains("on")).toBe(true);
  panel.button.click();
  expect(panel.clear().disabled).toBe(false);
  panel.clear().click();
  expect(panel.pressed()).toEqual(["Recently added"]);
  expect(panel.clear().disabled).toBe(true);
  expect(document.activeElement).toBe(panel.apply());
  // It counts with Apply, as an order pressed does.
  expect(panel.asked.sort).toBe("name");
  panel.apply().click();
  expect(panel.asked.sort).toBe("recent");
  expect(panel.button.classList.contains("on")).toBe(false);
  expect(panel.button.ariaLabel).toBe("Sort");
  // An order pressed can be cleared again.
  panel.button.click();
  expect(panel.clear().disabled).toBe(true);
  panel.orders()[1].click();
  expect(panel.clear().disabled).toBe(false);
});
