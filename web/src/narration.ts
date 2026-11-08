// Narration in a text of a chat: what stands between two asterisks is told, drawn in italics without them;
// speech stays upright. `paragraphs` parts a text at its empty lines (a card's texts too); `pieces` reads a
// paragraph as speech and narration; `narrated` makes the paragraphs a message shows, a `p` each, a blank line
// as text between two, so `textContent` is the text written less the asterisks and the marks of links.
// Two asterisks side by side (bold), one alone ("2 * 3") or inside a word ("2*3*4") begin no narration. In a
// text still being written (`open`) the narration begun last runs to its end.
// In a message, Markdown's links and an address alone open in the browser, and Markdown's pictures show
// (`linked`); another kind of address than http(s) stays text (data: only for a picture). A picture from
// another address than Cardwave's own (this page's origin, or data:) shows only while Settings' "Pictures from
// the web" is on (`webPictures`, which `readWebPictures` reads from the settings for the chat and the companion): else its place says
// why, with a button that switches it on and shows every picture so held back on the page. The page's
// Content-Security-Policy lets them load only where the switch was on as the page was loaded, which the first value
// read on the page stands for (`atLoad`, read at start by main.ts and the companion's): switched on later, the page
// loads again (once under Vite's dev server, which sends no policy).
import { changeSettings, getSettings } from "./api/client";
import { el, failure, reason } from "./dom";
import { wording } from "./language/language";

let fromWeb = false;
/** The switch as first read on this page, which the server's policy for the page followed as it was loaded. */
let atLoad: boolean | undefined;
/**
 * Settings' "Show pictures from other websites", as the server holds it, for every message drawn after; answers whether
 * it changed. Switched on where the page's policy holds them back, the page loads again.
 */
export function webPictures(on: boolean): boolean {
  const changed = on !== fromWeb;
  fromWeb = on;
  atLoad ??= on;
  if (on && !atLoad) location.reload();
  return changed;
}

/**
 * Reads Settings' "Show pictures from other websites" for the messages drawn after, and answers whether it changed; where it
 * cannot be read it stays as it was (held back at first).
 */
export const readWebPictures = () => getSettings().then(({ web_pictures }) => webPictures(web_pictures), () => false);

/** A stretch of a paragraph: speech as it is written, or narration, without its asterisks. */
export interface Piece {
  text: string;
  told: boolean;
}

/**
 * Narration: an asterisk that stands alone and not behind a letter or a digit, words that begin and end without a
 * space, and the next asterisk that stands alone and not before a letter or a digit.
 */
const TOLD = /(?<![\p{L}\p{N}*])\*(?![\s*])([^*]*?)(?<![\s*])\*(?![\p{L}\p{N}*])/gu;
/** Narration that is begun and has no end yet: the last asterisk, with words right behind it or none so far. */
const BEGUN = /(?<![\p{L}\p{N}*])\*(?![\s*])([^*]*)$/u;

/** A Markdown picture, a Markdown link, or an address alone, of which a sign that ends a sentence is not part. */
const LINKED = /!\[([^\]]*)\]\(([^)\s]+)\)|\[([^\]]+)\]\(([^)\s]+)\)|(https?:\/\/[^\s<>"]*[^\s<>".,;:!?)\]'])/g;

/** Whether `url` may be a link: one to a web page. */
const isWeb = (url: string) => /^https?:\/\//i.test(url);

/** A link that opens in the browser, beside the app (the desktop app hands it to the system's browser). */
const link = (url: string, words: string) => el("a", { href: url, target: "_blank", rel: "noopener noreferrer" }, words);

