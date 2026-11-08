// What a line of first run's step 4 says at its right: its percent, "Waiting" behind a download not there yet,
// "Done", and nothing beside "Try again" after a failure; and that a download the server refuses to start, or takes and leaves absent, is not asked
// for again until "Try again"; that only the downloads chosen show; what can be chosen, and what the button says of
// it (`toDownload`, `downloadText`). The server is a stand-in (`../api/client`).
import { expect, test, vi } from "vitest";
import { changeSettings, downloadSearchModel, downloadVoice, getSearchModel, getSettings, getVoice } from "../api/client";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { clearNotice } from "../dom";
import { remember } from "../storage";
import type { SearchModel } from "../api/generated/SearchModel";
import type { Settings } from "../api/generated/Settings";
import type { VoiceModel } from "../api/generated/VoiceModel";
import type { ErrorBody } from "../api/generated/ErrorBody";
import { downloadText, downloadsHeard, downloadsStep, downloadsChosen, firstRunLeft, followDownloads, followsAtStart, stateSays, toDownload, toMake } from "./downloads-step";

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
  vi.mocked(downloadSearchModel).mockRejectedValue(new Error("the disk is full"));
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(step.node.textContent).toContain("the disk is full"));
  // Read anew, as on an event: the refusal stands, and nothing is asked for again.
  step.read();
  await new Promise((settle) => setTimeout(settle, 20));
  expect(downloadSearchModel).toHaveBeenCalledTimes(1);
  expect(downloadVoice).not.toHaveBeenCalled();
  // The search model's line, the first, has "Try again"; the voice's waits.
  const retries = [...step.node.querySelectorAll("button")].filter((button) => button.textContent === "Try again");
  expect(retries.map((button) => button.hidden)).toEqual([false, true]);
  retries[0].click();
  await vi.waitFor(() => expect(downloadSearchModel).toHaveBeenCalledTimes(2));
  step.node.remove();
});

test("a download the server takes but does not start is tried once and told as failed on its line, until “Try again”", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  vi.mocked(getVoice).mockResolvedValue(voice);
  vi.mocked(getSearchModel).mockResolvedValue(model("ready"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice"] } as Settings);
  vi.mocked(downloadVoice).mockReset().mockResolvedValue(voice);
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(step.node.textContent).toContain("Something went wrong in Cardwave"));
  step.read();
  await new Promise((settle) => setTimeout(settle, 20));
  expect(downloadVoice).toHaveBeenCalledTimes(1);
  [...step.node.querySelectorAll("button")].find((button) => button.textContent === "Try again" && !button.hidden)!.click();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(2));
  await new Promise((settle) => setTimeout(settle, 20));
  expect(downloadVoice).toHaveBeenCalledTimes(2);
  step.node.remove();
});

test("a started download that fails says the server's reason on its line, not a failure of Cardwave", async () => {
  const failure: ErrorBody = { code: "download_failed", error: "connection reset", details: {} };
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  vi.mocked(getVoice).mockReset().mockResolvedValueOnce(voice).mockResolvedValue({ ...voice, failure });
  vi.mocked(getSearchModel).mockResolvedValue(model("ready"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice"] } as Settings);
  vi.mocked(downloadVoice).mockReset().mockResolvedValue(voice);
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(1));
  await vi.waitFor(() => expect(step.node.textContent).toContain("The download failed"));
  expect(step.node.textContent).not.toContain("Something went wrong in Cardwave");
  step.node.remove();
});

/** A stand-in answer the test gives when it chooses. */
const later = <T>() => {
  let give!: (value: T) => void;
  const answer = new Promise<T>((settle) => (give = settle));
  return { answer, give };
};
const settled = () => new Promise((settle) => setTimeout(settle, 20));

test("a read asked before a start answers is not taken for that start's failure, nor starts it again", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  const reads: ReturnType<typeof later<VoiceModel>>[] = [];
  vi.mocked(getVoice).mockReset().mockImplementation(() => (reads.push(later<VoiceModel>()), reads.at(-1)!.answer));
  vi.mocked(getSearchModel).mockResolvedValue(model("ready"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice"] } as Settings);
  const started = later<VoiceModel>();
  vi.mocked(downloadVoice).mockReset().mockReturnValue(started.answer);
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(reads.length).toBe(1));
  reads[0].give(voice);
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(1));
  // An event's read, asked while the start is on its way.
  step.read();
  await vi.waitFor(() => expect(reads.length).toBe(2));
  started.give({ ...voice, state: "downloading" });
  await vi.waitFor(() => expect(reads.length).toBe(3));
  reads[1].give(voice);
  await settled();
  expect(step.node.textContent).not.toContain("Something went wrong");
  expect(downloadVoice).toHaveBeenCalledTimes(1);
  reads[2].give({ ...voice, state: "downloading", done: 500 });
  await vi.waitFor(() => expect(step.node.textContent).toContain("50%"));
  step.node.remove();
});

