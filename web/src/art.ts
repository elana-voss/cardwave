// The rules of a picture: whether one that has come is art (`isArt`, `MIN_ART`), `pictureOr`, a picture that gives
// its place to a stand-in where it is none, the kinds of file taken (`PICTURES`), and `smallPicture`, a picture
// made small enough to send.
import { el } from "./dom";
import { wording } from "./language/language";

/** A picture narrower or lower than this, in pixels, is no art: a card made without a picture carries a stub. */
export const MIN_ART = 16;

/** Whether a picture that has come is art. */
export const isArt = (picture: HTMLImageElement) => picture.naturalWidth >= MIN_ART && picture.naturalHeight >= MIN_ART;

/**
 * `shown`, which gives its place to what `standIn` makes where its picture does not come or is no art (a card
 * without a picture carries a stub), as an `img` without a picture is drawn as a broken one. With `stubs` (the
 * tab's round, as its look stands) a stub stays and only a picture that fails gives way.
 */
export function pictureOr(shown: HTMLImageElement, standIn: () => HTMLElement, { stubs = false } = {}): HTMLImageElement {
  const none = () => shown.replaceWith(standIn());
  shown.onload = () => {
    if (!stubs && !isArt(shown)) none();
  };
  shown.onerror = none;
  return shown;
}

/** The kinds of picture file taken. */
export const PICTURES = ["image/png", "image/jpeg", "image/webp"];
/** The longer side of a picture as it is sent, in pixels. */
const SIDE = 512;

/** The picture `file` made at most `SIDE` pixels on its longer side, as a PNG; refused, with why, where it is no picture. */
export async function smallPicture(file: File): Promise<Blob> {
  if (!PICTURES.includes(file.type)) throw new Error(wording("art-is-not-a-png", { name: file.name }));
  const read = await createImageBitmap(file).catch(() => {
    throw new Error(wording("art-cannot-be-read-as", { name: file.name }));
  });
  const scale = Math.min(1, SIDE / Math.max(read.width, read.height));
  const canvas = el("canvas", { width: Math.max(1, Math.round(read.width * scale)), height: Math.max(1, Math.round(read.height * scale)) });
  canvas.getContext("2d")!.drawImage(read, 0, 0, canvas.width, canvas.height);
  read.close();
  return new Promise((done, failed) => canvas.toBlob((made) => (made ? done(made) : failed(new Error(wording("art-cannot-be-made-a", { name: file.name })))), "image/png"));
}
