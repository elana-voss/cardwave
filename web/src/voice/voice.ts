// Reading aloud: a text sent to the server's voice (`speak`, server/src/api/voice.rs) a sentence at a time
// (`sentences`), each answer, 16-bit samples as they are made, played as it comes, each piece after the one
// before (Web Audio), so the first words are heard a fraction of a second after the asking and the next sentence
// is made while the one before plays. `spoken` is what of a message is read: its text without the asterisks of
// its narration (narration.ts). The server makes it faster or slower (Settings › Voices, "Speed").
//
// A stalled voice recovers by itself: a sentence whose sound stops coming for `STALL_MS` (or does not begin
// within `FIRST_MS`, as the server answers only once the model is loaded and the reading before is done) is
// asked for again, once, its samples already played skipped; the second time the reading ends, saying so. Sound the window had put to sleep is woken at each piece.
// One reading at a time in the page: a new one stops the one before. Stopping hangs up too, so the server
// stops making it. `readAloud` is called from a click, as a page may play sound only after one; a window that
// cannot play sound at all ends the reading at once, saying so.
import { speak } from "../api/client";
import { reason } from "../dom";
import { paragraphs, pieces } from "../narration";
import { wording } from "../language/language";

/** How long a sentence's sound may stop coming before it is asked for again. */
export const STALL_MS = 8000;
/** How long a sentence's sound may take to begin. */
export const FIRST_MS = 60_000;

/** A message's text as it is read aloud: without the asterisks of its narration. */
export const spoken = (text: string) =>
  paragraphs(text)
    .map((paragraph) => pieces(paragraph).map((piece) => piece.text).join(""))
    .join("\n\n");

/** A text cut into its sentences: after a full stop, a question or an exclamation mark (and the quote that closes it), and at each line's end. */
export const sentences = (text: string): string[] =>
  text
    .split(/(?<=[.!?…]["'”’»)\]]*)\s+|\n+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);

/** Reads 16-bit little-endian samples from the pieces they come in, a byte left over kept for the next. */
export function pcm(): (bytes: Uint8Array) => Float32Array<ArrayBuffer> {
  let left: number | null = null;
  return (bytes) => {
    let all = bytes;
    if (left !== null) {
      all = new Uint8Array(bytes.length + 1);
      all[0] = left;
      all.set(bytes, 1);
    }
    const count = Math.floor(all.length / 2);
    left = all.length % 2 ? all[all.length - 1] : null;
    const view = new DataView(all.buffer, all.byteOffset, count * 2);
    const samples = new Float32Array(count);
    for (let at = 0; at < count; at++) samples[at] = view.getInt16(at * 2, true) / 32768;
    return samples;
  };
}

/** The reading that plays, and what stops it. */
let playing: (() => void) | null = null;

/** How loud the reading that plays is heard now, where one plays. */
let heard: (() => number) | null = null;

/** How loud the reading is heard now: the root mean square of its last samples, 0 (none plays) to 1. */
export const loudness = (): number => heard?.() ?? 0;

/** Stops the reading that plays, if one does. */
export const stopReading = () => playing?.();

/** Whose voice reads: the voice `voice`, else the voice of the card `card`, else the account's. */
export type Reader = { voice?: string; card?: number };

/** What a sentence's sound did: came to its end, or stopped coming. */
type Heard = "ended" | "stalled";

/**
 * Reads `text` aloud at `rate` samples a second, in the voice `reader` names, after stopping the reading
 * before. `ended` is called once: when it has been heard to its end, when it is stopped (with nothing), or when
 * it failed (with why). Answers what stops it.
 */
export function readAloud(text: string, rate: number, ended: (why?: string) => void, reader: Reader = {}): () => void {
  playing?.();
  let sound: AudioContext;
  try {
    sound = new AudioContext({ sampleRate: rate });
  } catch (error) {
    ended(wording("voice-this-window-cannot-play", { reason: reason(error) }));
    return () => {};
  }
  // Every piece is played through `meter`, which tells how loud it is heard.
  const meter = sound.createAnalyser();
  meter.fftSize = 1024;
  meter.connect(sound.destination);
  const last = new Float32Array(meter.fftSize);
  heard = () => {
    meter.getFloatTimeDomainData(last);
    return Math.sqrt(last.reduce((sum, sample) => sum + sample * sample, 0) / last.length);
  };
  let hangUp = new AbortController();
  let over = false;
  const stop = (why?: string) => {
    if (over) return;
    over = true;
    hangUp.abort();
    void sound.close();
    if (playing === stop) {
      playing = null;
      heard = null;
    }
    ended(why);
  };
  playing = stop;
  let at = 0;
  /** The samples of the sentence being read that have been played, which its second asking skips. */
  let played = 0;
  /** Plays a sentence's sound as it comes, after the first `skip` samples; answers whether it came to its end or stalled. */
  const play = async (sentence: string, skip = 0): Promise<Heard> => {
    hangUp = new AbortController();
    const asked = hangUp;
    let watch: ReturnType<typeof setTimeout> | undefined;
    let stalled = false;
    const wait = (ms: number) => {
      clearTimeout(watch);
      watch = setTimeout(() => {
        stalled = true;
        asked.abort();
      }, ms);
    };
    wait(FIRST_MS);
    played = 0;
    try {
      const answer = await speak({ text: sentence, ...reader }, asked.signal);
      const body = answer.body!.getReader();
      const read = pcm();
      for (;;) {
        const { value, done } = await body.read();
        if (done || over) return "ended";
        wait(STALL_MS);
        const all = read(value);
        const samples = all.subarray(Math.min(all.length, Math.max(0, skip - played)));
        played += all.length;
        if (!samples.length) continue;
        if (sound.state !== "running") void sound.resume();
        const buffer = sound.createBuffer(1, samples.length, rate);
        buffer.copyToChannel(samples, 0);
        const source = sound.createBufferSource();
        source.buffer = buffer;
        source.connect(meter);
        // A piece that comes late starts a moment from now; one in time right after the one before.
        at = Math.max(at, sound.currentTime + 0.05);
        source.start(at);
        at += buffer.duration;
      }
    } catch (error) {
      if (stalled) return "stalled";
      throw error;
    } finally {
      clearTimeout(watch);
    }
  };
  void (async () => {
    try {
      for (const sentence of sentences(text)) {
        if (over) return;
        if ((await play(sentence)) === "stalled" && !over && (await play(sentence, played)) === "stalled") {
          return stop(wording("voice-the-voice-stopped-answering"));
        }
      }
      // Ended when what was given has been played.
      if (!over) setTimeout(() => stop(), Math.max(0, at - sound.currentTime) * 1000);
    } catch (error) {
      if (!over) stop(reason(error));
    }
  })();
  return () => stop();
}
