// What a message reads aloud, cut into its sentences, the sound the server sends taken as it comes, and a
// sentence whose sound stalls asked for again.
import { afterEach, describe, expect, test, vi } from "vitest";

const asked: { text: string; signal: AbortSignal }[] = [];
/** The sound each asking sends, as 16-bit samples, before its answer stalls; none where it is not given. */
const sends: number[][] = [];
vi.mock("../api/client", () => ({
  // Each reading's answer sends what `sends` gives it, then never ends: the voice stalls.
  speak: (text: { text: string }, signal: AbortSignal) => {
    const samples = sends[asked.length] ?? [];
    asked.push({ text: text.text, signal });
    return Promise.resolve({
      body: new ReadableStream({
        start: (c) => {
          if (samples.length) c.enqueue(new Uint8Array(Int16Array.from(samples).buffer));
          signal.addEventListener("abort", () => c.error(new DOMException("aborted", "AbortError")));
        },
      }),
    });
  },
}));

const { FIRST_MS, STALL_MS, loudness, pcm, readAloud, sentences, spoken, stopReading } = await import("./voice");

/** A Web Audio that plays nothing, and the first sample of each piece it was given. */
function sound(): number[] {
  const heard: number[] = [];
  vi.stubGlobal("AudioContext", class {
    state = "running";
    currentTime = 0;
    destination = {};
    close = () => Promise.resolve();
    createBuffer = () => ({ duration: 0, copyToChannel: (samples: Float32Array) => heard.push(Math.round(samples[0] * 32768)) });
    createBufferSource = () => ({ connect: () => {}, start: () => {} });
    // What is heard now: a wave at half of full strength.
    createAnalyser = () => ({ fftSize: 0, connect: () => {}, getFloatTimeDomainData: (into: Float32Array) => into.forEach((_, at) => (into[at] = at % 2 ? 0.5 : -0.5)) });
  });
  return heard;
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
  asked.length = 0;
  sends.length = 0;
});

describe("reading aloud", () => {
  test("a message is read without the asterisks of its narration", () => {
    expect(spoken("*She smiles.* Come in.\n\n*The door shuts.*")).toBe("She smiles. Come in.\n\nThe door shuts.");
  });

  test("a text is read a sentence at a time, a quote that closes one kept with it", () => {
    expect(sentences("She smiles. “Come in!” Is it late?\n\nThe door shuts… Then 3.5 seconds")).toEqual([
      "She smiles.",
      "“Come in!”",
      "Is it late?",
      "The door shuts…",
      "Then 3.5 seconds",
    ]);
  });

  test("the sound's samples are read across the pieces it comes in, a sample split between two too", () => {
    const read = pcm();
    // 16384 (0x4000) and -32768 (0x8000), little-endian, the second split after its first byte.
    expect(Array.from(read(new Uint8Array([0x00, 0x40, 0x00])))).toEqual([0.5]);
    expect(Array.from(read(new Uint8Array([0x80])))).toEqual([-1]);
    expect(Array.from(read(new Uint8Array([])))).toEqual([]);
  });

  test("a page that cannot play sound says so, and the reading is over", () => {
    // This page has no Web Audio, as a browser may refuse it.
    const ended = vi.fn();
    readAloud("Hello.", 24_000, ended);
    expect(ended).toHaveBeenCalledOnce();
    expect(ended.mock.calls[0][0]).toBeTruthy();
  });

  test("a sentence whose sound stalls is asked for once more, then the reading ends saying so", async () => {
    vi.useFakeTimers();
    sound();
    const ended = vi.fn();
    readAloud("First one. Second one.", 24_000, ended, { card: 3 });
    await vi.advanceTimersByTimeAsync(0);
    expect(asked.map((one) => one.text)).toEqual(["First one."]);
    // Its first sound may take long, the model loading.
    await vi.advanceTimersByTimeAsync(STALL_MS);
    expect(asked).toHaveLength(1);
    await vi.advanceTimersByTimeAsync(FIRST_MS - STALL_MS);
    expect(asked[0].signal.aborted).toBe(true);
    expect(asked.map((one) => one.text)).toEqual(["First one.", "First one."]);
    expect(ended).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(FIRST_MS);
    expect(ended).toHaveBeenCalledExactlyOnceWith("The voice stopped answering. Try again, or choose another voice in Settings › Voices.");
    expect(asked).toHaveLength(2);
  });

  test("a sentence asked for again goes on after what was played of it", async () => {
    vi.useFakeTimers();
    const heard = sound();
    // The first asking sends two samples and stalls; the second sends the sentence from its start.
    sends.push([100, 200], [100, 200, 300, 400]);
    readAloud("First one.", 24_000, () => {});
    await vi.advanceTimersByTimeAsync(STALL_MS);
    expect(asked).toHaveLength(2);
    expect(heard).toEqual([100, 300]);
  });

  test("how loud the reading is heard now is told while it plays, and nothing once it is stopped", async () => {
    vi.useFakeTimers();
    sound();
    stopReading();
    expect(loudness()).toBe(0);
    const stop = readAloud("First one.", 24_000, () => {});
    expect(loudness()).toBeCloseTo(0.5);
    stop();
    expect(loudness()).toBe(0);
  });
});
