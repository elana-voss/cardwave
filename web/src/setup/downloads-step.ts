// First run's fourth step, "Downloads" (board "First run · step 3", its third there): a line per download step 2
// chose (the account's `setup_downloads`), the voice and the search model, each with its size, a bar and at its right its percent, "Waiting", or "Done" with the blue tick;
// a failed one says why in red under its bar, with "Retry" in its percent's place. One downloads at a time, in
// the lines' order (`next`): the next starts once the one before is there; after a failure nothing starts until
// "Retry"; a download the server refused to start counts as failed, with the refusal as why (`refused`), so it is
// not asked for again until "Retry". The account's list of first run's downloads not through (`setup_downloads`,
// which step 3's "Continue" set) brings a start back to this step until "Open Cardwave", which opens the app at
// any time and is kept in the browser (`OPENED`; `firstRunLeft`); the step then goes on downloading from outside
// the screen (`following`, fed the server's events by main.ts through `downloadsHeard`), and so does a start after
// it while the list holds any (`followDownloads`, which resumes one a restart cut): one notice when all are there,
// which empties the list, and one that stays across screens with "Try again" when one fails. Only this computer's
// account downloads, so only it comes here.
// `read` asks the server for both states anew, on their events and when the server is heard again.
import { wording } from "../language/language";
import { failedWords } from "../language/errors";
import { changeSettings, downloadSearchModel, downloadVoice, getSearchModel, getSettings, getVoice } from "../api/client";
import type { SearchModel } from "../api/generated/SearchModel";
import type { SetupDownload } from "../api/generated/SetupDownload";
import type { VoiceModel } from "../api/generated/VoiceModel";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { announce, el, failure, item, newest, noticeBox, reason, told } from "../dom";
import { bytes } from "../format";
import { percent } from "../models/downloaded";
import { icon } from "../icons";
import { remember, remembered } from "../storage";
import type { Settings } from "../api/generated/Settings";

type Model = VoiceModel | SearchModel;
/** A model as its line shows it: why it failed in words. */
type Shown = { state: Model["state"]; done: number; size: number; failure: string | null };
type Kind = SetupDownload;

/** The step that goes on downloading after "Open Cardwave", reading anew when told; none while nothing is left. */
let follower: (() => void) | null = null;

/** Kept in the browser once "Open Cardwave" left first run with its downloads still going on. */
const OPENED = "setup-opened";

/** Whether a start goes back to first run's last step: its downloads are not through and "Open Cardwave" was not pressed. */
export function firstRunLeft(settings: Pick<Settings, "setup_downloads">): boolean {
  return settings.setup_downloads.length > 0 && remembered(OPENED) !== "1";
}

/** Step 3 chose first run's downloads: an "Open Cardwave" kept in this browser from an earlier first run is forgotten. */
export function downloadsChosen(): void {
  remember(OPENED, "");
}

/** Whether a start at the address `hash` follows first run's downloads left: any start but one that opens first run, which downloads them itself. */
export function followsAtStart(settings: Pick<Settings, "setup_downloads">, hash: string): boolean {
  return settings.setup_downloads.length > 0 && !hash.startsWith("#/setup");
}

/** At a start after "Open Cardwave" with first run's downloads not through: goes on downloading and tells how it ended. */
export function followDownloads(): void {
  downloadsStep(() => {}).follow();
}

/** Tells the downloads that go on after first run what the server did. */
export function downloadsHeard(event: ServerEvent): void {
  if (follower && (event.type === "voice" || event.type === "search" || event.type === "hello")) follower();
}

/** What a download's line says at its right: its percent, "Waiting", "Done", or nothing beside "Retry". */
export function stateSays(model: Omit<Shown, "failure"> & { failure: unknown }, before: Model | null): string {
  if (model.state === "ready") return wording("setup-done");
  if (model.state === "downloading") return wording("setup-percent", { percent: String(percent(model)) });
  if (model.failure) return "";
  return before && before.state !== "ready" ? wording("setup-waiting") : wording("setup-percent", { percent: String(percent(model)) });
}

/** A download's line, with its bar, what it says at its right and why it failed. */
function downloadLine(label: string, retrying: string, retry: () => void) {
  const about = el("span", { className: "meta" });
  const bar = el("div", { className: "bar f-none mt-8 on-box download-bar" }, el("div"));
  const wrong = el("div", { className: "download-wrong fs-small" });
  const state = el("span", { className: "meta download-state" });
  const again = el("button", { type: "button", className: "btn btn-secondary on-box", hidden: true, ariaLabel: retrying, onclick: retry }, wording("setup-try-again"));
  const node = item(label, el("div", { className: "download-text flex f-col" }, about, bar, wrong), state);
  node.append(again);
  node.classList.add("download-line");
  const show = (model: Shown, says: string, before: Model | null) => {
    about.textContent = says;
    (bar.firstElementChild as HTMLElement).style.width = `${model.state === "ready" ? 100 : percent(model)}%`;
    const said = stateSays(model, before);
    state.replaceChildren(...(model.state === "ready" ? [icon("check", 14), wording("setup-done-mark")] : [said]));
    const failed = model.state !== "ready" && model.state !== "downloading" ? model.failure : null;
    wrong.replaceChildren(...(failed ? [failure(failed)] : []));
    again.hidden = !failed;
    state.hidden = !!failed;
  };
  return { node, show };
}

