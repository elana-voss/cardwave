// What Search Cardwave shows of a hit (search-panel.ts draws it): the page each one opens (`addressOf`) and what of
// that page is shown when it is there (`revealOf`: a persona's, a memory's or a document's row, a setting's line),
// its round's drawing, and the groups in their order (`grouped`). The app's own pages and the settings on them are
// found here, by their names and labels (`pageHits`), as the server does not know them: the pages of pages.ts that
// have a place, and the settings' labels of setting-labels.ts, with those the caller adds (the voices). Words are
// matched as the server does (crates/cw-find/src/lib.rs): every word, in any order, in any case.
import type { Hit } from "../api/generated/Hit";
import type { HitKind } from "../api/generated/HitKind";
import { chatName } from "../chat-title";
import { knownLine } from "../memory-known";
import { ago } from "../format";
import type { IconName } from "../icons";
import { PAGES, type Page } from "./pages";
import { onPage } from "../setting-labels";
import { wording } from "../language/language";

/** A hit as the panel shows it: the kinds of the server's and the app's pages. */
export interface Shown {
  kind: HitKind | "page";
  name: string;
  line: string;
  address: string;
  /** A row's title or a setting's label on the page, scrolled to once it is there. */
  reveal: string | null;
  picture: number | null;
  shape: IconName;
}

/** The groups in their order, each with its heading. */
export const groups = (): [Shown["kind"], string][] => ([
  ["character", wording("page-characters")],
  ["lorebook", wording("page-lorebooks")],
  ["chat", wording("page-chats")],
  ["persona", wording("page-personas")],
  ["memory", wording("page-memories")],
  ["document", wording("page-documents")],
  ["page", wording("find-pages")],
]);

const SHAPES: Record<Shown["kind"], IconName> = {
  character: "person",
  lorebook: "lorebook",
  chat: "chat",
  persona: "persona",
  memory: "knowledge",
  document: "document",
  page: "gear",
};

/** Every page of the app a search finds, its name with the place it is under, and the grey line under it (where it is), in the language in use. */
const found = () => PAGES.filter((page): page is Page & { address: string; under: string } => page.address !== null && page.under !== null).map(({ address, name, under, shape }) => ({
  address,
  name: under ? `${under} › ${name}` : name,
  line: under ? under.split(" › ")[0] : wording("find-page"),
  shape,
}));

/** A text folded for matching: each character as its first lower case one, so places stay as they were. */
const fold = (text: string) => [...text].map((c) => [...c.toLowerCase()][0] ?? c).join("");

/** The most words of a search that count, as the server counts them (`MAX_WORDS`). */
const MAX_WORDS = 8;

/** The words of a search, folded, the first `MAX_WORDS`; empty where it has none. */
export const wordsOf = (query: string) => fold(query).split(/\s+/).filter(Boolean).slice(0, MAX_WORDS);

/** Whether `text` holds every one of `words`. */
const holds = (text: string, words: string[]) => words.length > 0 && words.every((word) => fold(text).includes(word));

/** The pages whose names hold every word of `query`, then the settings whose labels do; `more` the labels the server told, by page. */
export function pageHits(query: string, more: Record<string, string[]> = {}): Shown[] {
  const words = wordsOf(query);
  const pages = found().filter(({ name }) => holds(name, words)).map(({ address, name, line, shape }): Shown => ({ kind: "page", name, line, address, reveal: null, picture: null, shape }));
  const settings = found().flatMap(({ address, name, shape }) =>
    [...(onPage()[address] ?? []), ...(more[address] ?? [])].filter((label) => holds(label, words)).map((label): Shown => ({ kind: "page", name: label, line: name, address, reveal: label, picture: null, shape })),
  );
  return [...pages, ...settings];
}

/** The page a hit of the server's opens: a lorebook on its entry, a card's own in the card. */
export function addressOf(hit: Hit): string {
  const entry = hit.part ? `/${encodeURIComponent(hit.part)}` : "";
  switch (hit.kind) {
    case "character":
      return `#/library/${hit.id}`;
    case "lorebook":
      if (hit.book === null) return `#/library/lorebooks/${hit.id}${entry}`;
      return `#/library/${hit.id}/${hit.book ? encodeURIComponent(hit.book) : "lorebook"}${entry}`;
    case "chat":
      return `#/chats/${hit.id}`;
    case "persona":
      return "#/library/personas";
    case "memory":
      return "#/knowledge/memories";
    case "document":
      return "#/knowledge/documents";
  }
}

/** A hit of the server's as the panel shows it: a chat called as among the latest chats, its line how long ago it was written in, as the list of chats says. */
export function shown(hit: Hit): Shown {
  const chat = hit.kind === "chat";
  const listed = hit.kind === "persona" || hit.kind === "memory" || hit.kind === "document";
  return {
    kind: hit.kind,
    name: chat ? chatName({ names: hit.names, title: hit.name }) : hit.name,
    line: chat && hit.when !== null ? ago(hit.when) : hit.known ? knownLine(hit.known) : hit.line,
    address: addressOf(hit),
    reveal: listed ? hit.name : null,
    picture: hit.picture,
    shape: SHAPES[hit.kind],
  };
}

/** The hits by group, in the groups' order, each group's hits as they came; a group only where it has hits. */
export function grouped(hits: Shown[]): [string, Shown[]][] {
  return groups().map(([kind, heading]): [string, Shown[]] => [heading, hits.filter((hit) => hit.kind === kind)]).filter(([, hits]) => hits.length > 0);
}
