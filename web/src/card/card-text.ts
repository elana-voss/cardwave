// A card's text on its page: its Markdown rendered (`markdown`), an earlier draft told against the text as it
// is (`compare`, word by word; `marked` as shown), the AI tools (`textTools()`) and what a draft is called by what made it (`madeBy`).
//
// The Markdown is the little a card's texts use: paragraphs parted by an empty line, a line break kept, headings
// (#, ##, ###), lists (-, * or 1.), quotation blocks and the marks, read as a chat reads them (marks.ts); with
// `links` (a chat without a character) also links and addresses. It is made of elements, never of HTML read, so a
// card's words cannot put markup on the page.
import type { AiTool } from "../api/generated/AiTool";
import { el } from "../dom";
import type { IconName } from "../icons";
import { units } from "../marks";
import { block, inline } from "../narration";
import { wording } from "../language/language";

/** The names a card's texts read with in place of `{{char}}` and `{{user}}`. */
export interface Names {
  char: string;
  user: string;
}

/** `text` with `{{char}}` and `{{user}}` (in any case) as `names`, for reading; the text itself keeps them. */
export const named = (text: string, names: Names): string => text.replace(/\{\{(char|user)\}\}/gi, (_, which: string) => (which.toLowerCase() === "char" ? names.char : names.user));

/**
 * A text as the elements its Markdown makes, read in the units a chat's message is (marks.ts `units`): a heading or
 * list where every line of a block is one, else the block as a chat draws it (narration.ts `block`), its lines'
 * ends kept as written (the stylesheet breaks them). With `open` the text is still being written; a text of blank
 * lines alone is nothing.
 */
