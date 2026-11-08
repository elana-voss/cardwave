// The lorebook editor's AI tools for the whole lorebook (the header's sparkle, `loreTools`): Write missing
// keywords, Fix grammar in every entry and Translate the lorebook…, which asks the language in the bar over the
// entry. The background model changes the entries it is given (`rewriteLore`), nothing stored; each changed
// entry's change waits in `Book.proposed`, shown over the entry against it as it is (`proposalBox`) with Keep and
// Undo, its line in the list saying "Proposed by the AI". The bar (`drawBar`) has Keep all and Undo all while some wait.
// Kept, a change is saved as the entry's words are, a version made by the tool (`saveEntry`). One tool runs at a
// time (`running`); an entry changed while it ran gets no proposal, as it was asked of words since replaced.
import { rewriteLore } from "../api/client";
import type { EditEntry } from "../api/generated/EditEntry";
import type { EntryChange } from "../api/generated/EntryChange";
import type { LoreText } from "../api/generated/LoreText";
import type { LoreTool } from "../api/generated/LoreTool";
import { marked } from "../card/card-text";
import { announce, changesBar, el, failure, reason } from "../dom";
import { menu } from "../dialogs";
import type { IconName } from "../icons";
import { saveEntry, type Book } from "./lorebook-entry";
import { wording } from "../language/language";
import { comma } from "../format";

/** An AI change of an entry that waits for Keep: what the foot says of it, what makes its version, the entry as changed. */
export interface Proposal {
  said: string;
  made: string;
  text: LoreText;
}

/** The tools, as the header's menu lists them. */
const tools = (): { tool: LoreTool; name: string; working: string; shape: IconName; made: string }[] => ([
  { tool: "keywords", name: wording("lore-tools-write-missing-keywords"), working: wording("lore-tools-writing-missing-keywords"), shape: "sparkle", made: "edited" },
  { tool: "fix", name: wording("lore-tools-fix-grammar-in-every"), working: wording("lore-tools-fixing-grammar-in-every"), shape: "check", made: "fix" },
  { tool: "translate", name: wording("lore-tools-translate-the-lorebook"), working: wording("lore-tools-translating-the-lorebook"), shape: "globe", made: "translated" },
]);

/** An entry as the background model is given it. */
const asText = (entry: EditEntry): LoreText => ({ reference: entry.reference, text: entry.content, keywords: entry.keywords, secondary_keywords: entry.secondary });

/** The entries a tool changes: those without keywords that are used by keywords, for Write missing keywords; else those with words. */
function chosen(tool: LoreTool, entries: EditEntry[]): EditEntry[] {
  const worded = entries.filter((entry) => entry.content.trim());
  return tool === "keywords" ? worded.filter((entry) => entry.keywords.length === 0 && entry.trigger !== "always") : worded;
}

/** What of an entry a proposal changes. */
function changeOf(entry: EditEntry, text: LoreText): EntryChange {
  const change: EntryChange = {};
  if (text.text !== entry.content) change.content = text.text;
  if (JSON.stringify(text.keywords) !== JSON.stringify(entry.keywords)) change.keywords = text.keywords;
  if (JSON.stringify(text.secondary_keywords) !== JSON.stringify(entry.secondary)) change.secondary = text.secondary_keywords;
  return change;
}

/** The editors whose tool runs. */
const running = new WeakSet<Book>();

/** The header's sparkle: the AI tools for the whole lorebook. A tool chosen while one runs does nothing. */
export function loreTools(b: Book): HTMLElement {
  const items = tools().map((one) => ({
    label: one.name,
    shape: one.shape,
    action: () => {
      if (running.has(b)) return;
      if (one.tool === "translate") askLanguage(b, one);
      else void run(b, one, "");
    },
  }));
  return menu(wording("lore-tools-ai-tools-for-the"), items, "sparkle", 16);
}

/** Translate the lorebook…: the bar asks into which language, sent with Enter. */
function askLanguage(b: Book, one: (ReturnType<typeof tools>)[number]): void {
  const line = el("input", { type: "text", className: "field f-grow minw0", ariaLabel: wording("lore-tools-into-which-language"), placeholder: wording("lore-tools-into-which-language"), autocomplete: "off" });
  line.onkeydown = (event) => {
    if (event.key === "Escape" && !event.isComposing) {
      event.preventDefault();
      return drawBar(b);
    }
    if (event.key !== "Enter" || event.isComposing || !line.value.trim()) return;
    event.preventDefault();
    void run(b, one, line.value.trim());
  };
  b.bar.replaceChildren(line, el("button", { type: "button", className: "btn btn-secondary", onclick: () => drawBar(b) }, wording("common-cancel")));
  b.bar.hidden = false;
  line.focus();
}

