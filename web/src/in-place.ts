// A part of a page written where it stands (`inPlace`): a click or the focus shows a field in its place with what
// it holds, and leaving the field saves. A text being written that is not saved yet is kept as the field's unsaved
// text (`InPlace.keep`, unsaved.ts) and comes back when it is written in again.
import { atMost, el } from "./dom";
import { forget, keep, kept } from "./unsaved";

/** What a field being written in place is told. */
export interface InPlace {
  /** What the field is called, for who cannot see it. */
  label: string;
  /** What it holds as saved, or as waiting to be. */
  value(): string;
  /** What it shows while not written in. */
  show(): (Node | string)[];
  /** Told what was written, where it differs from `value`; may answer, once tried, whether it was saved. */
  commit(text: string): void | Promise<boolean>;
  multiline?: boolean;
  placeholder?: string;
  /** How many signs it takes at most. */
  limit?: number;
  /** Told every letter typed. */
  input?(text: string): void;
  /** Told when it is begun and ended. */
  editing?(on: boolean): void;
  /** Whether it cannot be written in now. */
  blocked?(): boolean;
  /** The name what is written and not saved yet is kept by (unsaved.ts), to come back when it is written in again. */
  keep?(): string | null;
}

/**
 * Makes `node` a thing written where it stands: a click or the focus shows a field in its place with what it
 * holds, and leaving the field saves what was written (Enter too, in a line; Escape in a line takes it back).
 * Answers what begins the writing.
 */
export function inPlace(node: HTMLElement, place: InPlace): () => void {
  let field: HTMLInputElement | HTMLTextAreaElement | null = null;
  const read = () => {
    field = null;
    node.tabIndex = 0;
    node.replaceChildren(...place.show());
  };
  const begin = () => {
    if (field || place.blocked?.()) return;
    const now = place.multiline ? el("textarea", { className: "in-place", rows: 1 }) : el("input", { className: "in-place", autocomplete: "off" });
    field = now;
    now.value = place.value();
    const key = place.keep?.() ?? null;
    now.ariaLabel = place.label;
    if (place.placeholder) now.placeholder = place.placeholder;
    // Counted as signs, as the server counts them, where `maxLength` counts a 🌊 twice.
    if (place.limit) atMost(now, place.limit);
    // A text grows with its words.
    const grow = () => {
      if (now instanceof HTMLTextAreaElement) {
        now.style.height = "auto";
        now.style.height = `${now.scrollHeight}px`;
      }
    };
    now.oninput = () => {
      grow();
      place.input?.(now.value);
      if (key) keep(key, now.value === place.value() ? "" : now.value);
    };
    now.onkeydown = (event) => {
      if (event.key === "Escape" && !place.multiline) now.value = place.value();
      if (event.key === "Escape" || (event.key === "Enter" && !place.multiline)) {
        event.preventDefault();
        now.blur();
      }
    };
    now.onblur = () => {
      const text = now.value;
      place.editing?.(false);
      // Unsaved words are let go once saved: a save that fails leaves them to come back.
      if (text.trim() !== place.value().trim()) {
        const saved = Promise.resolve(place.commit(text));
        if (key) void saved.then((done) => done !== false && forget(key));
      } else if (key) forget(key);
      read();
    };
    node.tabIndex = -1;
    node.replaceChildren(now);
    place.editing?.(true);
    grow();
    now.focus();
    // What was written here and not saved comes back, unless something is typed meanwhile.
    if (key) {
      const shown = now.value;
      void kept(key).then((text) => {
        if (text === null || field !== now || now.value !== shown) return;
        now.value = text;
        grow();
        // Told as typed, so what waits on typing (a new card's New chat) is ready.
        place.input?.(text);
      });
    }
  };
  node.addEventListener("focus", begin);
  node.addEventListener("click", begin);
  read();
  return begin;
}