/** Makes the step; `open` opens the app once the downloads are through; `cards`, whether a folder of cards waits for it. */
export function downloadsStep(open: () => void, cards: () => boolean = () => false): { node: HTMLElement; read(): void; follow(): void } {
  let voice: VoiceModel | null = null;
  let search: SearchModel | null = null;
  let voiceName = "";
  /** The downloads step 2 chose, in the lines' order. */
  let chosen: Kind[] = [];
  /** A download asked for and not yet answered: no second one starts meanwhile. */
  let starting = false;
  /** Why the server refused to start a download, until "Retry". */
  const refused: Record<Kind, string | null> = { voice: null, search: null };
  // The shared place for why, which takes no room while it says nothing (no gap of its own under the lines).
  const failed = noticeBox();
  const later = el("p", { className: "hint", hidden: true }, wording("setup-cards-later"));
  const asks: Record<Kind, () => Promise<unknown>> = { voice: downloadVoice, search: downloadSearchModel };
  const start = (kind: Kind) => {
    starting = true;
    refused[kind] = null;
    asks[kind]()
      .catch((error) => (refused[kind] = told(error)))
      .finally(() => {
        starting = false;
        read();
      });
  };
  /** The model as its line has it: a refusal is its failure while it is not downloading. */
  const seen = (model: Model, kind: Kind): Shown => ({
    state: model.state,
    done: model.done,
    size: model.size,
    failure: (model.state === "absent" && refused[kind]) || failedWords(model.failure),
  });
  const voiceLine = downloadLine(wording("setup-voice"), wording("setup-try-voice-again"), () => start("voice"));
  const searchLine = downloadLine(wording("setup-search"), wording("setup-try-search-again"), () => start("search"));
  const openButton = el("button", { type: "button", className: "btn btn-primary btn-lg" }, wording("setup-open"));
  /** Opened before all were there: the step goes on downloading and tells how it ended. */
  let following = false;
  /** The download whose failure the notice told, until "Try again". */
  let warned: Kind | null = null;
  openButton.onclick = () => {
    const through = !!voice && !!search && chosen.every((kind) => (kind === "voice" ? voice : search)!.state === "ready");
    if (!through) {
      remember(OPENED, "1");
      open();
      return follow();
    }
    void changeSettings({ setup_downloads: [] }).then(open, (error) => failed.replaceChildren(failure(reason(error))));
  };
  /** Goes on downloading outside the screen and tells how it ended. */
  const follow = () => {
    following = true;
    follower = read;
    read();
  };
  const node = el("div", { className: "setup-step flex f-col g-28", hidden: true }, el("div", { className: "group" }, voiceLine.node, searchLine.node), later, failed, el("div", { className: "setup-actions flex ai-c g-10 wrap" }, openButton));

  /** Starts the first download that is not there, unless one runs, is being asked for, or failed. */
  const next = () => {
    if (!voice || !search || starting || !(node.isConnected || following)) return;
    const downloads: [Shown, Kind][] = chosen.map((kind) => [kind === "voice" ? seen(voice!, kind) : seen(search!, kind), kind]);
    const first = downloads.find(([model]) => model.state !== "ready");
    if (!first || first[0].state === "downloading" || first[0].failure) return;
    start(first[1]);
  };
  const draw = () => {
    later.hidden = !cards();
    if (!voice || !search) return;
    voiceLine.show(seen(voice, "voice"), `${voiceName} · ${bytes(voice.size)}`, null);
    searchLine.show(seen(search, "search"), `${search.name} · ${bytes(search.size)}`, chosen.includes("voice") ? voice : null);
    voiceLine.node.hidden = !chosen.includes("voice");
    searchLine.node.hidden = !chosen.includes("search");
  };
  /** After "Open Cardwave": one notice when all are there, one that stays with "Try again" when one failed. */
  const tell = () => {
    const downloads = chosen.map((kind) => [kind, seen(kind === "voice" ? voice! : search!, kind)] as const);
    const broken = downloads.find(([, model]) => model.state !== "downloading" && model.state !== "ready" && model.failure);
    if (broken) {
      const [kind, model] = broken;
      if (warned === kind) return;
      warned = kind;
      const again = async () => {
        warned = null;
        start(kind);
      };
      announce(kind === "voice" ? wording("setup-voice-failed", { why: model.failure! }) : wording("setup-search-failed", { why: model.failure! }), again, "stays", wording("setup-try-again"));
    } else if (downloads.every(([, model]) => model.state === "ready")) {
      following = false;
      follower = null;
      announce(wording("setup-downloads-done"));
      // Not emptied (the server unheard): the next start follows again, finds all there and tells it once more.
      void changeSettings({ setup_downloads: [] }).then(() => remember(OPENED, ""), () => undefined);
    }
  };
  const order = newest();
  const read = () => {
    const mine = order.ask();
    Promise.all([getVoice(), getSearchModel(), getSettings()]).then(
      ([v, s, settings]) => {
        if (!order.take(mine)) return;
        [voice, search] = [v, s];
        chosen = (["voice", "search"] as const).filter((kind) => settings.setup_downloads.includes(kind));
        const named = v.voices.find((one) => one.id === settings.voice) ?? v.voices[0];
        voiceName = named ? wording("setup-voice-named", { name: named.name, language: named.language }) : wording("setup-voice-model");
        draw();
        next();
        if (following) tell();
      },
      (error) => void (order.take(mine) && failed.replaceChildren(failure(reason(error)))),
    );
  };
  return { node, read, follow };
}
