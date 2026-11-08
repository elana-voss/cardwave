// What a lorebook's editor (views/lorebook.ts) decides about an entry, without its screen: `entryOf`, the entry an address names (its reference, as one part of the address, or
// `NEW` for one that is being written); `said`, what a line of the list says under an entry's name;
// `matches`, which entries a search leaves; and `keys`, a field of keywords as pills: Enter adds what is typed,
// as does leaving the field, a word that is there already is not added again, and the × of a pill and
// Backspace in the empty field take one away; each change is told (`changed`), which saves it.
import type { EditEntry } from "../api/generated/EditEntry";
import { el } from "../dom";
import { icon } from "../icons";
import { wording } from "../language/language";
import { comma } from "../format";

/** What stands in the address for an entry that is being written: no entry's reference, which has a dot. */
export const NEW = "new";

/** The entry the address `hash` names: its reference, `NEW`, or none. */
export function entryOf(hash: string): string | null {
  const part = hash.split("/")[4];
  if (!part) return null;
  try {
    return decodeURIComponent(part);
  } catch {
    return part;
  }
}

/** What a line of the list says under an entry's name: what the entry is used by, its keywords named as such. */
export function said(entry: EditEntry): string {
  if (entry.trigger === "always") return wording("lorebook-entry-always");
  if (entry.trigger === "vector") return wording("lorebook-entry-by-meaning");
  return entry.keywords.length ? wording("lorebook-entry-keywords-said", { keywords: entry.keywords.join(comma()) }) : wording("entry-no-keywords");
}

/** Whether an entry has every word of `query` in its name or its keywords, in any case. */
export function matches(entry: EditEntry, query: string): boolean {
  const text = [entry.label, ...entry.keywords].join("\n").toLowerCase();
  return query.toLowerCase().split(/\s+/).every((word) => text.includes(word));
}

/** How many fields of keywords were made: each has a number of its own for its name to point at. */
let made = 0;

/**
 * A field of keywords, each a pill with the × that takes it away, and behind
 * them the place to type the next: Enter adds it, and so does leaving the
 * field. Backspace in the empty
 * place takes the last away. `list` is changed in place, and `changed` told.
 * `under` stands under the field: what goes with the keywords, and what is to
 * be said of them.
 */
export function keys(name: string, placeholder: string, list: string[], changed: () => void, ...under: HTMLElement[]): HTMLElement {
  const input = el("input", { id: `keys-${++made}`, className: "field f-grow", placeholder });
  const box = el("div", { className: "field keys pills ai-c" }, input);
  const pill = (key: string) => {
    const node = el("span", { className: "key pill on-box iflex ai-c g-6" }, key);
    const off = el("button", { type: "button", className: "key-off", ariaLabel: wording("entry-remove", { key }), title: wording("mcp-remove") }, icon("close", 12));
    off.onclick = () => {
      list.splice(list.indexOf(key), 1);
      node.remove();
      changed();
      input.focus();
    };
    node.append(off);
    return node;
  };
  const take = () => {
    const key = input.value.trim();
    input.value = "";
    if (!key || list.includes(key)) return;
    list.push(key);
    input.before(pill(key));
    changed();
  };
  input.onkeydown = (event) => {
    // Not the Enter that ends a word an input method is putting together.
    if (event.isComposing) return;
    if (event.key === "Enter" && input.value.trim()) {
      // The word is taken; the form is not saved by this Enter.
      event.preventDefault();
      take();
    } else if (event.key === "Backspace" && !input.value && list.length) {
      list.pop();
      input.previousElementSibling?.remove();
      changed();
    }
  };
  input.onblur = take;
  // A press on the field beside its pills is one on the place to type.
  box.onclick = (event) => event.target === box && input.focus();
  for (const key of list) input.before(pill(key));
  return el("div", { className: "fld" }, el("label", { className: "label", htmlFor: input.id }, name), box, ...under);
}
