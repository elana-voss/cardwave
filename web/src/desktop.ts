// What the page asks of the desktop app's program (desktop/src/main.rs), where it is in one of its windows: the
// companion window opened, closed or started with the app, the app's window shown at an address, whether the
// cursor is on what the companion window shows, the window's buttons and its move for the title bar the page
// draws (titlebar.ts), the system's folder picker (`pickFolder`), the logs' folder opened (`open_logs`), a page of the app in a window of its own (`openPage`) and
// the app's updates (settings/update.ts); `appWindow` tells its own window from its window of one page. A
// browser has no such program: there it asks nothing, and `openPage` opens a tab.
//
// Traps: the program answers only the pages of its own server, by a capability it gives that address when it
// starts (main.rs, `allow_pages`); a command it does not know, or one it refuses, rejects, which no screen waits on.
import { onLanguage } from "./language/language";

declare global {
  interface Window {
    __TAURI_INTERNALS__?: { invoke(command: string, args?: Record<string, unknown>): Promise<unknown> };
    /** What the desktop app tells the page in its window: the folder that window saves files into (null where the system names none), the logs' folder, and which of its windows it is. */
    cardwaveDesktop?: { downloads: string | null; logs: string; window?: string };
  }
}

/** What the desktop app calls its window of one page of the app (`openPage`). */
export const PAGE_WINDOW = "page";

/** Whether the page is in a window of the desktop app. */
export const inDesktop = () => window.cardwaveDesktop !== undefined;

/** Whether the page is the desktop app's own window, the one the companion is told of: not a browser, not its window of one page. */
export const appWindow = () => inDesktop() && window.cardwaveDesktop?.window !== PAGE_WINDOW;

/** Names the page's window by `word`, in the page's language: now, and anew when the language changes. */
export function nameWindow(word: () => string): void {
  const name = () => {
    document.title = word();
    void desktop("window_title", { title: document.title }).catch(() => {}); // a browser's tab is named by the title alone
  };
  name();
  onLanguage(name);
}

/** Asks the desktop app's program to do `command`; in a browser nothing is asked. */
export function desktop(
  command: "companion_open" | "companion_start" | "companion_quit" | "companion_over" | "open_main" | "window_minimize" | "window_maximize" | "window_close" | "window_drag" | "window_title" | "pick_folder" | "open_logs" | "open_page" | "update_check" | "update_install",
  args: Record<string, unknown> = {},
): Promise<unknown> {
  return window.__TAURI_INTERNALS__?.invoke(command, args) ?? Promise.resolve();
}

/** The system's folder picker, opened at `start`: the folder chosen, or nothing where it was cancelled. */
export const pickFolder = (start: string) => desktop("pick_folder", { start }) as Promise<string | null>;

/** Shows the app's page at `hash` in a window of its own beside the app's: in the desktop app its own, in a browser a new tab. */
export function openPage(hash: string): void {
  if (inDesktop()) void desktop("open_page", { hash }).catch(() => {});
  else window.open(`/${hash}`, "_blank", "noopener");
}
