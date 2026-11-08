// What a line of first run's step 3 says at its right: its percent, "Waiting" behind a download not there yet,
// "Done", and nothing beside "Try again" after a failure; and that a download the server refuses to start is not asked
// for again until "Try again"; and that only the downloads step 2 chose show. The server is a stand-in (`../api/client`).
import { expect, test, vi } from "vitest";
import { changeSettings, downloadSearchModel, downloadVoice, getSearchModel, getSettings, getVoice } from "../api/client";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { clearNotice } from "../dom";
import { remember } from "../storage";
import type { SearchModel } from "../api/generated/SearchModel";
import type { Settings } from "../api/generated/Settings";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { downloadsHeard, downloadsStep, downloadsChosen, firstRunLeft, followDownloads, followsAtStart, stateSays } from "./downloads-step";

vi.mock("../api/client", () => ({
  changeSettings: vi.fn(),
  downloadSearchModel: vi.fn(),
  downloadVoice: vi.fn(),
  getSearchModel: vi.fn(),
  getSettings: vi.fn(),
  getVoice: vi.fn(),
}));

const model = (state: SearchModel["state"], more: Partial<SearchModel> = {}): SearchModel => ({ name: "bge-m3", size: 1000, state, done: 0, failure: null, left: 0, ...more });

test("a download waits for the one before it, then says how far it is, and is done once there", () => {
  expect(stateSays(model("absent"), model("downloading", { done: 640 }))).toBe("Waiting");
  expect(stateSays(model("absent"), model("ready"))).toBe("0%");
  expect(stateSays(model("downloading", { done: 640 }), null)).toBe("64%");
  expect(stateSays(model("ready"), null)).toBe("Done");
  expect(stateSays(model("absent", { failure: { code: "download_failed", error: "no connection", details: {} } }), null)).toBe("");
});

test("a download the server refuses to start is told on its line and asked for again only by “Try again”", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  vi.mocked(getVoice).mockResolvedValue(voice);
  vi.mocked(getSearchModel).mockResolvedValue(model("absent"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice", "search"] } as Settings);
  vi.mocked(downloadVoice).mockRejectedValue(new Error("the disk is full"));
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(step.node.textContent).toContain("the disk is full"));
  // Read anew, as on an event: the refusal stands, and nothing is asked for again.
  step.read();
  await new Promise((settle) => setTimeout(settle, 20));
  expect(downloadVoice).toHaveBeenCalledTimes(1);
  expect(downloadSearchModel).not.toHaveBeenCalled();
  // The voice's line, the first, has "Try again"; the search model's waits.
  const retries = [...step.node.querySelectorAll("button")].filter((button) => button.textContent === "Try again");
  expect(retries.map((button) => button.hidden)).toEqual([false, true]);
  retries[0].click();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(2));
  step.node.remove();
});

test("only the downloads step 2 chose show, and the app opens once they are there", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  vi.mocked(getVoice).mockResolvedValue(voice);
  vi.mocked(getSearchModel).mockResolvedValue(model("ready"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["search"] } as Settings);
  vi.mocked(downloadVoice).mockClear();
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  const open = [...step.node.querySelectorAll("button")].find((button) => button.textContent === "Open Cardwave")!;
  const lines = [...step.node.querySelectorAll<HTMLElement>(".download-line")];
  await vi.waitFor(() => expect(lines.map((line) => line.hidden)).toEqual([true, false]));
  expect(open.disabled).toBe(false);
  expect(downloadVoice).not.toHaveBeenCalled();
  step.node.remove();
});

const notice = () => {
  let node = document.querySelector<HTMLElement>("#toast");
  if (!node) document.body.append((node = Object.assign(document.createElement("div"), { id: "toast" })));
  return node;
};

/** A step whose voice and search model `now` gives, opened at once. */
async function openedWhileDownloading(now: () => [VoiceModel, SearchModel]) {
  vi.mocked(getVoice).mockImplementation(async () => now()[0]);
  vi.mocked(getSearchModel).mockImplementation(async () => now()[1]);
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice", "search"] } as Settings);
  vi.mocked(changeSettings).mockReset().mockResolvedValue({} as Settings);
  vi.mocked(downloadSearchModel).mockReset().mockResolvedValue(undefined as never);
  const opened = vi.fn();
  const step = downloadsStep(opened);
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  const open = [...step.node.querySelectorAll("button")].find((button) => button.textContent === "Open Cardwave")!;
  await vi.waitFor(() => expect(open.disabled).toBe(false));
  open.click();
  await vi.waitFor(() => expect(opened).toHaveBeenCalled());
  step.node.remove();
}

