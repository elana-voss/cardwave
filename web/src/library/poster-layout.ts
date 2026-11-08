// How a poster's words are laid out, no DOM: the title's lines and size (`layoutTitle`), the tagline's cut (`cutTagline`)
// and the face rule (`freeBands`, `keepOffFaces`), whose steps the page "Cardwave Posters" (docs/design.md) lists.
// Widths and heights are asked of the caller (poster.ts), which measures them on the page.
import type { Face } from "../api/generated/Face";
import type { Crop } from "./poster-colours";

/** The smallest title, as a share of the poster's width: 13 px on a tile of Gallery. */
const SMALLEST_TITLE = 0.063;
/** The highest a title may stand, as a share of the poster's height. */
const HIGHEST_TITLE = 0.34;
const MOST_LINES = 3;
/** A title of more words is only ever wrapped: the breaks to try grow with the words squared, each a measure on the page. */
const MOST_WORDS_TO_TRY = 16;
/** How far text stays from a face, as a share of the poster's height. */
export const FACE_PAD = 0.03;

export interface TitleBox {
  /** The poster's size. */
  width: number;
  height: number;
  /** The width the title may take. */
  room: number;
  /** The design's largest title, as a share of the poster's width. */
  largest: number;
  /** The title's line height, as a share of its size. */
  lineHeight: number;
}
export interface TitleLines {
  size: number;
  lines: string[];
  cut: boolean;
}
export interface Band {
  from: number;
  to: number;
}
/** How much room the text at each end takes from the poster's edge. */
export interface Sides {
  top: number;
  foot: number;
}
/** What the face rule asks of the poster's text on the page. */
export interface Placing {
  need(): Sides;
  /** Swaps what stands at the two ends. */
  swap(): void;
  /** Puts title and tagline together in the band. */
  stack(band: Band): void;
  stackedHeight(): number;
  /** Makes the title smaller, so that it and the tagline fit `room`. */
  shrinkTitle(room: number): void;
  /** Takes the tagline away and fits the title to `room`. */
  dropTagline(room: number): void;
  titleAtFoot(): void;
}
/** What came of the face rule. */
export type FaceResult = "clear" | "swapped" | "stacked" | "shrunk" | "dropped" | "over" | "no-room";

/** Every way to break `words` into `count` lines. */
function breaks(words: string[], count: number): string[][] {
  if (count === 1) return [[words.join(" ")]];
  const found: string[][] = [];
  for (let at = 1; at <= words.length - count + 1; at++) {
    for (const rest of breaks(words.slice(at), count - 1)) found.push([words.slice(0, at).join(" "), ...rest]);
  }
  return found;
}

/**
 * The title's lines: between words, one to three, whichever gives the largest size within the room and `highest`
 * pixels (at most about a third of the poster). Below the smallest size it stays at that and is wrapped, cut at a word
 * with "…" after three lines, or at a letter where one word is wider than the room. `width` is a line's width at 100 px.
 */
export function layoutTitle(title: string, width: (line: string) => number, box: TitleBox, highest = HIGHEST_TITLE * box.height): TitleLines {
  const measured = new Map<string, number>();
  const widthOf = (line: string) => {
    const known = measured.get(line);
    if (known !== undefined) return known;
    const found = width(line);
    measured.set(line, found);
    return found;
  };
  const words = title.trim().split(/\s+/);
  let best: TitleLines | null = null;
  if (words.length <= MOST_WORDS_TO_TRY) {
    for (let count = 1; count <= Math.min(MOST_LINES, words.length); count++) {
      for (const lines of breaks(words, count)) {
        const widest = Math.max(...lines.map(widthOf));
        const size = Math.min(box.largest * box.width, (box.room / widest) * 100, highest / (count * box.lineHeight));
        if (!best || size > best.size + 0.01) best = { size, lines, cut: false };
      }
    }
  }
  const size = SMALLEST_TITLE * box.width;
  if (best && best.size >= size) return best;
  const fits = (line: string) => (widthOf(line) * size) / 100 <= box.room;
  const lines: string[] = [];
  let line: string[] = [];
  for (const word of words) {
    if (!line.length || fits([...line, word].join(" "))) line.push(word);
    else {
      lines.push(line.join(" "));
      line = [word];
    }
  }
  lines.push(line.join(" "));
  /** A word that does not fit has no word to be cut at: its letters are. */
  const ended = (text: string) => {
    const letters = Array.from(text);
    while (letters.length > 1 && !fits(`${letters.join("")}…`)) letters.pop();
    return `${letters.join("")}…`;
  };
  const tooWide = lines.slice(0, MOST_LINES).findIndex((kept) => !fits(kept));
  if (tooWide >= 0) return { size, lines: [...lines.slice(0, tooWide), ended(lines[tooWide])], cut: true };
  if (lines.length <= MOST_LINES) return { size, lines, cut: false };
  const last = lines[MOST_LINES - 1].split(" ");
  while (last.length > 1 && !fits(`${last.join(" ")}…`)) last.pop();
  return { size, lines: [...lines.slice(0, MOST_LINES - 1), ended(last.join(" "))], cut: true };
}

