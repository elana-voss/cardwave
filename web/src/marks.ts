// The one reader of a text's marks, for a chat's messages, the companion's and a card's page: what it reads, never
// how it is drawn (narration.ts draws it). `read` reads one paragraph or quotation block into `Piece`s:
// - first, leftmost, code in backticks (a run of any length, a fence's language word left out; nothing inside it
//   is read), and only with `links` (the card page passes none: they stay text) Markdown pictures, links and an
//   address alone; a link's words are read for marks and pictures, its address (brackets in pairs kept, a title
//   left out) and a picture's words whole; a link to no web page (a picture from neither the web nor
//   `data:image/`) stays text;
// - then speech in every language's quotation marks, paired by position (any of " “ ” „ ‟ « » closes the one
//   open, 「」 and 『』 by their partner; single quotes never, a sign right after a digit opens none), `*` italics,
//   `**` bold and `<u>` underline, nested within each other. A mark opened later that the earlier one's end
//   crosses ends with it; its own closing sign then shows as written.
// - Left open: with `open` (the text still being written) every mark runs to the end; else speech runs to the
//   paragraph's end (a novel's long speech) and the other signs show as written.
// Traps: an asterisk inside a word or beside a space marks nothing ("2*3*4", "2 * 3"); runs of more than three show.
// `units` parts a text into what is read, the same for every place (`paragraphs`, `blocks`), `joined` puts
// them together again; `plain` is the text without its marks (read aloud).

/** What a mark sets apart: speech, italics (narration, thoughts), bold, underline. */
export type Mark = "speech" | "italics" | "bold" | "underline";

/** A stretch of a text as read: words, code, a picture, a link with its words, or a mark around what it holds. */
export type Piece =
  | { kind: "text"; text: string }
  | { kind: "code"; text: string }
  | { kind: "picture"; url: string; alt: string }
  | { kind: "link"; url: string; pieces: Piece[] }
  | { kind: "mark"; mark: Mark; pieces: Piece[] };

export interface Reading {
  /** The text is still being written: a mark left open runs to its end. */
  open?: boolean;
  /** Links, pictures and addresses are read (a chat's messages); else they stay as written. */
  links?: boolean;
}

