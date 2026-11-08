// A part of a tab's screen found again in the screen made anew (`keyOf`, `partOf`: its tag, first class and which
// of those it is), and what the user typed into its fields kept across that (`typedIn`, `putTyped`): the tabs make
// every screen anew when the language changes (tabs.ts `relanguage`). Only a field the user typed into is kept,
// marked as the document hears its `input` (`watchTyping`), so what a screen fills in itself is its own again.
// Traps: a screen made anew draws its fields, and fills them, as the server's answers come, so the text is put
// back each frame for a while (`PUT_BACK_MS`) wherever the field holds another, until the user types in it; it is
// put back with an `input` event, so the screen counts it as typed (unsaved) as before.

/** How long a screen made anew has its scroll and typed text put back while it is drawn, in milliseconds. */
export const PUT_BACK_MS = 2500;

/** A field's typed text by its key (`keyOf`); the one that had the focus. */
export interface Typed {
  fields: [key: string, value: string][];
  focus: string | null;
}

/** The fields the user typed into. */
const touched = new WeakSet<Element>();
let watching = false;

/** Marks each field the user types into, from now on (once). */
export function watchTyping(): void {
  if (watching) return;
  watching = true;
  document.addEventListener("input", (event) => event.target instanceof Element && touched.add(event.target), true);
}

/** What finds a part of a page again in the page made anew: its tag and first class, and which of those it is. */
export function keyOf(node: HTMLElement, part: Element): string {
  if (part === node) return "";
  const like = part.tagName.toLowerCase() + (part.classList[0] ? `.${part.classList[0]}` : "");
  return `${like}@${[...node.querySelectorAll(like)].indexOf(part)}`;
}

/** The part of `node` that `key` names, where there is one yet. */
export function partOf(node: HTMLElement, key: string): Element | null {
  if (!key) return node;
  const at = key.lastIndexOf("@");
  return node.querySelectorAll(key.slice(0, at))[Number(key.slice(at + 1))] ?? null;
}

const isField = (part: Element): part is HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement =>
  part instanceof HTMLInputElement || part instanceof HTMLTextAreaElement || part instanceof HTMLSelectElement;

/** What the user typed in `node`'s fields, and which had the focus. */
export function typedIn(node: HTMLElement): Typed {
  const fields = [...node.querySelectorAll("input, textarea, select")].filter((part) => touched.has(part) && isField(part));
  const focused = document.activeElement && node.contains(document.activeElement) ? keyOf(node, document.activeElement) : null;
  return { fields: fields.map((part) => [keyOf(node, part), (part as HTMLInputElement).value]), focus: focused };
}

/** Puts `typed` back into `node`'s fields as they are drawn and filled, every frame for `PUT_BACK_MS`, but into a field the user has typed in since; the focus too. */
export function putTyped(node: HTMLElement, typed: Typed): void {
  let focus = typed.focus;
  const end = Date.now() + PUT_BACK_MS;
  // The fields the user typed in after the screen was made: an `input` not sent by `frame`.
  const typedSince = new WeakSet<Element>();
  let putting = false;
  const heard = (event: Event) => !putting && event.target instanceof Element && typedSince.add(event.target);
  node.addEventListener("input", heard, true);
  const frame = () => {
    for (const [key, value] of typed.fields) {
      const part = partOf(node, key);
      if (!part || !isField(part) || typedSince.has(part) || part.value === value) continue;
      part.value = value;
      touched.add(part);
      putting = true;
      part.dispatchEvent(new Event("input", { bubbles: true }));
      putting = false;
    }
    const focused = focus === null ? null : partOf(node, focus);
    if (focused instanceof HTMLElement && node.isConnected) {
      focused.focus();
      focus = null;
    }
    if ((typed.fields.length || focus !== null) && Date.now() < end) requestAnimationFrame(frame);
    else node.removeEventListener("input", heard, true);
  };
  frame();
}
