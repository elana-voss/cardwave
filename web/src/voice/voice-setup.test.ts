// What the line "Voice" and its dialog say of the voice in each of its states; in first run, the download's size
// on this computer's account alone (the account and the server stand-ins, `./account`, `./api/client`).
import { describe, expect, onTestFinished, test, vi } from "vitest";
import { account } from "../account";
import { getSettings, getVoice } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { useLanguage } from "../language/language";
import { dialogSays, lineSays, voiceLine } from "./voice-setup";

vi.mock("../account", () => ({ account: vi.fn() }));
vi.mock("../api/client", () => ({ getSettings: vi.fn(), getVoice: vi.fn() }));

const voices = [
  { id: "alba", name: "Alba", language: "en", set: "Alba MacKenna", license: "CC BY 4.0", credit: "Voice-acted by Alba MacKenna", own: false },
  { id: "marius", name: "Marius", language: "en", set: "Voice donations", license: "CC0", credit: "", own: false },
];
const model = (state: VoiceModel["state"], more: Partial<VoiceModel> = {}): VoiceModel => ({
  size: 192_406_993,
  state,
  done: 0,
  failure: null,
  rate: 24_000,
  voices,
  languages: [],
  reads_in: "English",
  at_provider: false,
  ...more,
});

describe("the voice", () => {
  test("not downloaded, it is set up from the line and downloaded from the dialog", () => {
    expect(lineSays(model("absent"), null)).toEqual({ says: "Not set up", action: "Set up" });
    // In first run, the voice and the size of the download "Confirm" makes.
    expect(lineSays(model("absent"), "marius", true)).toEqual({ says: "Reads replies aloud · Marius (English) · 183.5 MB download", action: "Change" });
    expect(dialogSays(model("absent"))).toEqual({ state: "Not downloaded", action: "Download" });
  });

  test("while it downloads both say how far in whole hundredths, and the dialog cancels it", () => {
    const downloading = model("downloading", { done: 192_406_993 * 0.649 });
    expect(lineSays(downloading, null)).toEqual({ says: "Downloading 64%", action: "Set up" });
    expect(dialogSays(downloading)).toEqual({ state: "64%", action: "Cancel" });
  });

  test("ready, the line names the voice chosen, the first until one is", () => {
    expect(lineSays(model("ready"), null)).toEqual({ says: "Alba · English", action: "Change" });
    expect(lineSays(model("ready"), "marius")).toEqual({ says: "Marius · English", action: "Change" });
    expect(lineSays(model("ready"), "gone")).toEqual({ says: "Alba · English", action: "Change" });
    expect(dialogSays(model("ready"))).toEqual({ state: "Ready", action: null });
  });

  test("the voice's language is named in the app's language", () => {
    onTestFinished(() => useLanguage("en"));
    useLanguage("de", "");
    expect(lineSays(model("ready"), null).says).toBe("Alba · Englisch");
  });
});

test("in first run another account's line says nothing of a download, as only this computer's account downloads", async () => {
  vi.mocked(getVoice).mockResolvedValue(model("absent"));
  vi.mocked(getSettings).mockResolvedValue({ voice: "marius" } as Settings);
  const says = async (local: boolean) => {
    vi.mocked(account).mockResolvedValue({ local } as Awaited<ReturnType<typeof account>>);
    const line = voiceLine(() => document.body, { changed: () => {} });
    line.read();
    await new Promise((settle) => setTimeout(settle, 10));
    return line.node.querySelector(".item-text > .meta")!.textContent;
  };
  expect(await says(true)).toMatch(/download$/);
  expect(await says(false)).not.toMatch(/download/);
});