/** A tagline cut at a word with "…" until it fits. */
export function cutTagline(tagline: string, fits: (text: string) => boolean): string {
  if (fits(tagline)) return tagline;
  const words = tagline.split(" ");
  while (words.length > 1) {
    words.pop();
    if (fits(`${words.join(" ")}…`)) break;
  }
  return `${words.join(" ")}…`;
}

/** Letter spacing of a spaced design, in em: narrower as the title grows. */
export const spacingFor = (title: string) => Math.max(0.04, Math.min(0.45, 0.55 - 0.035 * title.length));

/**
 * The rows of a poster of `size` left free by the faces on a picture of `picture`'s size cropped to `crop`: a face
 * outside the crop or under 1% of the poster counts for nothing (`boxes` says how many did count), one that does
 * blocks its rows, grown by 15% on every side.
 */
export function freeBands(faces: Face[], crop: Crop, picture: { width: number; height: number }, size: { width: number; height: number }): { boxes: number; free: Band[] } {
  const { width: W, height: H } = size;
  const blocked: [number, number][] = [];
  for (const face of faces) {
    const x0 = ((face.left * picture.width - crop.sx) / crop.sw) * W;
    const x1 = (((face.left + face.width) * picture.width - crop.sx) / crop.sw) * W;
    const y0 = ((face.top * picture.height - crop.sy) / crop.sh) * H;
    const y1 = (((face.top + face.height) * picture.height - crop.sy) / crop.sh) * H;
    const shown = (Math.min(W, x1) - Math.max(0, x0)) * (Math.min(H, y1) - Math.max(0, y0));
    if (x1 <= 0 || x0 >= W || y1 <= 0 || y0 >= H || shown < 0.01 * W * H) continue;
    const grown = (y1 - y0) * 0.15;
    blocked.push([Math.max(0, y0 - grown), Math.min(H, y1 + grown)]);
  }
  blocked.sort((one, other) => one[0] - other[0]);
  const free: Band[] = [];
  let edge = 0;
  for (const [from, to] of blocked) {
    if (from > edge) free.push({ from: edge, to: from });
    edge = Math.max(edge, to);
  }
  if (edge < H) free.push({ from: edge, to: H });
  return { boxes: blocked.length, free };
}

/** The face rule's steps, on a poster `height` high whose free rows are `free`. */
export function keepOffFaces(free: Band[], text: Placing, height: number): FaceResult {
  const pad = FACE_PAD * height;
  const atTop = free[0]?.from === 0 ? free[0].to : 0;
  const last = free[free.length - 1];
  const atFoot = last?.to === height ? height - last.from : 0;
  const fits = () => {
    const need = text.need();
    return (!need.top || need.top + pad <= atTop) && (!need.foot || need.foot + pad <= atFoot);
  };
  if (fits()) return "clear";
  text.swap();
  if (fits()) return "swapped";
  const band = [...free].sort((one, other) => other.to - other.from - (one.to - one.from))[0];
  if (!band) {
    text.swap();
    return "no-room";
  }
  text.stack(band);
  const room = band.to - band.from - 2 * FACE_PAD * height;
  if (text.stackedHeight() <= room) return "stacked";
  text.shrinkTitle(room);
  if (text.stackedHeight() <= room) return "shrunk";
  text.dropTagline(room);
  if (text.stackedHeight() <= room) return "dropped";
  text.titleAtFoot();
  return "over";
}
