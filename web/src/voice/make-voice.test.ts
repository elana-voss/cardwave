// The dialog "Make a voice from a recording": a file too short leaves the recording made before in its box,
// and "Make voice" sends that one. The server and the reading of a file are stand-ins.
import { expect, test, vi } from "vitest";
import { makeVoice } from "../api/client";
import { makeVoiceDialog } from "./make-voice";
import { toWav } from "./wav";

vi.mock("../api/client", () => ({ makeVoice: vi.fn() }));
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
  vi.mocked(makeVoice).mockResolvedValue({ id: "own-1", name: "Evening", language: "", set: "", license: "", credit: "", own: true });
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
