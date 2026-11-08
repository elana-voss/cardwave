// What a form that edits is built of, a lorebook entry's (lorebook-entry.ts) and a prompt preset's
// (views/prompt-preset.ts): `field`, a control under its name (`.fld > .field-head`), with its tools beside the
// name and what is to be said of it under it; `line`, a field of one line; and `count`, a field for a whole
// number, which keeps no wrong number and shows one as Advanced does: red, its range in red under it in the
// hint's place, never the browser's message (A17).
import { el } from "./dom";
import { wording } from "./language/language";

/** How many fields were made: each has a number of its own for its name to point at. */
let fields = 0;

/** A field under its name, with what can be done with it beside the name, and what is to be said of it under it. */
export function field(name: string, control: HTMLInputElement | HTMLTextAreaElement, tools: HTMLElement[] = [], hint?: string): HTMLElement {
  control.id = `edit-${++fields}`;
  const said = hint ? el("p", { className: "hint", id: `${control.id}-hint` }, hint) : null;
  if (said) control.setAttribute("aria-describedby", said.id);
  return el("div", { className: "fld g-4" }, el("div", { className: "field-head flex ai-c jc-sb" }, el("label", { className: "label", htmlFor: control.id }, name), ...tools), control, said);
}

/** A field of one line that tells `set` what is typed. */
export function line(value: string, set: (value: string) => void, required = false): HTMLInputElement {
  const node = el("input", { className: "field", value, required });
  node.oninput = () => set(node.value);
  return node;
}

/**
 * A field for a whole number between `least` and `most`, which tells `set`
 * one that is typed. Emptied, it tells `empty`; where there is none, a number
 * has to stand in it. A wrong number (beyond them, not whole) it does not
 * tell, so what the form keeps never holds one, also where it is not in view. A wrong one, once left (or where
 * the form is sent), is red with its range in the field's hint (`.wrong`); the browser's message is held back.
 */
export function count(value: number | null, set: (value: number) => void, { least, most, empty }: { least?: number; most?: number; empty?: number }): HTMLInputElement {
  const node = el("input", { className: "field", type: "number", step: "1", value: value === null ? "" : String(value), required: empty === undefined });
  if (least !== undefined) node.min = String(least);
  if (most !== undefined) node.max = String(most);
  node.oninput = () => {
    if (node.value === "" && empty !== undefined) set(empty);
    else if (Number.isInteger(node.valueAsNumber) && !node.validity.rangeUnderflow && !node.validity.rangeOverflow) set(node.valueAsNumber);
    if (node.classList.contains("wrong")) mark();
  };
  const range = least !== undefined && most !== undefined ? wording("edit-form-from-to", { least, most }) : least !== undefined ? wording("edit-form-a-whole-number-from", { least }) : wording("advanced-whole");
  /** The hint's own words, while it says the range. */
  let hint: string | null = null;
  // `validity`, not `checkValidity()`, which would fire `invalid` again.
  const mark = () => {
    const wrong = !node.validity.valid || (node.value !== "" && !Number.isInteger(node.valueAsNumber));
    node.classList.toggle("wrong", wrong);
    node.ariaInvalid = String(wrong);
    const said = node.closest(".fld")?.querySelector<HTMLElement>(":scope > p.hint");
    if (!said) return;
    hint ??= said.textContent;
    said.textContent = wrong ? range : hint;
  };
  node.addEventListener("change", mark);
  // Where a form is sent with it wrong, the field says so and takes the focus, in the browser's message's place.
  node.addEventListener("invalid", (event) => {
    event.preventDefault();
    mark();
    node.focus();
  });
  return node;
}