export function markdown(text: string, links = false, open = false): HTMLElement[] {
  return units(text).flatMap((unit): HTMLElement[] => {
    const rows = unit.text.split("\n").filter((row) => row.trim());
    // Only the text's last row is still being written.
    const line = (words: string, at: number) => inline(words, links, open && unit.last && at === rows.length - 1);
    const every = (pattern: RegExp) => !unit.quote && rows.every((row) => pattern.test(row));
    const heading = /^(#{1,3})\s+(.*)$/;
    if (every(heading)) return rows.map((row) => heading.exec(row)!).map(([, marks, words], at) => el(`h${marks.length + 2}` as "h3", null, ...line(words, at)));
    const items = (pattern: RegExp) => rows.map((row, at) => el("li", null, ...line(row.replace(pattern, ""), at)));
    if (every(/^\s*[-*]\s+/)) return [el("ul", null, ...items(/^\s*[-*]\s+/))];
    if (every(/^\s*\d+\.\s+/)) return [el("ol", null, ...items(/^\s*\d+\.\s+/))];
    return [block(unit, { links, open: open && unit.last })];
  });
}

/** A stretch of an earlier draft told against the text as it is: in both, only in the draft, or only in the text. */
export interface Stretch {
  text: string;
  kind: "same" | "back" | "gone";
}

/** The most pairs of words `compare` weighs: a table of more would freeze the page. */
const PAIRS = 4_000_000;

/**
 * `then`, an earlier draft, against `now`, the text as it is, word by word (spaces stay with what they follow).
 * Where more than `PAIRS` pairs of words differ (a long text rewritten throughout), those between the words both
 * start and end with are told as gone and back whole.
 */
export function compare(now: string, then: string): Stretch[] {
  const words = (text: string) => text.match(/\S+\s*|\s+/g) ?? [];
  const all = words(now);
  const before = words(then);
  // The words both start and end with are the same: only those between are compared, which keeps a long text quick.
  let start = 0;
  while (start < all.length && start < before.length && all[start] === before[start]) start++;
  let end = 0;
  while (end < all.length - start && end < before.length - start && all[all.length - 1 - end] === before[before.length - 1 - end]) end++;
  const a = all.slice(start, all.length - end);
  const b = before.slice(start, before.length - end);
  const told: Stretch[] = [];
  const add = (text: string, kind: Stretch["kind"]) => {
    const last = told[told.length - 1];
    if (last?.kind === kind) last.text += text;
    else told.push({ text, kind });
  };
  add(all.slice(0, start).join(""), "same");
  if ((a.length + 1) * (b.length + 1) > PAIRS) {
    add(a.join(""), "gone");
    add(b.join(""), "back");
  } else {
    // The longest run of words both have, from the end: `longest[i][j]` for a[i..] and b[j..].
    const width = b.length + 1;
    const longest = new Uint32Array((a.length + 1) * width);
    for (let i = a.length - 1; i >= 0; i--) {
      for (let j = b.length - 1; j >= 0; j--) {
        longest[i * width + j] = a[i] === b[j] ? longest[(i + 1) * width + j + 1] + 1 : Math.max(longest[(i + 1) * width + j], longest[i * width + j + 1]);
      }
    }
    let i = 0;
    let j = 0;
    while (i < a.length || j < b.length) {
      if (i < a.length && j < b.length && a[i] === b[j]) {
        add(a[i++], "same");
        j++;
      } else if (i < a.length && (j === b.length || longest[(i + 1) * width + j] >= longest[i * width + j + 1])) add(a[i++], "gone");
      else add(b[j++], "back");
    }
  }
  add(all.slice(all.length - end).join(""), "same");
  // A run of changed words leaves its last space to the words both have after it, outside its marks.
  for (let at = 0; at < told.length; at++) {
    if (told[at].kind === "same") continue;
    let end = at;
    while (told[end + 1] && told[end + 1].kind !== "same") end++;
    const next = told[end + 1];
    let space = "";
    for (let one = at; next && one <= end; one++) {
      const trailing = /\s+$/.exec(told[one].text);
      if (!trailing) continue;
      space = trailing[0];
      told[one].text = told[one].text.slice(0, trailing.index);
    }
    if (next) next.text = space + next.text;
    at = end;
  }
  return told.filter((one) => one.text);
}

/**
 * `then` against `now` as a text shows it (`compare`): words only in `then` marked as written in, those only in
 * `now` struck through; and how many changes (a run of words taken out or written in, between words that stay).
 */
export function marked(now: string, then: string): { count: number; words: (HTMLElement | string)[] } {
  const stretches = compare(now, then);
  const count = stretches.filter((one, at) => one.kind !== "same" && (at === 0 || stretches[at - 1].kind === "same")).length;
  return { count, words: stretches.map(({ text, kind }) => (kind === "same" ? text : el(kind === "back" ? "ins" : "del", { className: "ch" }, text))) };
}

/**
 * A text's AI tools, by the background model: the tool, its line in the menu, what the text's foot says while it
 * works, and what a field in the menu asks first (the language, the change).
 */
export const textTools = (): { tool: AiTool; name: string; working: string; shape: IconName; asks?: string }[] => ([
  { tool: "improve", name: wording("card-text-improve-the-prose"), working: wording("card-text-improving-the-prose"), shape: "sparkle" },
  { tool: "fix", name: wording("card-text-fix-grammar-and-spelling"), working: wording("card-text-fixing-grammar-and-spelling"), shape: "check" },
  { tool: "shorter", name: wording("card-text-make-it-shorter"), working: wording("card-text-making-it-shorter"), shape: "shorter" },
  { tool: "longer", name: wording("card-text-make-it-longer"), working: wording("card-text-making-it-longer"), shape: "longer" },
  { tool: "translate", name: wording("character-translate"), working: wording("card-text-translating"), shape: "globe", asks: wording("lore-tools-into-which-language") },
  { tool: "ask", name: wording("card-text-ask-for-a-change"), working: wording("card-text-changing-it"), shape: "chat", asks: wording("card-text-what-should-change") },
]);

/** What a draft is called, by what made it: an AI tool that asks nothing first by its line in `textTools()`. */
export function madeBy(made: string): string {
  const named: Record<string, string> = {
    edited: wording("card-text-edited-by-you"),
    imported: wording("importing-imported"),
    restored: wording("card-text-restored"),
    translated: wording("card-text-translated"),
    ask: wording("card-block-changed-as-asked"),
  };
  return named[made] ?? textTools().find((one) => one.tool === made && !one.asks)?.name ?? made;
}
