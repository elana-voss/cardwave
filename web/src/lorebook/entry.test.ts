// What entry.ts decides, without a browser: which entry an address names, what a line of the list says, which
// entries a search leaves, and what the field of keywords takes and gives away.
//
// `entry` is an entry with what the test names of it; `field` puts a field of keywords into the page and
// answers with its place to type, its list and how often it told of a change; `press` sends a key to that
// place and answers whether the key was left to the form (a key that was taken is `defaultPrevented`).
import { afterEach, describe, expect, test } from "vitest";
import type { EditEntry } from "../api/generated/EditEntry";
import { entryOf, keys, matches, NEW, said } from "./entry";

afterEach(() => document.body.replaceChildren());

const entry = (of: Partial<EditEntry>): EditEntry => ({
  reference: "lore.one",
  label: "One",
  name: "One",
  trigger: "keyword",
  keywords: [],
  content: "",
  enabled: true,
  at_depth: false,
  depth: 4,
  order: 100,
  secondary: [],
  logic: "and_any",
  probability: 100,
  scan_depth: 0,
  case_sensitive: false,
  whole_words: false,
  ...of,
});

describe("entryOf", () => {
  test("an address names an entry by its reference, as one part, or the one being written, or none", () => {
    expect(entryOf("#/library/lorebooks/3")).toBeNull();
    expect(entryOf("#/library/lorebooks/3/")).toBeNull();
    expect(entryOf("#/library/lorebooks/3/lore.coast-wreck")).toBe("lore.coast-wreck");
    expect(entryOf(`#/library/lorebooks/3/${NEW}`)).toBe(NEW);
    // A reference with signs an address keeps for itself is written so that it stays one part.
    expect(entryOf(`#/library/lorebooks/3/${encodeURIComponent("lore.a/b c%")}`)).toBe("lore.a/b c%");
    // What cannot be read back stays as it stands.
    expect(entryOf("#/library/lorebooks/3/lore.50%")).toBe("lore.50%");
  });
});

describe("said", () => {
  test("a line says what its entry is used by: its keywords, or that it always is, or by meaning", () => {
    expect(said(entry({ keywords: ["council", "twelve", "lords"] }))).toBe("Keywords: council, twelve, lords");
    expect(said(entry({ keywords: [] }))).toBe("No keywords");
    expect(said(entry({ trigger: "always", keywords: ["guard"] }))).toBe("Always");
    expect(said(entry({ trigger: "vector", keywords: ["oath"] }))).toBe("By meaning");
  });
});

describe("matches", () => {
  test("a search leaves the entries that have each of its words in their name or keywords, in any case", () => {
    const council = entry({ label: "The Council of Twelve", keywords: ["lords", "Camlann"], content: "They meet at each new moon." });
    expect(matches(council, "")).toBe(true);
    expect(matches(council, "council")).toBe(true);
    expect(matches(council, "TWELVE camlann")).toBe(true);
    expect(matches(council, "council keep")).toBe(false);
    // An entry is found by what its line shows, not by what it tells the model.
    expect(matches(council, "moon")).toBe(false);
  });
});

describe("keys", () => {
  function field(list: string[]): { input: HTMLInputElement; told: () => number; pills: () => string[]; node: HTMLElement } {
    let told = 0;
    const node = keys("Keywords", "Add a keyword", list, () => told++);
    document.body.append(node);
    return {
      node,
      input: node.querySelector("input")!,
      told: () => told,
      pills: () => [...node.querySelectorAll(".key")].map((pill) => pill.textContent ?? ""),
    };
  }
  const press = (input: HTMLInputElement, key: string): boolean => input.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }));

  test("the keywords an entry has are pills, in their order, and the field is named", () => {
    const { node, pills, input } = field(["council", "twelve"]);
    expect(pills()).toEqual(["council", "twelve"]);
    expect(node.querySelector("label")?.textContent).toBe("Keywords");
    expect(node.querySelector("label")?.htmlFor).toBe(input.id);
    expect(input.placeholder).toBe("Add a keyword");
  });

  test("Enter adds what is typed, without the space around it, and is not the form's then", () => {
    const list = ["council"];
    const { input, pills, told } = field(list);
    input.value = "  the lords ";
    expect(press(input, "Enter")).toBe(false);
    expect(list).toEqual(["council", "the lords"]);
    expect(pills()).toEqual(["council", "the lords"]);
    expect([input.value, told()]).toEqual(["", 1]);
    // The Enter that ends a word an input method is putting together adds nothing.
    input.value = "とう";
    expect(input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", isComposing: true, cancelable: true }))).toBe(true);
    expect([list.length, input.value]).toEqual([2, "とう"]);
    input.value = "";
    // With nothing typed, Enter is the form's: it saves.
    expect(press(input, "Enter")).toBe(true);
    input.value = "   ";
    expect(press(input, "Enter")).toBe(true);
    expect([list.length, told()]).toEqual([2, 1]);
  });

  test("a keyword that is there already is not added again", () => {
    const list = ["council"];
    const { input, pills, told } = field(list);
    input.value = "council";
    press(input, "Enter");
    expect([list, pills(), input.value, told()]).toEqual([["council"], ["council"], "", 0]);
  });

  test("leaving the field adds what is typed, so that it is not lost", () => {
    const list: string[] = [];
    const { input, pills, told } = field(list);
    input.value = "keep";
    input.dispatchEvent(new FocusEvent("blur"));
    expect([list, pills(), input.value, told()]).toEqual([["keep"], ["keep"], "", 1]);
    // Left with nothing typed, nothing is added.
    input.dispatchEvent(new FocusEvent("blur"));
    expect([list, told()]).toEqual([["keep"], 1]);
  });

  test("the × of a pill takes that keyword away, and the place to type has the focus", () => {
    const list = ["council", "twelve", "lords"];
    const { node, input, pills, told } = field(list);
    const off = node.querySelectorAll<HTMLButtonElement>(".key button")[1];
    expect(off.ariaLabel).toBe("Remove twelve");
    off.click();
    expect([list, pills(), told()]).toEqual([["council", "lords"], ["council", "lords"], 1]);
    expect(document.activeElement).toBe(input);
  });

  test("Backspace in the empty place takes the last keyword away, and with words typed it is the field's own", () => {
    const list = ["council", "twelve"];
    const { input, pills, told } = field(list);
    input.value = "lor";
    press(input, "Backspace");
    expect([list.length, told()]).toEqual([2, 0]);
    input.value = "";
    press(input, "Backspace");
    expect([list, pills(), told()]).toEqual([["council"], ["council"], 1]);
    press(input, "Backspace");
    press(input, "Backspace");
    expect([list, pills(), told()]).toEqual([[], [], 2]);
  });

  test("a press on the field beside its pills is one on the place to type", () => {
    const { node, input } = field(["council"]);
    const box = node.querySelector<HTMLElement>(".keys")!;
    node.querySelector<HTMLElement>(".key")!.click();
    expect(document.activeElement).not.toBe(input);
    box.click();
    expect(document.activeElement).toBe(input);
  });

  test("what goes with the keywords stands under the field", () => {
    const hint = document.createElement("p");
    const node = keys("Secondary keywords", "Add a keyword", [], () => {}, hint);
    expect(node.lastElementChild).toBe(hint);
  });
});
