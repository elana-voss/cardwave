// The mouth without a voice (`Lips`): a text the figure speaks unvoiced (the compact chat's reply as it streams in,
// the bubble of its own `Say`, which arrives whole) is played letter by letter at a speaking pace (`PACE`), each
// letter a mouth shape (`shapesOf`): wide on a, less on o and e, little on i and u, shut on m, b and p, a little open
// on the other consonants, at rest between words and longer at a comma or a sentence's end. Letters of a script
// without these vowels open and half-shut in turn, a syllable each. It rests when the text is played or it is told to
// (`rest`), and figure.ts smooths the shapes into the face's "open".
//
// Traps: a reply streams in faster than it is spoken, so its letters queue; what is left of them when the reply ends
// is dropped by `rest`, so the mouth rests with the reply.

/** Letters a second, about the pace of speech, for a streamed reply and a bubble alike. */
export const PACE = 15;

/** Each vowel's and lip-closing consonant's shape (0 shut to 1 wide), after its accents are taken off. */
const SHAPES: Record<string, number> = { a: 1, o: 0.8, e: 0.6, i: 0.4, u: 0.4, y: 0.4, m: 0, b: 0, p: 0 };
/** Any other Latin consonant's. */
const CONSONANT = 0.2;
/** A letter of another script, opened and half-shut in turn. */
const SYLLABLE = [0.7, 0.2];
/** How many letters' time the mouth rests at a word's end, a comma and a sentence's end. */
const PAUSES: [RegExp, number][] = [[/\s/u, 1], [/[,;:،、，]/u, 2], [/[.!?…。！？]/u, 3]];

/** The shapes of `text`'s letters in turn, the `nth` of the letters of other scripts before it counted from `nth`. */
export function shapesOf(text: string, nth = 0): { shapes: number[]; nth: number } {
  const shapes: number[] = [];
  for (const char of text) {
    const pause = PAUSES.find(([marks]) => marks.test(char));
    if (pause) shapes.push(...Array<number>(pause[1]).fill(0));
    else if (/[a-z]/i.test(char.normalize("NFD")[0])) shapes.push(SHAPES[char.normalize("NFD")[0].toLowerCase()] ?? CONSONANT);
    else if (/[\p{L}\p{N}]/u.test(char)) shapes.push(SYLLABLE[nth++ % SYLLABLE.length]);
  }
  return { shapes, nth };
}

/** A mouth that speaks the letters it hears, in turn, at `PACE`. */
export class Lips {
  /** The shapes still to play, the one shown first. */
  private shapes: number[] = [];
  /** How far into the first shape it is, in letters. */
  private at = 0;
  private nth = 0;

  /** Letters arrived, played after those before. */
  hear(text: string): void {
    const heard = shapesOf(text, this.nth);
    this.nth = heard.nth;
    this.shapes.push(...heard.shapes);
  }

  /** A whole text to speak, in place of what was left. */
  say(text: string): void {
    this.rest();
    this.hear(text);
  }

  /** Rests at once, what was left dropped. */
  rest(): void {
    this.shapes = [];
    this.at = 0;
    this.nth = 0;
  }

  /** How open the mouth is after `dt` more seconds (0 shut to 1 wide). */
  step(dt: number): number {
    this.at += dt * PACE;
    const played = Math.min(Math.floor(this.at), this.shapes.length);
    this.shapes.splice(0, played);
    this.at = this.shapes.length ? this.at - played : 0;
    return this.shapes[0] ?? 0;
  }
}