/** Whether a picture's address is Cardwave's own: one in the message itself, or this page's server. */
function isOwn(url: string): boolean {
  if (/^data:image\//i.test(url)) return true;
  try {
    return new URL(url).origin === location.origin;
  } catch {
    // No address a browser can read ("http://" alone): none of Cardwave's.
    return false;
  }
}

/** A picture of a message; one that does not come is a link to it, its words or its address. */
function shownPicture(url: string, alt: string): HTMLElement {
  const picture = el("img", { className: "message-picture", src: url, alt, loading: "lazy" });
  picture.onerror = () => picture.replaceWith(isWeb(url) ? link(url, alt || url) : alt);
  return picture;
}

/** A picture of a message, or while pictures from the web are off and it is from another address, the warning in its place. */
function heldBack(url: string, alt: string): HTMLElement {
  if (fromWeb || isOwn(url)) return shownPicture(url, alt);
  const why = el("span");
  const button = el("button", { type: "button", className: "btn btn-secondary" }, wording("narration-show-pictures-from-the"));
  const held = el(
    "span",
    { className: "web-picture flex f-col g-10 ai-s" },
    el("span", null, wording("narration-a-picture-from-another")),
    button,
    el("span", { className: "meta" }, wording("narration-you-can-change-this")),
    why,
  );
  held.dataset.src = url;
  held.dataset.alt = alt;
  button.onclick = async () => {
    button.disabled = true;
    try {
      webPictures((await changeSettings({ web_pictures: true })).web_pictures);
      for (const other of document.querySelectorAll<HTMLElement>(".web-picture")) other.replaceWith(shownPicture(other.dataset.src!, other.dataset.alt!));
    } catch (error) {
      why.replaceChildren(failure(reason(error)));
    } finally {
      button.disabled = false;
    }
  };
  return held;
}

/**
 * A stretch of a message's text with its links and pictures: a Markdown link or an address alone becomes a link,
 * a Markdown picture an image (its words its `alt`); what is no web address stays as it is written.
 */
export function linked(text: string): (HTMLElement | string)[] {
  const shown: (HTMLElement | string)[] = [];
  let at = 0;
  for (const match of text.matchAll(LINKED)) {
    const [whole, alt, picture, words, url, bare] = match;
    const made =
      picture !== undefined
        ? (isWeb(picture) || /^data:image\//i.test(picture)) && heldBack(picture, alt)
        : url !== undefined
          ? isWeb(url) && link(url, words)
          : link(bare, bare);
    if (!made) continue;
    if (match.index > at) shown.push(text.slice(at, match.index));
    shown.push(made);
    at = match.index + whole.length;
  }
  if (at < text.length) shown.push(text.slice(at));
  return shown;
}

/** A text as its paragraphs: an empty line starts a new one. */
export const paragraphs = (text: string) => text.split(/\n\s*\n/);

/**
 * A paragraph as stretches of speech and narration, in their order. With
 * `open` the paragraph is still being written: narration begun and not ended
 * runs to its end.
 */
export function pieces(paragraph: string, open = false): Piece[] {
  const found: Piece[] = [];
  const add = (text: string, told: boolean) => {
    if (text) found.push({ text, told });
  };
  let at = 0;
  for (const match of paragraph.matchAll(TOLD)) {
    add(paragraph.slice(at, match.index), false);
    add(match[1], true);
    at = match.index + match[0].length;
  }
  const rest = paragraph.slice(at);
  const begun = open ? BEGUN.exec(rest) : null;
  if (begun) {
    add(rest.slice(0, begun.index), false);
    add(begun[1], true);
  } else add(rest, false);
  return found;
}

/**
 * A text as what a message shows: its paragraphs, which an empty line parts,
 * each with its narration in italics. With `open` the text is still being
 * written. A paragraph without words is left out, and a text without any is
 * nothing.
 */
export function narrated(text: string, open = false): (HTMLElement | string)[] {
  if (!text) return [];
  const parts = paragraphs(text);
  // The last paragraph is the one being written, with words or without: one before it is ended.
  const shown = parts.flatMap((paragraph, at) =>
    paragraph.trim() ? [el("p", null, ...pieces(paragraph, open && at === parts.length - 1).flatMap(({ text, told }) => (told ? [el("em", null, ...linked(text))] : linked(text))))] : [],
  );
  return shown.flatMap((paragraph, at) => (at ? ["\n\n", paragraph] : [paragraph]));
}
