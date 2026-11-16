// What the browser keeps and saves: `remember` and `remembered`, a choice kept for the next start; `keepOverReload`
// and `takeKept`, a note kept for this tab's next load; `save` and `saveFrom`, a file handed to the browser to save, which in the desktop app's window say the folder it went into.
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

/** Keeps a note for this tab's next load, read once by [`takeKept`]; nothing kept where the browser refuses. */
export function keepOverReload(key: string, value: string): void {
  try {
    sessionStorage.setItem(key, value);
  } catch {
    // Not kept, then: the next load says nothing.
  }
}

/** The note [`keepOverReload`] kept under `key`, removed as it is read; `null` when none or the browser keeps nothing. */
export function takeKept(key: string): string | null {
  try {
    const value = sessionStorage.getItem(key);
    sessionStorage.removeItem(key);
    return value;
  } catch {
    return null;
  }
}
