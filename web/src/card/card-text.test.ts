// What card-text.ts decides: how a card's text shows rendered, what an earlier draft changes, and a draft's name.
import { expect, test } from "vitest";
import { narrated } from "../narration";
import { compare, madeBy, markdown, named } from "./card-text";

const html = (text: string) => markdown(text).map((node) => (typeof node === "string" ? node : node.outerHTML)).join("");

test("a text's Markdown shows rendered: paragraphs, lines, headings, lists, quotes, bold, code and narration", () => {
  expect(html("One\ntwo\n\nThree")).toBe("<p>One\ntwo</p><p>Three</p>");
  expect(html("# Past\n## Now")).toBe("<h3>Past</h3><h4>Now</h4>");
  expect(html("- red\n* blue")).toBe("<ul><li>red</li><li>blue</li></ul>");
  expect(html("1. one\n2. two")).toBe("<ol><li>one</li><li>two</li></ol>");
  expect(html("> said\n> twice")).toBe("<blockquote><p>said\ntwice</p></blockquote>");
  expect(html('**Bold** and `code` and *she nods* "Go."')).toBe('<p><strong>Bold</strong> and <code>code</code> and <em>she nods</em> <span class="speech">"Go."</span></p>');
  // What is written as markup is shown as text, never read as HTML.
  expect(html("<b>x</b> 2 * 3")).toBe("<p>&lt;b&gt;x&lt;/b&gt; 2 * 3</p>");
  expect(markdown("  \n\n ")).toEqual([]);
});

test("a text reads as a chat with a character reads it: a fence, marks across a line, quotation blocks, a mark left open", () => {
  const chat = (text: string, open = false) => narrated(text, open).filter((node) => typeof node !== "string").map((node) => (node as HTMLElement).outerHTML).join("");
  for (const text of ['```python\nprint("hi")\n\n```', "*She leans\ncloser.*", "Intro:\n> quoted", ">quoted"]) expect(html(text)).toBe(chat(text));
  expect(html('```python\nprint("hi")\n\n```')).toBe('<p><code>print("hi")\n</code></p>');
  expect(markdown("*She leans", true, true).map((node) => node.outerHTML).join("")).toBe(chat("*She leans", true));
});

test("a list or heading still being written keeps its open mark from showing as written", () => {
  const open = (text: string) => markdown(text, true, true).map((node) => node.textContent).join("|");
  expect(open("Options:\n\n- **Fast")).not.toContain("*");
  expect(open("## *Plan")).not.toContain("*");
  // Only the last row is still being written: a closed list above keeps its asterisks as written.
  expect(open("- **a\n- b")).toContain("**a");
});

test("with links, an address in the Markdown opens in the browser; without, it stays text", () => {
  const html = (nodes: HTMLElement[]) => nodes.map((node) => node.outerHTML).join("");
  const text = "- **1.83** at https://example.org/notes";
  expect(html(markdown(text, true))).toContain('<li><strong>1.83</strong> at <a href="https://example.org/notes"');
  expect(html(markdown(text))).not.toContain("<a ");
});

test("an earlier draft is told against the text as it is: what would come back, and what would go", () => {
  expect(compare("A dry old keeper.", "A kind old keeper.")).toEqual([
    { text: "A ", kind: "same" },
    { text: "dry", kind: "gone" },
    { text: "kind", kind: "back" },
    { text: " old keeper.", kind: "same" },
  ]);
  expect(compare("Same.", "Same.")).toEqual([{ text: "Same.", kind: "same" }]);
  expect(compare("", "New words")).toEqual([{ text: "New words", kind: "back" }]);

  // A long text with a word changed is told at once: the words both start and end with are not compared.
  const long = (word: string) => `${"start ".repeat(30_000)}${word} ${"end ".repeat(30_000)}`.trim();
  expect(compare(long("dry"), long("kind")).map(({ kind }) => kind)).toEqual(["same", "gone", "back", "same"]);

  // A long text rewritten throughout is told as gone and back whole, not compared word by word.
  const now = "a b ".repeat(4_000).trim();
  const then = "b a ".repeat(4_000).trim();
  expect(compare(now, then)).toEqual([
    { text: now, kind: "gone" },
    { text: then, kind: "back" },
  ]);
});

test("{{char}} and {{user}} read as the names, in any case; other braces stay", () => {
  expect(named("{{char}} greets {{User}}. {{CHAR}}'s {{other}}", { char: "Moss", user: "Ann" })).toBe("Moss greets Ann. Moss's {{other}}");
});

test("a draft is named by what made it", () => {
  expect(["edited", "imported", "restored", "translated", "Make it shorter"].map(madeBy)).toEqual([
    "Edited by you",
    "Imported",
    "Restored",
    "Translated",
    "Make it shorter",
  ]);
});
