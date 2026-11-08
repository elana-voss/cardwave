// The app's pages, once: each one's address, the start of the addresses that are its (`match`, the address itself
// where none is given), its name, the place it is under (`under`: "" for a page of its own, none for one Search
// Cardwave does not find, as a chat or a card) and its drawing. Search Cardwave finds those with a place, in this
// order (find.ts), a tab is named after the page whose start matches longest (`pageAt`, tabs.ts), and the rail's
// lines and the account's menu are drawn from them (`page`, rail.ts). main.ts makes each page's screen. A name and
// a place are read anew each time, in the language in use (language.ts).
import type { IconName } from "../icons";
import { wording } from "../language/language";

export interface Page {
  /** Where it is opened; none for a page that is one of many (a chat, a card). */
  address: string | null;
  match: RegExp;
  name: string;
  /** The place it is under, which Search Cardwave shows before its name; "" for a page of its own, none where it is not found. */
  under: string | null;
  shape: IconName;
}

/** The start of the addresses that are `address`'s. */
const startOf = (address: string) => new RegExp(`^${address.replace(/[/]/g, "\\/")}`);
/** A page Search Cardwave finds, at its address; its name and place read in the language in use. */
const at = (address: string, name: () => string, under: () => string, shape: IconName, match = startOf(address)): Page => ({
  address,
  match,
  get name() {
    return name();
  },
  get under() {
    return under();
  },
  shape,
});
/** A page that is one of many, found by its start alone. */
const one = (match: RegExp, name: () => string, shape: IconName): Page => ({
  address: null,
  match,
  get name() {
    return name();
  },
  under: null,
  shape,
});
const own = () => "";
const library = () => wording("place-library");
const knowledge = () => wording("place-knowledge");
const account = () => wording("place-account");
const settings = () => wording("place-settings");

export const PAGES: Page[] = [
  at("#/chats", () => wording("page-chats"), own, "chat"),
  at("#/library", () => wording("page-characters"), library, "person"),
  at("#/library/lorebooks", () => wording("page-lorebooks"), library, "lorebook"),
  at("#/library/personas", () => wording("page-personas"), library, "persona"),
  at("#/knowledge/memories", () => wording("page-memories"), knowledge, "knowledge", /^#\/knowledge/),
  at("#/knowledge/documents", () => wording("page-documents"), knowledge, "document"),
  at("#/generator", () => wording("page-generator"), own, "generator"),
  at("#/interview", () => wording("page-interview"), own, "interview"),
  at("#/account/profile", () => wording("page-profile"), account, "person", /^#\/account/),
  at("#/account/server", () => wording("page-server"), account, "server"),
  at("#/settings", () => wording("page-settings"), own, "gear"),
  at("#/settings/providers", () => wording("page-providers"), settings, "gear"),
  at("#/settings/voices", () => wording("page-voices"), settings, "gear"),
  at("#/settings/advanced", () => wording("page-advanced"), settings, "gear"),
  at("#/settings/advanced/css", () => wording("page-css"), () => wording("place-advanced"), "gear"),
  at("#/settings/tools/written", () => wording("page-written-tools"), settings, "gear"),
  at("#/settings/tools/coding", () => wording("page-coding-team"), settings, "gear"),
  at("#/settings/trash", () => wording("page-trash"), settings, "gear"),
  at("#/settings/about", () => wording("page-about"), settings, "info"),
  one(/^#\/chats\/\d+\/tasks\//, () => wording("page-coding-task"), "code"),
  one(/^#\/chats\/\d+/, () => wording("page-chat"), "chat"),
  one(/^#\/library\/new/, () => wording("page-new-card"), "edit"),
  one(/^#\/library\/lorebooks\/\d+/, () => wording("page-lorebook"), "lorebook"),
  one(/^#\/library\/\d+\/lorebook/, () => wording("page-lorebook"), "lorebook"),
  one(/^#\/library\/\d+/, () => wording("page-card"), "person"),
  one(/^#\/settings\/advanced\/prompts/, () => wording("page-prompt-preset"), "gear"),
  one(/^#\/setup/, () => wording("page-first-run"), "gear"),
];

/** The page at `address`, by the start that matches longest; the list of chats for what the app does not know, as main.ts shows it. */
export function pageAt(address: string): Page {
  let best = PAGES[0];
  let longest = -1;
  for (const page of PAGES) {
    const length = address.match(page.match)?.[0].length ?? -1;
    if (length > longest) [best, longest] = [page, length];
  }
  return best;
}

/** The page whose address is `address`, which is one of the list's. */
export const page = (address: string): Page => PAGES.find((one) => one.address === address)!;
