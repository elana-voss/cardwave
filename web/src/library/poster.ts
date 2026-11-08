// A card's poster, the picture of a tile in the view Posters: its picture cropped, with its title and tagline set in
// its design (poster-designs.ts), by the colour and crop rules on the picture's pixels (poster-colours.ts) and the
// title and face rules (poster-layout.ts). How it looks is ../app/posters.css, whose head names what is set here.
// Painted once the picture and the design's fonts are in, and anew when its width changes; until then its words stay
// hidden. A paint starts from the same state whatever came before it. Traps: a width is measured inside the poster,
// where the design's letter spacing holds, by `offsetWidth`, which a design's transform does not change; a poster
// taken from the page reports a size of nothing, at which it leaves the shared observer.
import { cardThumbnailUrl } from "../api/client";
import type { CardSummary } from "../api/generated/CardSummary";
import type { Poster } from "../api/generated/Poster";
import { isArt } from "../art";
import { el } from "../dom";
import { DESIGNS, type DesignName } from "./poster-designs";
import { centreCrop, colours, CROP_SAMPLE, type Crop, cropOf, flips, hex, NO_PICTURE, type Reading, readCrop, SAMPLE } from "./poster-colours";
import { type Band, cutTagline, FACE_PAD, freeBands, keepOffFaces, layoutTitle, type Placing, spacingFor } from "./poster-layout";
import { cardTitle } from "../card-title";

const ARTICLE = /^(the|a|an)\s+(.+)$/i;
const MOST_TAGLINE_LINES = 3;
/** The gap between title and tagline, as a share of the poster's width (.poster-zone's gap). */
const GAP = 0.026;
/** How far a fade goes past its text, and the most it may cover, as shares of the poster's height. */
const FADE_PAST = 0.2;
const FADE_MOST = 0.8;
const MIDDLE_FADE_PAST = 0.12;
/** An article's size, as a share of the title's, and its smallest in pixels. */
const ARTICLE_SIZE = 0.36;
const ARTICLE_SMALLEST = 11;
/** How many pictures' readings are kept: about what a long scroll passes. */
const MOST_KEPT = 500;

interface PictureRead {
  crop: Crop;
  reading: Reading;
}

const read = new Map<string, PictureRead>();

/** The pixels of a part of `picture`, scaled to `width` by `height`. */
function pixelsOf(picture: HTMLImageElement, width: number, height: number, part?: Crop): Uint8ClampedArray {
  const canvas = el("canvas", { width, height });
  const paper = canvas.getContext("2d", { willReadFrequently: true });
  if (!paper) throw new Error("no canvas");
  if (part) paper.drawImage(picture, part.sx, part.sy, part.sw, part.sh, 0, 0, width, height);
  else paper.drawImage(picture, 0, 0, width, height);
  return paper.getImageData(0, 0, width, height).data;
}

/** What a picture gives its poster; none where its pixels cannot be read: its colours are those of no picture. */
function readPicture(picture: HTMLImageElement): PictureRead | null {
  const known = read.get(picture.src);
  if (known) return known;
  const { naturalWidth: wide, naturalHeight: high } = picture;
  const scale = CROP_SAMPLE / Math.max(wide, high);
  const width = Math.max(1, Math.round(wide * scale));
  const height = Math.max(1, Math.round(high * scale));
  try {
    const crop = cropOf(pixelsOf(picture, width, height), width, height, wide, high);
    const found = { crop, reading: readCrop(pixelsOf(picture, SAMPLE.width, SAMPLE.height, crop)) };
    if (read.size >= MOST_KEPT) read.clear();
    read.set(picture.src, found);
    return found;
  } catch (cause) {
    console.warn("A poster could not read its picture", cause);
    return null;
  }
}

const painters = new WeakMap<Element, () => void>();
const sizes = new ResizeObserver((entries) => {
  for (const { target } of entries) {
    if (target.isConnected) painters.get(target)?.();
    else sizes.unobserve(target);
  }
});

