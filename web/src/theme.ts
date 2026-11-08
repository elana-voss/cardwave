// How the app looks by the user's choice, which is kept in the browser for the
// next start: the theme (the system's, light, dark, or one of the five looks of app/looks.css, each its own colour
// scheme; Cyberpunk is left out, the owner, 2026-11-06), the chat's layout (bubbles or plain) and Compact (every size about a fifth smaller).
// The title bar's view menu (view-menu.ts) and Settings › Appearance set the same choices; each choice tells the
// page by the event `LOOK` on the document, so what shows a choice is drawn anew.
//
// `theme`, `setTheme` and `themes` (their words in the language in use) are the theme; index.html sets it and Compact before the page is drawn, under
// the same names. `chatLayout`, `setChatLayout`, `showChatLayout` and `chatLayouts` are the chat's layout,
// which the root says as `data-chat` and styles.css draws a chat's messages by; main.ts has it shown at the
// start.
import type { PageViews } from "./dom";
import { remember, remembered } from "./storage";
import { wording } from "./language/language";

/** The event on the document that tells of a choice of the look. */
export const LOOK = "look";
const told = () => document.dispatchEvent(new Event(LOOK));

/** System, light, dark and the five looks (app/looks.css): the source tools/looks.py writes those and public/early.js's list from. */
export type Theme = "system" | "light" | "dark" | "downtempo" | "outrun" | "retrowave" | "neonwave-dark" | "neonwave-light";

/** The themes to choose from, each with its words in the language in use. */
export const themes = (): [Theme, string][] => [
  ["system", wording("theme-system")],
  ["light", wording("theme-light")],
  ["dark", wording("theme-dark")],
  ["downtempo", wording("theme-downtempo")],
  ["outrun", wording("theme-outrun")],
  ["retrowave", wording("theme-retrowave")],
  ["neonwave-dark", wording("theme-neonwave-dark")],
  ["neonwave-light", wording("theme-neonwave-light")],
];

/** The choice is kept under this name. index.html reads it too, to set the theme before the page is drawn. */
const THEME = "theme";

/** The theme chosen; the system's while none was. */
export const theme = (): Theme => themes().find(([name]) => name === remembered(THEME))?.[0] ?? "system";

/** Sets the theme at once and keeps the choice. The root's `data-theme` names it; without it the system's light or dark counts. */
export function setTheme(to: Theme): void {
  remember(THEME, to);
  if (to === "system") delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = to;
  told();
}

/** How a chat draws its messages: each a bubble, the user's at the right, or each as text under its name. */
export type ChatLayout = "bubbles" | "plain";

export const chatLayouts = (): [ChatLayout, string][] => [
  ["bubbles", wording("layout-bubbles")],
  ["plain", wording("layout-plain")],
];

/** The layout is kept under this name. */
const CHAT_LAYOUT = "chat-layout";

/** The chat's layout chosen; bubbles while none was. */
export const chatLayout = (): ChatLayout => chatLayouts().find(([name]) => name === remembered(CHAT_LAYOUT))?.[0] ?? "bubbles";

/** Has the page draw chats in the layout `to`: the root's `data-chat` says which. */
export function showChatLayout(to: ChatLayout = chatLayout()): void {
  document.documentElement.dataset.chat = to;
}

/** Sets the chat's layout at once and keeps the choice. */
export function setChatLayout(to: ChatLayout): void {
  remember(CHAT_LAYOUT, to);
  showChatLayout(to);
  told();
}

/** A chat's views in the view menu: its layouts, the same choice as Settings' Chat layout. */
export const CHAT_VIEWS: PageViews = { get list() {
    return chatLayouts();
  }, now: () => chatLayout(), choose: (to) => setChatLayout(to as ChatLayout) };

/** Compact is kept under this name. index.html reads it too, to set it before the page is drawn. */
const DENSITY = "density";

/** Whether Compact is on; off while it was never chosen. */
export const compact = (): boolean => remembered(DENSITY) === "compact";

/** Turns Compact on or off at once and keeps the choice: the root's `data-density="compact"`, whose sizes cardwave.css has. */
export function setCompact(on: boolean): void {
  remember(DENSITY, on ? "compact" : "regular");
  if (on) document.documentElement.dataset.density = "compact";
  else delete document.documentElement.dataset.density;
  told();
}