/** Runs the tool `one`, given `given`, over the lorebook's entries; its changes wait for Keep. */
async function run(b: Book, one: (ReturnType<typeof tools>)[number], given: string): Promise<void> {
  const entries = chosen(one.tool, b.book?.entries ?? []);
  if (entries.length === 0) {
    drawBar(b);
    return announce(one.tool === "keywords" ? wording("lore-tools-every-entry-has-keywords") : wording("lore-tools-no-entry-has-words"));
  }
  const stopping = new AbortController();
  const many = wording("lorebooks-entries", { count: entries.length });
  b.bar.replaceChildren(el("span", null, wording("lore-tools-working", { working: one.working, many })), el("button", { type: "button", className: "btn btn-secondary", onclick: () => stopping.abort() }, wording("gen-stop")));
  b.bar.hidden = false;
  let answered: LoreText[];
  running.add(b);
  try {
    answered = await rewriteLore({ tool: one.tool, given: given || undefined, entries: entries.map(asText) }, AbortSignal.any([stopping.signal, b.leaving.signal]));
  } catch (error) {
    drawBar(b);
    if (!stopping.signal.aborted && !b.leaving.signal.aborted) b.notice.replaceChildren(failure(reason(error)));
    return;
  } finally {
    running.delete(b);
  }
  const said = one.tool === "translate" ? wording("lore-tools-translated-into", { given }) : one.tool === "keywords" ? wording("lore-tools-keywords-written") : wording("lore-tools-grammar-fixed");
  let changed = 0;
  for (const text of answered) {
    const asked = entries.find((one) => one.reference === text.reference);
    const entry = b.book?.entries.find((one) => one.reference === text.reference);
    // Gone, or changed while the tool ran: the answer is of words no longer there.
    if (!asked || !entry || JSON.stringify(asText(asked)) !== JSON.stringify(asText(entry))) continue;
    if (Object.keys(changeOf(entry, text)).length === 0) continue;
    b.proposed.set(text.reference, { said, made: one.made, text });
    changed += 1;
  }
  if (changed === 0) announce(wording("card-tools-no-changes"));
  drawBar(b);
  b.redraw();
}

/** Keeps the change waiting for the entry `reference`. */
async function keep(b: Book, reference: string): Promise<void> {
  const proposal = b.proposed.get(reference);
  const entry = b.book?.entries.find((one) => one.reference === reference);
  b.proposed.delete(reference);
  if (proposal && entry) await saveEntry(b, reference, changeOf(entry, proposal.text), proposal.made);
}

/** The bar over the entry: how many changes wait, with Keep all and Undo all; hidden while none do. */
export function drawBar(b: Book): void {
  const waiting = b.proposed.size;
  b.bar.hidden = waiting === 0;
  if (waiting === 0) return void b.bar.replaceChildren();
  const keepAll = () =>
    void b.attempt(async () => {
      try {
        for (const reference of [...b.proposed.keys()]) await keep(b, reference);
      } finally {
        drawBar(b);
        b.redraw();
      }
    });
  const undoAll = () => {
    b.proposed.clear();
    drawBar(b);
    b.redraw();
  };
  b.bar.replaceChildren(...changesBar(wording("lore-tools-entries-changed-by-ai", { count: waiting }), keepAll, undoAll));
}

/** The change waiting for `entry`, against it as it is, with Keep and Undo; none where none waits. */
export function proposalBox(b: Book, entry: EditEntry): HTMLElement | null {
  const proposal = b.proposed.get(entry.reference);
  if (!proposal) return null;
  const change = changeOf(entry, proposal.text);
  const done = () => {
    drawBar(b);
    b.redraw();
  };
  const keepOne = el("button", { type: "button", className: "btn btn-primary" }, wording("card-block-keep"));
  keepOne.onclick = () => void b.attempt(() => keep(b, entry.reference).finally(done));
  const undo = el("button", { type: "button", className: "btn btn-secondary", onclick: () => (b.proposed.delete(entry.reference), done()) }, wording("card-block-undo"));
  return el(
    "section",
    { className: "lore-change flex f-col g-4", ariaLabel: wording("lore-tools-ai-change") },
    change.content !== undefined && el("div", { className: "md changes" }, el("p", null, ...marked(entry.content, change.content).words)),
    change.keywords && el("p", null, el("span", { className: "label" }, wording("lore-tools-keywords")), ...marked(entry.keywords.join(comma()), change.keywords.join(comma())).words),
    change.secondary && el("p", null, el("span", { className: "label" }, wording("lore-tools-secondary-keywords")), ...marked(entry.secondary.join(comma()), change.secondary.join(comma())).words),
    el("div", { className: "tb-foot" }, el("span", { className: "meta" }, proposal.said), keepOne, undo),
  );
}
