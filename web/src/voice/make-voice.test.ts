// The dialog "Make a voice from a recording": a file too short leaves the recording made before in its box,
// and "Make voice" sends that one. The server and the reading of a file are stand-ins.
import { expect, test, vi } from "vitest";
import { makeVoice } from "../api/client";
import { makeVoiceDialog } from "./make-voice";
import { toWav } from "./wav";

vi.mock("../api/client", () => ({ makeVoice: vi.fn() }));
vi.mock("./microphone", () => ({ microphone: vi.fn(async () => ({ getTracks: () => [{ stop() {} }] })) }));
vi.mock("./wav", () => ({ LONGEST: 30, SHORTEST: 3, toWav: vi.fn() }));

/** Chooses `name` in the dialog's file field. */
function choose(dialog: HTMLElement, name: string): void {
  const field = dialog.querySelector<HTMLInputElement>("input[type=file]")!;
  Object.defineProperty(field, "files", { value: [new File(["x"], name)], configurable: true });
  field.dispatchEvent(new Event("change"));
}

test("a file too short leaves the recording made before, which “Make voice” sends", async () => {
  const good = new Blob(["ten seconds"]);
  vi.mocked(toWav).mockResolvedValueOnce({ file: good, seconds: 10 }).mockResolvedValueOnce({ file: new Blob(["one"]), seconds: 1 });
  vi.mocked(makeVoice).mockResolvedValue({ id: "own-1", name: "Evening", language: "", set: "", license: "", credit: { kind: "none" }, own: true });
  const made = vi.fn();
  makeVoiceDialog(document.body, 24_000, made);
  const dialog = document.body.querySelector("dialog")!;
  const box = dialog.querySelector(".recording")!;

  choose(dialog, "long.wav");
  await vi.waitFor(() => expect(box.textContent).toContain("0:10"));
  choose(dialog, "short.wav");
  await vi.waitFor(() => expect(dialog.textContent).toContain("too short"));
  expect(box.textContent).toContain("0:10");
  expect(box.textContent).toContain("Record again");

  dialog.querySelector<HTMLInputElement>("#made-voice-name")!.value = "Evening";
  const make = [...dialog.querySelectorAll("button")].find((button) => button.textContent === "Make voice")!;
  expect(make.disabled).toBe(false);
  make.click();
  await vi.waitFor(() => expect(made).toHaveBeenCalledOnce());
  expect(makeVoice).toHaveBeenCalledWith("Evening", good);
});

test("a file chosen while the microphone records ends the recording, and the recording is not taken after it", async () => {
  class Recorder {
    state = "inactive";
    mimeType = "audio/webm";
    ondataavailable: ((event: { data: Blob }) => void) | null = null;
    onstop: (() => void) | null = null;
    start() {
      this.state = "recording";
    }
    stop() {
      this.state = "inactive";
      setTimeout(() => this.onstop?.(), 0);
    }
  }
  vi.stubGlobal("MediaRecorder", Recorder);
  const chosen = new Blob(["the file"]);
  vi.mocked(toWav).mockReset().mockResolvedValueOnce({ file: chosen, seconds: 8 }).mockResolvedValue({ file: new Blob(["the room"]), seconds: 9 });
  vi.mocked(makeVoice).mockReset().mockResolvedValue({ id: "own-2", name: "File", language: "", set: "", license: "", credit: { kind: "none" }, own: true });
  document.body.replaceChildren();
  makeVoiceDialog(document.body, 24_000, vi.fn());
  const dialog = document.body.querySelector("dialog")!;
  const box = dialog.querySelector(".recording")!;
  [...box.querySelectorAll("button")].find((button) => button.textContent === "Record")!.click();
  await vi.waitFor(() => expect(box.querySelector(".recording-bar")).not.toBeNull());
  choose(dialog, "mine.wav");
  await vi.waitFor(() => expect(box.textContent).toContain("0:08"));
  await new Promise((done) => setTimeout(done, 20));
  expect(box.textContent).toContain("0:08");
  dialog.querySelector<HTMLInputElement>("#made-voice-name")!.value = "File";
  [...dialog.querySelectorAll("button")].find((button) => button.textContent === "Make voice")!.click();
  await vi.waitFor(() => expect(makeVoice).toHaveBeenCalled());
  expect(makeVoice).toHaveBeenCalledWith("File", chosen);
});