test("a download cut from outside (a server restart) is started again once, not told as failed", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  const running = { ...voice, state: "downloading" as const };
  vi.mocked(getVoice).mockReset().mockResolvedValueOnce(voice).mockResolvedValueOnce(running).mockResolvedValueOnce(voice).mockResolvedValue(running);
  vi.mocked(getSearchModel).mockResolvedValue(model("ready"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice"] } as Settings);
  vi.mocked(downloadVoice).mockReset().mockResolvedValue(running);
  const step = downloadsStep(() => {});
  step.node.hidden = false;
  document.body.append(step.node);
  step.read();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(1));
  await settled();
  // An event's read sees it absent again, as after a restart: one start more, and no failure.
  step.read();
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(2));
  await settled();
  expect(downloadVoice).toHaveBeenCalledTimes(2);
  expect(step.node.textContent).not.toContain("Something went wrong");
  step.node.remove();
});

test("step 4 starts nothing while it still asks (its bars hidden), even with downloads left in the list", async () => {
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  vi.mocked(getVoice).mockReset().mockResolvedValue(voice);
  vi.mocked(getSearchModel).mockResolvedValue(model("absent"));
  vi.mocked(getSettings).mockResolvedValue({ voice: null, setup_downloads: ["voice", "search"] } as Settings);
  vi.mocked(downloadVoice).mockReset();
  vi.mocked(downloadSearchModel).mockReset();
  const step = downloadsStep(() => {});
  document.body.append(step.node);
  step.read();
  await settled();
  expect(downloadVoice).not.toHaveBeenCalled();
  expect(downloadSearchModel).not.toHaveBeenCalled();
  step.node.remove();
});

test("only the downloads step 4 chose show, and the app opens once they are there", async () => {
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
  await vi.waitFor(() => expect(lines.map((line) => line.hidden)).toEqual([false, true]));
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
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  let now: [VoiceModel, SearchModel] = [voice, model("downloading", { done: 100 })];
  notice().replaceChildren();
  await openedWhileDownloading(() => now);
  now = [voice, model("ready")];
  // The server starts it: from then on it is downloading.
  vi.mocked(downloadVoice).mockReset().mockImplementation(async () => void (now = [{ ...voice, state: "downloading" }, model("ready")]) as never);
  downloadsHeard({ type: "search" } as ServerEvent);
  await vi.waitFor(() => expect(downloadVoice).toHaveBeenCalledTimes(1));
  expect(notice().textContent).toBe("");
  now = [{ ...voice, state: "ready" }, model("ready")];
  downloadsHeard({ type: "voice" } as ServerEvent);
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
  const voice: VoiceModel = { size: 1000, state: "absent", done: 0, failure: null, rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  let now: [VoiceModel, SearchModel] = [voice, model("downloading", { done: 100 })];
  await openedWhileDownloading(() => now);
  expect(changeSettings).not.toHaveBeenCalledWith({ setup_downloads: [] });
  expect(firstRunLeft({ setup_downloads: ["voice", "search"] } as Settings)).toBe(false);
  // The restart: the search model is no longer downloading, and the next start follows the downloads left.
  now = [voice, model("absent")];
  vi.mocked(downloadSearchModel).mockReset().mockImplementation(async () => void (now = [{ ...voice, state: "ready" }, model("ready")]) as never);
  followDownloads();
  await vi.waitFor(() => expect(downloadSearchModel).toHaveBeenCalledTimes(1));
  downloadsHeard({ type: "search" } as ServerEvent);
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

test("first run downloads what its switches chose, where it is not there, on this computer's account alone", () => {
  const of = (state: "absent" | "downloading" | "ready", failure: ErrorBody | null = null) => ({ name: "bge-m3", size: 10, state, done: 0, failure, left: 0 });
  const voice = { ...of("absent"), rate: 22050, voices: [], languages: [], reads_in: "English", at_provider: false };
  const both = { voice: true, search: true };
  expect(toDownload(true, voice, of("ready"), both).map((one) => one.kind)).toEqual(["voice"]);
  // One downloading, or failed, is seen through too.
  expect(toDownload(true, { ...voice, state: "downloading" }, of("absent", { code: "download_failed", error: "no connection", details: {} }), both).map((one) => one.name)).toEqual(["Search", "Voice"]);
  expect(toDownload(true, { ...voice, state: "ready" }, of("ready"), both)).toEqual([]);
  expect(toDownload(false, voice, of("absent"), both)).toEqual([]);
  // As step 4 opens: the search model chosen, the voice not.
  expect(toDownload(true, voice, of("absent"), { voice: false, search: true }).map((one) => one.kind)).toEqual(["search"]);
  expect(toDownload(true, voice, of("absent"), { voice: false, search: false })).toEqual([]);
  // A model not read yet, or whose read failed, keeps step 4 with its line (and its error), and is not downloaded.
  expect(toMake(true, null, of("ready")).map((one) => one.kind)).toEqual(["voice"]);
  expect(toDownload(true, null, of("absent"), both).map((one) => one.kind)).toEqual(["search"]);
});

test("step 4's main button names the size of what it downloads, else it opens the app", () => {
  const voice = { name: "Voice", size: 192_406_993 };
  const search = { name: "Search", size: 634_553_760 };
  expect(downloadText([voice, search])).toBe("Download (788.7 MB)");
  expect(downloadText([search])).toBe("Download (605.2 MB)");
  expect(downloadText([])).toBe("Open Cardwave");
});
