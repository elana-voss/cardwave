// First run's fourth step, "Downloads" (board "First run · step 3", its third there; the owner's Option B of
// 2026-11-08), only this computer's account's. First it asks (`downloadsChoice`): the search model's line and the
// voice's, each with a switch of whether first run downloads it in place of "Change", and a button "Download (size
// of what is on)", "Open Cardwave" with both off. Then (`downloadsStep`) a line per download chosen (the account's
// `setup_downloads`), search first, each with a bar and at its right its percent, "Waiting", or "Done" with the
// tick; a failed one says why in red, with "Retry" in its percent's place. One downloads at a time, in the lines'
// order (`next`); after a failure nothing starts until "Retry"; a download the server refused to start counts as
// failed (`refused`), and so does a start it took that left it absent (`tried`). `setup_downloads` brings a start
// back to these bars until "Open Cardwave", which opens the app at any time and is kept in the browser (`OPENED`; `firstRunLeft`); the step then goes on downloading outside
// the screen (`following`, fed the server's events by main.ts through `downloadsHeard`), and so does a start after
// it while the list holds any (`followDownloads`): one notice when all are there, which empties the list, and one
// that stays with "Try again" when one fails. `read` asks the server for both states anew.
import { wording } from "../language/language";
import { voiceAbout, voiceLine } from "../voice/voice-setup";
import { errorWords, failedWords } from "../language/errors";
import { changeSettings, downloadSearchModel, downloadVoice, getSearchModel, getSettings, getVoice } from "../api/client";
import type { SearchModel } from "../api/generated/SearchModel";
import type { SetupDownload } from "../api/generated/SetupDownload";
import type { VoiceModel } from "../api/generated/VoiceModel";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { announce, el, failure, item, newest, noticeBox, reason, switchBox, told } from "../dom";
import { bytes } from "../format";
import { percent } from "../models/downloaded";
import { searchLine } from "../models/search-setup";
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

/** What first run can download: the search model and the voice where they are not there, also one that is
 * downloading or failed, so that the bars see it through, and one not read yet or whose read failed, whose line
 * shows why; on this computer's account alone. */
export function toMake(local: boolean, voice: VoiceModel | null, search: SearchModel | null): { kind: Kind; name: string; size: number }[] {
  if (!local) return [];
  return [
    ...(search?.state !== "ready" ? [{ kind: "search" as const, name: wording("setup-the-search-model"), size: search?.size ?? 0 }] : []),
    ...(voice?.state !== "ready" ? [{ kind: "voice" as const, name: wording("setup-the-voice"), size: voice?.size ?? 0 }] : []),
  ];
}
/** The downloads first run makes: of those it can, the ones `want` chose. */
export const toDownload = (local: boolean, voice: VoiceModel | null, search: SearchModel | null, want: Record<Kind, boolean>) =>
  toMake(local, voice, search).filter((one) => want[one.kind] && (one.kind === "voice" ? voice : search));

/** The asking button's words: "Download" with the size of all that is on, else "Open Cardwave". */
export const downloadText = (made: { size: number }[]) => (made.length ? wording("setup-download-size", { size: bytes(made.reduce((sum, one) => sum + one.size, 0)) }) : wording("setup-open"));

/** Step 4 as it asks: the search model's line and the voice's, a switch in place of each one's "Change" (the voice
 * is changed in Settings), the button that starts the downloads and "Back"; `changed` is told of the models' states. */