/** A text as its paragraphs: an empty line starts a new one, outside a code fence (a line beginning with ```). */
export function paragraphs(text: string): string[] {
  // The split keeps each empty line at the odd places, so a paragraph with a fence left open takes it back.
  const parts = text.split(/(\n\s*\n)/);
  const found = [parts[0]];
  for (let at = 2; at < parts.length; at += 2) {
    const last = found.length - 1;
    if ((found[last].match(/^\s*```/gm)?.length ?? 0) % 2 === 1) found[last] += parts[at - 1] + parts[at];
    else found.push(parts[at]);
  }
  return found;
}

/** A line of a quotation block: ">" at its start, alone or before a space. */
const QUOTE = /^\s*>(?:\s|$)/;

/** A paragraph as its runs of lines: quotation blocks (their ">" taken off) and the lines between them. */
export function blocks(paragraph: string): { quote: boolean; text: string }[] {
  const found: { quote: boolean; text: string }[] = [];
  for (const line of paragraph.split("\n")) {
    const quote = QUOTE.test(line);
    const text = quote ? line.replace(/^\s*> ?/, "") : line;
    const last = found.at(-1);
    if (last?.quote === quote) last.text += `\n${text}`;
    else found.push({ quote, text });
  }
  return found;
}

/** A block of a text as it is read: a quotation block or a run of lines, its paragraph's number, and whether it is the text's last. */
export interface Unit {
  quote: boolean;
  text: string;
  paragraph: number;
  /** The last block with words of the last paragraph: the one being written while the text is. */
  last: boolean;
}

/**
 * A text as what is read one at a time, each place alike (a chat's messages, the companion's, a card's page, reading
 * aloud): its paragraphs' quotation blocks and the runs of lines between them, those without words left out.
 */
export function units(text: string): Unit[] {
  const parts = paragraphs(text.replace(/\r\n?/g, "\n"));
  return parts.flatMap((paragraph, at) => {
    const found = blocks(paragraph).filter((block) => block.text.trim());
    return found.map((block, which) => ({ ...block, paragraph: at, last: at === parts.length - 1 && which === found.length - 1 }));
  });
}

/**
 * A text's units, each as `each` makes it, with what stands between two: a line's end within a paragraph, an empty
 * line between two paragraphs. Both the drawn text and the text read aloud are joined so, a copied selection too.
 */
export function joined<T>(text: string, each: (unit: Unit) => T): (T | string)[] {
  return units(text).flatMap((unit, at, all) => (at === 0 ? [each(unit)] : [all[at - 1].paragraph === unit.paragraph ? "\n" : "\n\n", each(unit)]));
}

/** A text's words without its marks, as read aloud: a link's words, a picture's none. */
export const plain = (pieces: Piece[]): string =>
  pieces.map((piece) => (piece.kind === "text" || piece.kind === "code" ? piece.text : piece.kind === "picture" ? "" : plain(piece.pieces))).join("");

/** Signs that end no address: a sentence's, the marks' and the quotation marks. */
const NOT_IN_ADDRESS = `\\s<>"*\`“”„‟«»「」『』。、，．！？；：（）【】《》〈〉`;
/** A link's or picture's address: its own brackets kept, in pairs ("A_(b)"). */
const URL = "(?:[^()\\s]|\\([^()\\s]*\\))+";
/** A link's title after its address, which is not shown. */
const TITLE = '(?:\\s+"[^"]*")?';
/** A link's words: a picture within them, brackets in pairs, anything but a bracket. */
const LINK_WORDS = `(?:!\\[[^\\]]*\\]\\(${URL}${TITLE}\\)|\\[[^\\]]*\\]|[^\\[\\]])+`;
/** A part of an address alone, and its last: brackets only in pairs, a sentence's sign never at its end. */
const UNIT = `(?:[^${NOT_IN_ADDRESS}()]|\\([^${NOT_IN_ADDRESS}()]*\\))`;
const END = `(?:[^${NOT_IN_ADDRESS}().,;:!?\\]']|\\([^${NOT_IN_ADDRESS}()]*\\))`;
/**
 * What is read in one go, leftmost first: code; a picture; a link; an address alone; a run of asterisks; an
 * underline's sign; a quotation mark.
 */
const TOKEN = new RegExp(
  [
    "(?<!`)(`+)([^`]|[^`][\\s\\S]*?[^`])\\1(?!`)",
    `!\\[([^\\]]*)\\]\\((${URL})${TITLE}\\)`,
    `\\[(${LINK_WORDS})\\]\\((${URL})${TITLE}\\)`,
    `(https?:\\/\\/${UNIT}*${END})`,
    "(\\*+)",
    "(<\\/?u>)",
    "([\"“”„‟«»「」『』])",
  ].join("|"),
  "giu",
);

/** Whether `url` is a web page's address (http or https). */
export const isWeb = (url: string) => /^https?:\/\//i.test(url);
const isPicture = (url: string) => isWeb(url) || /^data:image\//i.test(url);
const WORD = /[\p{L}\p{N}]/u;
const SPACE = /\s/u;
/** The pairs of the quotation marks read by their partner; every other one closes whichever is open. */
const PARTNERS: Record<string, string> = { "「": "」", "『": "』" };

/** Which pair a sign opens or closes. */
interface Slot {
  pair: number;
  opens: boolean;
}

/** What `read` finds before the signs are paired. */
type Token =
  | { kind: "text"; text: string }
  | { kind: "piece"; piece: Piece }
  | { kind: "stars"; size: number; open: boolean; close: boolean; atEnd: boolean; slots: (Slot | undefined)[] }
  | { kind: "sign"; text: string; afterDigit: boolean; slot?: Slot };

/** Code's text: a fence's (three backticks or more) without its language word's line and its last line's end. */
const codeText = (fence: string, code: string) => (fence.length < 3 ? code : code.replace(/^[^\n]*\n/, "").replace(/\n$/, ""));

/** What of links is read: all of them, pictures only (a link's words), or none (the card page). */
type Links = "all" | "pictures" | "none";

/** A paragraph's text as its tokens: words, what is read whole, and the signs of the marks; `writing` while it is written. */
function tokens(text: string, links: Links, writing: boolean): Token[] {
  const found: Token[] = [];
  const words = (to: number) => {
    if (to > at) found.push({ kind: "text", text: text.slice(at, to) });
  };
  let at = 0;
  const scan = new RegExp(TOKEN);
  for (let match = scan.exec(text); match; match = scan.exec(text)) {
    const [whole, fence, code, alt, picture, linkWords, url, bare, stars, underline, quote] = match;
    const piece: Piece | false | undefined =
      code !== undefined
        ? { kind: "code", text: codeText(fence, code) }
        : picture !== undefined
          ? links !== "none" && isPicture(picture) && { kind: "picture", url: picture, alt }
          : url !== undefined
            ? links === "all" && isWeb(url) && { kind: "link", url, pieces: reading(linkWords, false, "pictures") }
            : bare !== undefined
              ? links === "all" && { kind: "link", url: bare, pieces: [{ kind: "text", text: bare }] }
              : undefined;
    if (piece === false) {
      // No link to be made: its first sign stays text, and what follows is read again.
      scan.lastIndex = match.index + 1;
      continue;
    }
    words(match.index);
    at = match.index + whole.length;
    if (piece) found.push({ kind: "piece", piece });
    else if (stars !== undefined) {
      const before = text[match.index - 1] ?? " ";
      const after = text[at];
      // At the very end of a text being written, an asterisk may begin what is still to come.
      const open = (after === undefined ? writing : !SPACE.test(after)) && !WORD.test(before);
      const close = !SPACE.test(before) && !(after !== undefined && WORD.test(after));
      const atEnd = after === undefined;
      found.push({ kind: "stars", size: stars.length, open, close, atEnd, slots: Array<Slot | undefined>(stars.length).fill(undefined) });
    } else found.push({ kind: "sign", text: underline ?? quote, afterDigit: /\p{N}/u.test(text[match.index - 1] ?? "") });
  }
  words(text.length);
  return found;
}

/** The marks of the pairs found, a pair's number its place. */
type Pairs = Mark[];

type Stars = Extract<Token, { kind: "stars" }>;
type Sign = Extract<Token, { kind: "sign" }>;

/** An opener's signs still free: from `floor` to `right`, taken from the right, the one nearest its words first. */
interface Opener {
  token: Stars;
  floor: number;
  right: number;
}

/** An opener left without its closer as a mark open to the end of what holds it, three signs as bold within italics. */
function runsOn({ token, floor, right }: Opener, pairs: Pairs): void {
  const marks: Mark[] = right - floor === 3 ? ["italics", "bold"] : right - floor === 2 ? ["bold"] : ["italics"];
  let at = floor;
  for (const mark of marks) {
    const pair = pairs.push(mark) - 1;
    for (const end = at + (mark === "bold" ? 2 : 1); at < end; at++) token.slots[at] = { pair, opens: true };
  }
}

/**
 * Pairs the runs of asterisks: a closer takes the signs of the nearest opener of its own size, the openers above
 * it crossed (each a mark that ends with it where more is still to come, else its signs shown as written); with
 * none of its size the nearest opener's, two for bold where both have two. While the text is written a closer at
 * its very end with none of its size may begin what is still to come, and closes nothing yet.
 */
function pairStars(found: Token[], pairs: Pairs, open: boolean): void {
  const openers: Opener[] = [];
  const runs = found.filter((token): token is Stars => token.kind === "stars" && token.size <= 3);
  runs.forEach((token, index) => {
    let left = 0;
    let exact = token.close ? openers.length - 1 : -1;
    while (exact >= 0 && openers[exact].right - openers[exact].floor !== token.size) exact--;
    if (exact >= 0) {
      const more = open || runs.slice(index + 1).some((later) => later.close);
      for (const crossed of openers.splice(exact + 1)) if (more) runsOn(crossed, pairs);
    } else if (open && token.atEnd && token.close) {
      openers.push({ token, floor: 0, right: token.size });
      return;
    }
    while (token.close && left < token.size && openers.length) {
      const opener = openers.at(-1)!;
      const use = opener.right - opener.floor >= 2 && token.size - left >= 2 ? 2 : 1;
      const pair = pairs.push(use === 2 ? "bold" : "italics") - 1;
      for (let k = 0; k < use; k++) {
        opener.token.slots[opener.right - 1 - k] = { pair, opens: true };
        token.slots[left + k] = { pair, opens: false };
      }
      opener.right -= use;
      left += use;
      if (opener.right === opener.floor) openers.pop();
    }
    if (token.open && left < token.size) openers.push({ token, floor: left, right: token.size });
  });
  // Being written: what is begun runs to the end.
  if (open) for (const opener of openers) runsOn(opener, pairs);
}

/** Pairs the quotation marks by position and the underline's signs; speech left open runs to the end. */
function pairSigns(found: Token[], pairs: Pairs, open: boolean): void {
  let western: Sign | undefined;
  const partnered: Record<string, Sign[]> = { "「": [], "『": [] };
  const underlined: Sign[] = [];
  const pair = (opener: Sign, closer: Sign | undefined, mark: Mark) => {
    const id = pairs.push(mark) - 1;
    opener.slot = { pair: id, opens: true };
    if (closer) closer.slot = { pair: id, opens: false };
  };
  for (const token of found) {
    if (token.kind !== "sign") continue;
    const sign = token.text.toLowerCase();
    if (sign === "<u>") underlined.push(token);
    else if (sign === "</u>") {
      const opener = underlined.pop();
      if (opener) pair(opener, token, "underline");
    } else if (sign in PARTNERS) partnered[sign].push(token);
    else if (sign === "」" || sign === "』") {
      const opener = partnered[sign === "」" ? "「" : "『"].pop();
      if (opener) pair(opener, token, "speech");
    } else if (western) {
      pair(western, token, "speech");
      western = undefined;
    } else if (!token.afterDigit) western = token;
  }
  for (const opener of [western, ...partnered["「"], ...partnered["『"]]) if (opener) pair(opener, undefined, "speech");
  if (open) for (const opener of underlined) pair(opener, undefined, "underline");
}

/**
 * A paragraph or a quotation block as its pieces, in their order. With `open` it is still being written; with
 * `links` its links, pictures and addresses are read.
 */
export const read = (text: string, { open = false, links = false }: Reading = {}): Piece[] => reading(text, open, links ? "all" : "none");

/** `read`, with what of links is read. */
function reading(text: string, open: boolean, links: Links): Piece[] {
  const found = tokens(text, links, open);
  const pairs: Pairs = [];
  pairStars(found, pairs, open);
  pairSigns(found, pairs, open);
  return built(found, pairs);
}

/** A mark being read: its pair and what it holds so far. */
interface Frame {
  pair: number;
  pieces: Piece[];
}

/** The tokens, paired, as nested pieces: a pair's end ends the marks begun within it, whose own ends then show. */
function built(found: Token[], pairs: Pairs): Piece[] {
  const root: Frame = { pair: -1, pieces: [] };
  const frames: Frame[] = [root];
  const add = (piece: Piece) => {
    const into = frames.at(-1)!.pieces;
    const last = into.at(-1);
    if (piece.kind === "text" && last?.kind === "text") last.text += piece.text;
    else if (piece.kind !== "text" || piece.text) into.push(piece);
  };
  const text = (words: string) => add({ kind: "text", text: words });
  const end = () => {
    const frame = frames.pop()!;
    if (frame.pieces.length) add({ kind: "mark", mark: pairs[frame.pair], pieces: frame.pieces });
  };
  const sign = (slot: Slot | undefined, words: string) => {
    if (!slot) return text(words);
    const speech = pairs[slot.pair] === "speech";
    if (slot.opens) {
      frames.push({ pair: slot.pair, pieces: [] });
      if (speech) text(words);
      return;
    }
    const at = frames.findIndex((frame) => frame.pair === slot.pair);
    if (at < 0) return text(words);
    while (frames.length > at + 1) end();
    if (speech) text(words);
    end();
  };
  for (const token of found) {
    if (token.kind === "text") text(token.text);
    else if (token.kind === "piece") add(token.piece);
    else if (token.kind === "sign") sign(token.slot, token.text);
    else
      // A run of asterisks: each sign alone, a pair's two (bold) as one.
      token.slots.forEach((slot, at) => {
        if (!slot) return text("*");
        if (token.slots[at - 1]?.pair === slot.pair) return;
        sign(slot, token.slots[at + 1]?.pair === slot.pair ? "**" : "*");
      });
  }
  while (frames.length > 1) end();
  return root.pieces;
}