/** The poster of `card`, which shows `shows`, in the design `name`. */
export function poster(card: CardSummary, shows: Poster, name: DesignName): HTMLElement {
  const design = DESIGNS[name];
  const scrim = (where: string) => el("span", { className: `poster-scrim poster-scrim-${where}` });
  const scrims = { top: scrim("top"), foot: scrim("foot"), mid: scrim("mid") };
  const top = el("span", { className: "poster-zone poster-top" });
  const foot = el("span", { className: "poster-zone poster-foot" });
  const title = el("span", { className: "poster-title" });
  const tagline = el("span", { className: "poster-tagline" });
  const parts = { title, tagline };
  const picture = el("img", { src: cardThumbnailUrl(card.version_id, "tile"), alt: "", loading: "lazy" });
  const node = el("span", { className: `poster poster-${name}${design.left ? " poster-left" : ""}` }, picture, scrims.top, scrims.foot, scrims.mid, top, foot);
  const home = design.top.includes("title") ? "top" : "foot";
  const words = design.article ? cardTitle(card.title).trim().match(ARTICLE) : null;
  const titleWords = words ? words[2] : cardTitle(card.title);
  let found: PictureRead | null = null;
  let ready = false;
  let paintedWidth = 0;

  function paint(): void {
    const { clientWidth: width, clientHeight: height } = node;
    if (!ready || !width || width === paintedWidth) return;
    paintedWidth = width;
    const flipped = found !== null && flips(found.reading, home);
    top.style.top = "";
    top.append(...(flipped ? design.foot : design.top).map((part) => parts[part]));
    foot.append(...(flipped ? design.top : design.foot).map((part) => parts[part]));
    if (design.track) node.style.setProperty("--tr", `${spacingFor(cardTitle(card.title))}em`);

    const measure = el("span", { className: "poster-title poster-measure" });
    node.append(measure);
    const widthOf = (line: string) => {
      measure.textContent = line;
      return measure.offsetWidth;
    };
    const box = {
      width,
      height,
      room: top.clientWidth * design.span,
      largest: design.largest,
      lineHeight: parseFloat(getComputedStyle(measure).lineHeight) / 100 || 1,
    };
    const setTitle = (highest?: number) => {
      const { size, lines } = layoutTitle(titleWords, widthOf, box, highest);
      title.style.fontSize = `${size}px`;
      title.replaceChildren(...lines.map((line) => el("span", { className: "poster-line" }, line)));
      if (words) {
        const article = el("span", { className: "poster-article" }, words[1]);
        article.style.fontSize = `${Math.max(ARTICLE_SMALLEST, ARTICLE_SIZE * size)}px`;
        title.prepend(article);
      }
    };
    setTitle();
    const taglineLine = parseFloat(getComputedStyle(tagline).lineHeight);
    tagline.textContent = cutTagline(shows.tagline, (text) => {
      tagline.textContent = text;
      return tagline.offsetHeight <= taglineLine * MOST_TAGLINE_LINES + 1;
    });

    // A picture still shown whose pixels could not be read has its centre shown, and faces all the same.
    const shown = found?.crop ?? (picture.parentElement ? centreCrop(picture.naturalWidth, picture.naturalHeight) : null);
    if (shown && shows.faces.length) {
      const { boxes, free } = freeBands(shows.faces, shown, { width: picture.naturalWidth, height: picture.naturalHeight }, { width, height });
      if (boxes) keepOffFaces(free, placing(height, width), height);
    }

    const zone = title.parentElement as HTMLElement;
    const end = zone.offsetTop + zone.offsetHeight / 2 < height / 2 ? "top" : "foot";
    const colour = found ? colours(found.reading, end, design) : NO_PICTURE;
    node.style.setProperty("--dk", colour.fade.join(" "));
    node.style.setProperty("--tc", hex(colour.title));
    node.style.setProperty("--gc", hex(colour.tagline));
    if (!found) node.style.setProperty("--ground", hex(colour.fade));

    const middle = top.style.top !== "";
    const fade = (scrimOf: HTMLElement, used: boolean, reach: number) => {
      scrimOf.style.opacity = used ? "1" : "0";
      scrimOf.style.height = `${Math.min(FADE_MOST * height, reach + FADE_PAST * height)}px`;
    };
    fade(scrims.top, top.children.length > 0 && !middle, top.offsetTop + top.offsetHeight);
    fade(scrims.foot, foot.children.length > 0, height - foot.offsetTop);
    scrims.mid.style.opacity = middle ? "1" : "0";
    if (middle) {
      scrims.mid.style.top = `${Math.max(0, top.offsetTop - MIDDLE_FADE_PAST * height)}px`;
      scrims.mid.style.height = `${top.offsetHeight + 2 * MIDDLE_FADE_PAST * height}px`;
    }
    measure.remove();
    node.classList.add("poster-drawn");

    /** The face rule's moves, on this poster. */
    function placing(tall: number, wide: number): Placing {
      let stacked = top;
      return {
        need: () => ({ top: top.children.length ? top.offsetTop + top.offsetHeight : 0, foot: foot.children.length ? tall - foot.offsetTop : 0 }),
        swap: () => {
          const upper = [...top.children];
          top.append(...foot.children);
          foot.append(...upper);
        },
        stack: (band: Band) => {
          stacked = band.to === tall && band.from !== 0 ? foot : top;
          if (band.from !== 0 && band.to !== tall) top.style.top = `${band.from + FACE_PAD * tall}px`;
          stacked.append(...[...design.top, ...design.foot].map((part) => parts[part]));
        },
        stackedHeight: () => stacked.offsetHeight,
        shrinkTitle: (room) => setTitle(Math.max(0, room - (tagline.offsetHeight + GAP * wide))),
        dropTagline: (room) => {
          tagline.remove();
          setTitle(room);
        },
        titleAtFoot: () => {
          top.style.top = "";
          foot.append(title);
        },
      };
    }
  }

  /** The picture has come, or will not. */
  function pictureSettled(): void {
    void Promise.allSettled(design.fonts.map((font) => document.fonts.load(font))).then(() => {
      ready = true;
      paint();
    });
  }
  picture.onload = () => {
    if (isArt(picture)) {
      found = readPicture(picture);
      if (found) picture.style.objectPosition = found.crop.position;
    } else picture.remove();
    pictureSettled();
  };
  picture.onerror = () => {
    picture.remove();
    pictureSettled();
  };
  painters.set(node, paint);
  sizes.observe(node);
  return node;
}
