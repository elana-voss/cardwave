// Settings › Voices while Voice is at a provider: the provider's voices, each with its model under its name, tried
// without a download, and the one ticked stored for the account (the account and the server stand-ins).
import { expect, test, vi } from "vitest";
import { account } from "../account";
import { changeSettings, getCharacterVoices, getSettings, getVoice } from "../api/client";
import type { Settings } from "../api/generated/Settings";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { voicesView } from "./voices";

vi.mock("../account", () => ({ account: vi.fn() }));
vi.mock("../api/client", () => ({ getVoice: vi.fn(), getSettings: vi.fn(), getCharacterVoices: vi.fn(), changeSettings: vi.fn(), listCards: vi.fn() }));

const voice = (name: string) => ({ id: `at:${name}`, name, language: "", set: "tts-1", license: "", credit: { kind: "none" as const }, own: false });
const model: VoiceModel = { size: 1, state: "absent", done: 0, failure: null, rate: 24_000, voices: [voice("alloy"), voice("echo")], languages: [], reads_in: "English", at_provider: true };
const settings = { voice: "at:echo", voice_speed: 100 } as Settings;

test("at a provider the page lists its voices, tried without a download, and stores the one ticked", async () => {
  vi.mocked(account).mockResolvedValue({ local: true } as Awaited<ReturnType<typeof account>>);
  vi.mocked(getVoice).mockResolvedValue(model);
  vi.mocked(getSettings).mockResolvedValue(settings);
  // A character's voice of this computer is not read at the provider: its field shows the account's.
  vi.mocked(getCharacterVoices).mockResolvedValue([{ card_id: 1, name: "Mira", title: "Mira", voice: "marius" }]);
  vi.mocked(changeSettings).mockResolvedValue({ ...settings, voice: "at:alloy" });
  const page = document.body.appendChild(voicesView().node);
  await vi.waitFor(() => expect(page.querySelectorAll(".item-voice")).toHaveLength(2));

  const lines = [...page.querySelectorAll(".item-voice")];
  expect(lines.map((line) => line.querySelector(".item-text")!.textContent)).toEqual(["alloytts-1", "echotts-1"]);
  expect(lines[1].querySelector("input")!.checked).toBe(true);
  expect(lines[0].querySelector("button")!.disabled).toBe(false);
  expect(page.textContent).not.toContain("Make a voice from a recording");
  expect(page.textContent).not.toContain("Voice model");
  expect(page.querySelector(".select-words")!.textContent).toBe("echo");

  lines[0].querySelector("input")!.click();
  await vi.waitFor(() => expect(changeSettings).toHaveBeenCalledWith({ voice: "at:alloy" }));
});

test("a character of a card that names nothing is shown under the page's word for it", async () => {
  vi.mocked(account).mockResolvedValue({ local: true } as Awaited<ReturnType<typeof account>>);
  vi.mocked(getVoice).mockResolvedValue(model);
  vi.mocked(getSettings).mockResolvedValue(settings);
  vi.mocked(getCharacterVoices).mockResolvedValue([{ card_id: 1, name: "Mira", title: "", voice: "marius" }]);
  const page = document.body.appendChild(voicesView().node);
  await vi.waitFor(() => expect(page.textContent).toContain("Mira"));
  expect(page.textContent).toContain("Untitled");
});
