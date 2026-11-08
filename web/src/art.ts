// The rules of a picture: whether one that has come is art (`isArt`, `MIN_ART`), the kinds of file taken
// (`PICTURES`), and `smallPicture`, a picture made small enough to send.
import { el } from "./dom";
import { wording } from "./language/language";

/** A picture narrower or lower than this, in pixels, is no art: a card made without a picture carries a stub. */
export const MIN_ART = 16;

/** Whether a picture that has come is art. */
export const isArt = (picture: HTMLImageElement) => picture.naturalWidth >= MIN_ART && picture.naturalHeight >= MIN_ART;

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