export function downloadsChoice(home: () => HTMLElement, changed: () => void) {
  const voice = voiceLine(home, { changed });
  const search = searchLine(home, { changed });
  // The search model is recommended and on at first, the voice an option.
  const want = { voice: switchBox({ ariaLabel: wording("setup-want-voice"), onchange: changed }), search: switchBox({ ariaLabel: wording("setup-want-search"), checked: true, onchange: changed }) };
  for (const [line, toggle] of [[voice, want.voice], [search, want.search]] as const) {
    // Removed, not hidden: the line shows and hides its button by itself.
    line.node.querySelector(".btn")!.replaceWith(el("label", { className: "meta flex ai-c g-8" }, wording("voices-download"), toggle));
  }
  const go = el("button", { type: "button", className: "btn btn-primary btn-lg" }, downloadText([]));
  const back = el("button", { type: "button", className: "btn btn-quiet" }, wording("setup-back"));
  const node = el("div", { className: "setup-step flex f-col g-28", hidden: true }, el("div", { className: "group" }, search.node, voice.node), el("div", { className: "setup-actions flex ai-c g-10 wrap" }, go, back));
  /** What can be downloaded, and of it what is on. */
  const could = (local: boolean) => toMake(local, voice.model(), search.model());
  const chosen = (local: boolean) => toDownload(local, voice.model(), search.model(), { voice: want.voice.checked, search: want.search.checked });
  /** A line shows while its download can be made; the button names what is on. */
  const draw = (local: boolean) => {
    const can = could(local);
    for (const [kind, line] of [["voice", voice], ["search", search]] as const) line.node.hidden = !can.some((one) => one.kind === kind);
    go.textContent = downloadText(chosen(local));
  };
  return { node, voice, search, want, go, back, could, chosen, draw };
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
  /** The downloads chosen, in the lines' order. */
  let chosen: Kind[] = [];
  /** A download asked for and not yet answered: no second one starts meanwhile. */
  let starting = false;
  /** Why the server refused to start a download, until "Retry". */
  const refused: Record<Kind, string | null> = { voice: null, search: null };
  /** Started since the last press: a start the server took that left it absent failed, and is not tried again. */
  const tried: Record<Kind, boolean> = { voice: false, search: false };
  /** The first read asked after the last start answered: one asked before may tell the state before that start. */
  let fresh = 0;
  // The shared place for why, which takes no room while it says nothing (no gap of its own under the lines).
  const failed = noticeBox();
  const later = el("p", { className: "hint", hidden: true }, wording("setup-cards-later"));
  const asks: Record<Kind, () => Promise<unknown>> = { voice: downloadVoice, search: downloadSearchModel };
  const start = (kind: Kind) => {
    starting = true;
    tried[kind] = true;
    refused[kind] = null;
    asks[kind]()
      .catch((error) => (refused[kind] = told(error)))
      .finally(() => {
        starting = false;
        fresh = read();
      });
  };
  /** The model as its line has it: a refusal, or a start that left it absent, is its failure while it is not downloading. */
  const seen = (model: Model, kind: Kind): Shown => ({
    state: model.state,
    done: model.done,
    size: model.size,
    failure: (model.state === "absent" && (refused[kind] ?? failedWords(model.failure) ?? (tried[kind] && !starting ? errorWords(500, null) : null))) || failedWords(model.failure),
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
  const node = el("div", { className: "setup-step flex f-col g-28", hidden: true }, el("div", { className: "group" }, searchLine.node, voiceLine.node), later, failed, el("div", { className: "setup-actions flex ai-c g-10 wrap" }, openButton));

  /** Starts the first download that is not there, unless one runs, is being asked for, or failed. */
  const next = () => {
    if (!voice || !search || starting || !((node.isConnected && !node.hidden) || following)) return;
    const downloads: [Shown, Kind][] = chosen.map((kind) => [kind === "voice" ? seen(voice!, kind) : seen(search!, kind), kind]);
    const first = downloads.find(([model]) => model.state !== "ready");
    if (!first || first[0].state === "downloading" || first[0].failure) return;
    start(first[1]);
  };
  const draw = () => {
    later.hidden = !cards();
    if (!voice || !search) return;
    searchLine.show(seen(search, "search"), `${search.name} · ${bytes(search.size)}`, null);
    voiceLine.show(seen(voice, "voice"), `${voiceName} · ${bytes(voice.size)}`, chosen.includes("search") ? search : null);
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
        if (mine < fresh || !order.take(mine)) return;
        [voice, search] = [v, s];
        // Seen downloading, a start went through: one cut later (a restart) is started once more.
        if (v.state === "downloading") tried.voice = false;
        if (s.state === "downloading") tried.search = false;
        chosen = (["search", "voice"] as const).filter((kind) => settings.setup_downloads.includes(kind));
        const named = v.voices.find((one) => one.id === settings.voice) ?? v.voices[0];
        voiceName = named ? wording("setup-voice-named", { name: named.name, language: voiceAbout(named) }) : wording("setup-voice-model");
        draw();
        next();
        if (following) tell();
      },
      (error) => void (mine >= fresh && order.take(mine) && failed.replaceChildren(failure(reason(error)))),
    );
    return mine;
  };
  return { node, read, follow };
}
