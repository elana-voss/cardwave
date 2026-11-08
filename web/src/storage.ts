// What the browser keeps and saves: `remember` and `remembered`, a choice kept for the next start, and `save` and
// `saveFrom`, a file handed to the browser to save, which in the desktop app's window say the folder it went into.
import { el } from "./dom";

/**
 * Hands the browser a file to save under `name`. Returns the folder it goes
 * into, in the desktop app's window; a browser has its own and does not say.
 */
export function save(name: string, file: Blob): string | null {
  const url = URL.createObjectURL(file);
  saveFrom(url, name);
  // The download holds the file by now; a browser that reads it late still finds the address.
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return window.cardwaveDesktop?.downloads ?? null;
}

/**
 * Has the browser save what the server answers at `url`, as it comes, under the name the server gives it (or
 * `name`), without holding it in the page. Returns the folder as `save` does.
 */
export function saveFrom(url: string, name = ""): string | null {
  el("a", { href: url, download: name }).click();
  return window.cardwaveDesktop?.downloads ?? null;
}

/** A choice kept in the browser for the next start; `null` when none was made or the browser keeps nothing (private mode). */
export function remembered(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

/** Keeps a choice for [`remembered`]. */
export function remember(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Not kept, then.
  }
}
