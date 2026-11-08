// Dictation's pauses: the microphone's sound, as the page gets it piece by piece, cut where the speaker pauses, so
// each stretch said can be heard while the recording goes on (dictate.ts). A pause is `PAUSE` seconds that stay ten
// times (20 dB) softer than the loudest moment of the stretch, or below the server's line of silence (`LOUD`,
// `whisper::LOUD`); a stretch without a moment above that line is speech not yet begun and is never sent, only its
// last `BEFORE` seconds kept, so the first word is not cut off; nor is a stretch ten times softer than the loudest
// stretch sent before, the room's noise after a pause, which Whisper hears as "Thank you." (live) (Claude). Trap: a busy room seldom drops tenfold, so
// there the words may come only when the recording ends, as before.

/** The loudness (root mean square, of 1) below which there is no speech: the server's (-60 dBFS). */
const LOUD = 0.001;
/** How much softer than the stretch's loudest moment a pause is. */
const SOFTER = 10;
/** How long a pause lasts, in seconds. */
const PAUSE = 0.6;
/** How much of the sound before speech is kept, in seconds. */
const BEFORE = 0.3;

/** The recording at `rate` samples a second, cut at its pauses. */
export class Pauses {
  private pieces: Float32Array[] = [];
  private loudest = 0;
  private quiet = 0;
  /** The loudest moment of the stretches sent: the speaker's voice. */
  private voice = 0;

  constructor(private readonly rate: number) {}

  /** Takes `piece` (copied); answers the stretch said, where `piece` ends it with a pause. */
  add(piece: Float32Array): Float32Array<ArrayBuffer> | null {
    const level = Math.sqrt(piece.reduce((sum, x) => sum + x * x, 0) / Math.max(1, piece.length));
    this.pieces.push(piece.slice());
    if (this.loudest < LOUD) {
      if (level >= LOUD) this.loudest = level;
      else this.keepLast(BEFORE * this.rate);
      return null;
    }
    if (level >= LOUD && level >= this.loudest / SOFTER) {
      this.loudest = Math.max(this.loudest, level);
      this.quiet = 0;
      return null;
    }
    this.quiet += piece.length;
    return this.quiet >= PAUSE * this.rate ? this.said() : null;
  }

  /** What is left at the recording's end, where it holds speech. */
  rest(): Float32Array<ArrayBuffer> | null {
    const said = this.loudest >= LOUD ? this.said() : null;
    this.pieces = [];
    return said;
  }

  /** The stretch up to here, where it is as loud as the voice; the next begins. */
  private said(): Float32Array<ArrayBuffer> | null {
    const loudest = this.loudest;
    const said = this.take();
    if (loudest < this.voice / SOFTER) return null;
    this.voice = Math.max(this.voice, loudest);
    return said;
  }

  private take(): Float32Array<ArrayBuffer> {
    const said = new Float32Array(this.pieces.reduce((sum, piece) => sum + piece.length, 0));
    let at = 0;
    for (const piece of this.pieces) {
      said.set(piece, at);
      at += piece.length;
    }
    this.pieces = [];
    this.loudest = 0;
    this.quiet = 0;
    return said;
  }

  /** Drops the oldest pieces while the rest still holds `samples`. */
  private keepLast(samples: number) {
    let kept = this.pieces.reduce((sum, piece) => sum + piece.length, 0);
    while (this.pieces.length > 1 && kept - this.pieces[0].length >= samples) kept -= this.pieces.shift()!.length;
  }
}
