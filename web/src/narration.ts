// How a text's marks are drawn (marks.ts reads them): speech in a `span.speech` with its quotation marks, italics
// `em`, bold `strong`, underline `u`, code `code`, links that open in the browser, pictures. `narrated` makes the
// paragraphs and quotation blocks a chat's message and the companion's show, a `p` each (a quotation block's in a
// `blockquote`; `block` one, which a card's page shares), a blank line as text between two paragraphs, so
// `textContent` is the text written less its marks; `inline` draws a line elsewhere (a heading, a list's item, About). Their colours are the stylesheet's (text-sets.css).
// A picture from another address than Cardwave's own (this page's origin, or data:) shows only while Settings'
// "Pictures from the web" is on (`webPictures`, which `readWebPictures` reads from the settings for the chat and
// the companion): else its place says why, with a button that switches it on and shows every picture so held back
// on the page. The page's Content-Security-Policy lets them load only where the switch was on as the page was
// loaded, which the first value read on the page stands for (`atLoad`, read at start by main.ts and the
// companion's): switched on later, the page loads again (once under Vite's dev server, which sends no policy).
import { changeSettings, getSettings } from "./api/client";
import { el, failure, reason } from "./dom";
import { wording } from "./language/language";
import { isWeb, joined, read, type Piece, type Reading, type Unit } from "./marks";

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


/** A link that opens in the browser, beside the app (the desktop app hands it to the system's browser). */
const link = (url: string, ...words: (HTMLElement | string)[]) => el("a", { href: url, target: "_blank", rel: "noopener noreferrer" }, ...words);

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

/** The elements of what a mark sets apart. */
const MARKED = { speech: "span", italics: "em", bold: "strong", underline: "u" } as const;

/** Pieces as what shows of them: marks as their elements, code, links and pictures. */
export function drawn(pieces: Piece[]): (HTMLElement | string)[] {
  return pieces.map((piece) => {
    switch (piece.kind) {
      case "text":
        return piece.text;
      case "code":
        return el("code", null, piece.text);
      case "picture":
        return heldBack(piece.url, piece.alt);
      case "link":
        return link(piece.url, ...drawn(piece.pieces));
      case "mark":
        return el(MARKED[piece.mark], piece.mark === "speech" ? { className: "speech" } : null, ...drawn(piece.pieces));
    }
  });
}

/** A line as it shows: its marks, and with `links` its links, pictures and addresses. */
export const inline = (line: string, links: boolean, open = false) => drawn(read(line, { links, open }));

/**
 * A text as what a message shows: its paragraphs, which an empty line parts, and its quotation blocks, with their
 * marks, links and pictures. With `open` the text is still being written. A paragraph without words is left out,
 * and a text without any is nothing.
 */
export function narrated(text: string, open = false): (HTMLElement | string)[] {
  if (!text) return [];
  return joined(text, (unit) => block(unit, { open: open && unit.last, links: true }));
}

/** A block of a text as it shows: a `p` of its lines, a quotation block's in a `blockquote`. */
export function block({ quote, text }: Unit, reading: Reading): HTMLElement {
  const words = el("p", null, ...drawn(read(text, reading)));
  return quote ? el("blockquote", null, words) : words;
}
