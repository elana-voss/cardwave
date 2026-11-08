// The microphone: words at each pause while it records, a recording the browser ends itself, and a model removed
// while it records (stand-ins for the microphone, the page's sound, the server and the WAV), and where the words dictated go into the message field.
import { beforeEach, expect, test, vi } from "vitest";
import { getDictation, hear } from "../api/client";
import { dictateButton, inserted } from "./dictate";

vi.mock("../api/client", () => ({ getDictation: vi.fn(), hear: vi.fn() }));
vi.mock("../dom", async (original) => ({ ...(await original<typeof import("../dom")>()), announce: vi.fn() }));
vi.mock("../voice/wav", () => ({ resampled: vi.fn(async (samples: Float32Array) => samples), wav: vi.fn(() => new Blob()) }));

const RATE = 16_000;
const stopped = vi.fn();
const tracks: { stop: () => void; onended: (() => void) | null }[] = [];
const sounds: FakeSound[] = [];
const node = () => ({ connect() {}, disconnect() {} });
class FakeSound {
  sampleRate = RATE;
  destination = {};
  taker = { ...node(), onaudioprocess: null as ((event: unknown) => void) | null };
  constructor() {
    sounds.push(this);
  }
  resume() {}
  close() {}
  createMediaStreamSource = node;
  createScriptProcessor() {
    return this.taker;
  }
  /** `seconds` of sound as loud as `level`, in pieces of 0.1 s. */
  play(level: number, seconds: number) {
    for (let at = 0; at < seconds * 10; at++) this.taker.onaudioprocess?.({ inputBuffer: { getChannelData: () => new Float32Array(RATE / 10).fill(level) } });
  }
}

beforeEach(() => {
  sounds.length = 0;
  tracks.length = 0;
  stopped.mockClear();
  vi.mocked(hear).mockReset();
  vi.stubGlobal("AudioContext", FakeSound);
  const getUserMedia = vi.fn(async () => {
    const track = { stop: stopped, onended: null };
    tracks.push(track);
    return { getTracks: () => [track] };
  });
  Object.defineProperty(navigator, "mediaDevices", { configurable: true, value: { getUserMedia } });
  vi.mocked(getDictation).mockResolvedValue({ name: "Whisper large-v3-turbo", size: 1, state: "ready", done: 0, failure: null });
});

const settled = () => new Promise((done) => setTimeout(done, 0));
const microphone = async () => {
  const field = document.createElement("textarea");
  const { node } = dictateButton(field);
  document.body.append(field, node);
  await settled();
  return { field, button: node };
};

test("the words said up to a pause go in while it records, and the rest when it stops", async () => {
  vi.mocked(hear).mockResolvedValueOnce({ text: "Hello." }).mockResolvedValueOnce({ text: "Still here." });
  const { field, button } = await microphone();
  button.click();
  await settled();
  sounds[0].play(0.2, 1);
  sounds[0].play(0, 0.6);
  await settled();
  expect(field.value).toBe("Hello.");
  expect(button.title).toBe("Stop dictating");
  sounds[0].play(0.2, 0.5);
  button.click();
  expect(button.disabled).toBe(true);
  await settled();
  await settled();
  expect(field.value).toBe("Hello. Still here.");
  expect(button.title).toBe("Dictate");
  expect(button.disabled).toBe(false);
});

test("a recording the browser ends lets the microphone go, and the next press records again", async () => {
  vi.mocked(hear).mockResolvedValue({ text: "Hello." });
  const { field, button } = await microphone();
  expect(button.hidden).toBe(false);
  button.click();
  await settled();
  expect(button.classList.contains("recording")).toBe(true);
  sounds[0].play(0.2, 0.5);
  tracks[0].onended?.();
  await settled();
  expect(stopped).toHaveBeenCalled();
  expect(button.classList.contains("recording")).toBe(false);
  expect(field.value).toBe("Hello.");
  button.click();
  await settled();
  expect(sounds).toHaveLength(2);
  expect(button.title).toBe("Stop dictating");
});

test("a model removed while recording hides the microphone once heard", async () => {
  vi.mocked(hear).mockRejectedValue(new Error("dictation is not set up"));
  const { button } = await microphone();
  button.click();
  await settled();
  sounds[0].play(0.2, 0.5);
  vi.mocked(getDictation).mockResolvedValue({ name: "Whisper large-v3-turbo", size: 1, state: "absent", done: 0, failure: null });
  button.click();
  await settled();
  await settled();
  expect(button.hidden).toBe(true);
});

test("the words dictated go in at the cursor, a space between them and the words beside", () => {
  expect(inserted("", 0, 0, "Hello.")).toEqual({ value: "Hello.", at: 6 });
  expect(inserted("Say it", 6, 6, "again.")).toEqual({ value: "Say it again.", at: 13 });
  expect(inserted("Say  now", 4, 4, "it")).toEqual({ value: "Say it now", at: 6 });
  expect(inserted("Say it now", 4, 6, "this")).toEqual({ value: "Say this now", at: 8 });
});