test("“Open Cardwave” opens while a download runs; the next starts after it, and one notice tells when all are there", async () => {
  const voice: VoiceModel = { size: 1000, state: "downloading", done: 100, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  let now: [VoiceModel, SearchModel] = [voice, model("absent")];
  notice().replaceChildren();
  await openedWhileDownloading(() => now);
  now = [{ ...voice, state: "ready" }, model("absent")];
  // The server starts it: from then on it is downloading.
  vi.mocked(downloadSearchModel).mockImplementation(async () => void (now = [{ ...voice, state: "ready" }, model("downloading")]) as never);
  downloadsHeard({ type: "voice" } as ServerEvent);
  await vi.waitFor(() => expect(downloadSearchModel).toHaveBeenCalledTimes(1));
  expect(notice().textContent).toBe("");
  now = [{ ...voice, state: "ready" }, model("ready")];
  downloadsHeard({ type: "search" } as ServerEvent);
  await vi.waitFor(() => expect(notice().textContent).toBe("The downloads are done: Cardwave is fully set up."));
});

test("a download that fails after “Open Cardwave” leaves a notice that stays across screens, with “Try again”", async () => {
  const voice: VoiceModel = { size: 1000, state: "ready", done: 1000, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  let now: [VoiceModel, SearchModel] = [voice, model("downloading", { done: 300 })];
  await openedWhileDownloading(() => now);
  now = [voice, model("absent", { failure: { code: "download_failed", error: "no connection", details: {} } })];
  downloadsHeard({ type: "search" } as ServerEvent);
  await vi.waitFor(() => expect(notice().textContent).toContain("The search model couldn't be downloaded"));
  clearNotice();
  const again = notice().querySelector("button")!;
  expect(again.textContent).toBe("Try again");
  again.click();
  await vi.waitFor(() => expect(downloadSearchModel).toHaveBeenCalledTimes(1));
});

test("a download cut by a restart after “Open Cardwave” goes on at the next start, outside first run, and the list empties once all are there", async () => {
  const voice: VoiceModel = { size: 1000, state: "downloading", done: 100, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  let now: [VoiceModel, SearchModel] = [voice, model("absent")];
  await openedWhileDownloading(() => now);
  expect(changeSettings).not.toHaveBeenCalledWith({ setup_downloads: [] });
  expect(firstRunLeft({ setup_downloads: ["voice", "search"] } as Settings)).toBe(false);
  // The restart: the voice is no longer downloading, and the next start follows the downloads left.
  now = [{ ...voice, state: "absent", done: 0 }, model("absent")];
  vi.mocked(downloadVoice).mockReset().mockImplementation(async () => void (now = [{ ...voice, state: "ready" }, model("ready")]) as never);
  followDownloads();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(1));
  downloadsHeard({ type: "voice" } as ServerEvent);
  await vi.waitFor(() => expect(changeSettings).toHaveBeenCalledWith({ setup_downloads: [] }));
});

test("where a cards folder was chosen, the step says its cards come in once Cardwave opens", async () => {
  vi.mocked(getVoice).mockResolvedValue({ size: 1000, state: "downloading", done: 100, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false });
  vi.mocked(getSearchModel).mockResolvedValue(model("absent"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice"] } as Settings);
  let cards = false;
  const step = downloadsStep(() => {}, () => cards);
  step.read();
  await vi.waitFor(() => expect(step.node.textContent).toContain("10%"));
  const later = [...step.node.querySelectorAll("p")].find((one) => one.textContent === "Your cards come in from the folder once Cardwave opens.")!;
  expect(later.hidden).toBe(true);
  cards = true;
  step.read();
  await vi.waitFor(() => expect(later.hidden).toBe(false));
});

test("the downloads left are followed at any start that does not open first run, a reload at a page's address too", () => {
  const left = { setup_downloads: ["search"] } as Settings;
  expect(followsAtStart(left, "#/library")).toBe(true);
  expect(followsAtStart(left, "")).toBe(true);
  expect(followsAtStart(left, "#/setup")).toBe(false);
  expect(followsAtStart({ setup_downloads: [] } as unknown as Settings, "#/library")).toBe(false);
});

test("a first run that chooses downloads anew forgets an earlier “Open Cardwave” kept in this browser, so a restart comes back to its step", () => {
  remember("setup-opened", "1");
  downloadsChosen();
  expect(firstRunLeft({ setup_downloads: ["voice"] } as Settings)).toBe(true);
});
