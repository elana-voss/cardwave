// The voice: the line "Voice" of the settings' group Models, which leads to Settings › Voices (views/voices.ts),
// and in first run's step 2 opens the dialog "Voice" (the board "Settings › Models › Voice"), where a voice is
// picked before "Confirm" downloads it. The dialog's grey box is the voice model, which runs on this computer,
// its size and its state (not downloaded, downloading with how far, ready), with a bar while it downloads; under
// it the voices, each with its language (the licences are in About) and a button that plays a sample of it
// once the model is there; why the last download failed in red; and "Download" (while nothing is there) or "Use
// this voice", which stores the voice ticked for the account, with "Cancel", which closes the dialog and stops a
// download that runs (the × closes it alone). Nothing is downloaded before "Download" is pressed.
//
// `voiceLine` makes the line and opens the dialog (`voiceDialog`); its `read` asks the server for the voice's state and
// the account's settings anew, for both, on the event `voice` and when the server is heard again; a reading
// answered late is not taken (`reading`); the parts it shares with Search are `downloaded.ts`'s, those it shares
// with the page Voices `voiceAbout` and `sample`. What each says is `lineSays` and `dialogSays`; in first run's
// step 2 the line says the size of the download "Confirm" makes. The model serves every account, so only this
// computer's account downloads it; another's line has its button once it is there. Where the account has a provider
// (`at`, from the group Models), the line's button opens the picker of the kind, and the model taken leads to
// Settings › Voices (`local`), where its voice is chosen; where Voice is at a provider, the line says "[model] ·
// [provider]".
import { account } from "../account";
import { cancelVoiceDownload, changeSettings, downloadVoice, getSettings, getVoice } from "../api/client";
import type { VoiceChoice } from "../api/generated/VoiceChoice";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { el, failure, noticeBox, oneAtATime } from "../dom";
import { dialog } from "../dialogs";
import { bytes } from "../format";
import { failedIn, modelBox, modelLine, percent, reading } from "../models/downloaded";
import { icon } from "../icons";
import { readAloud, stopReading } from "./voice";
import { languageName, wording } from "../language/language";


/** The voice of `id`, or the first, which is used until one is chosen. */
export const voiceOf = (model: VoiceModel, id: string | null): VoiceChoice => model.voices.find((voice) => voice.id === id) ?? model.voices[0];

/** What a voice is, under its name: its language, that it was made from the user's recording, or a provider's its model. */
export const voiceAbout = (voice: VoiceChoice) =>
  voice.own ? wording("voice-setup-made-from-your-recording") : voice.language ? languageName(voice.language, voice.language) : voice.set;

/** What a voice says to be tried, in the language the account's messages are read in. */
export function sample(language: string, name: string): string {
  const said: Record<string, string> = {
    German: `Hallo, ich bin ${name}. So klingen deine Nachrichten, wenn sie vorgelesen werden.`,
    Italian: `Ciao, sono ${name}. Ecco come suonano i tuoi messaggi letti ad alta voce.`,
    Portuguese: `Olá, eu sou ${name}. É assim que as suas mensagens soam quando são lidas em voz alta.`,
    Spanish: `Hola, soy ${name}. Así suenan tus mensajes cuando se leen en voz alta.`,
    French: `Bonjour, je suis ${name}. Voici comment sonnent vos messages lus à voix haute.`,
  };
  return said[language] ?? wording("voice-setup-hello-im-this-is", { name });
}

/** What the line says under its name, and its button, with `chosen` the account's voice; in first run the size of a download "Confirm" makes. */
export function lineSays(model: VoiceModel, chosen: string | null, firstRun = false): { says: string; action: string } {
  if (model.state === "absent" && firstRun) {
    const voice = voiceOf(model, chosen);
    return { says: wording("voice-setup-voice-download", { name: voice.name, about: voiceAbout(voice), size: bytes(model.size) }), action: wording("password-change") };
  }
  if (model.state === "absent") return { says: wording("providers-not-set-up"), action: wording("downloaded-set-up") };
  if (model.state === "downloading") return { says: wording("voice-setup-downloading", { percent: String(percent(model)) }), action: wording("downloaded-set-up") };
  const voice = voiceOf(model, chosen);
  return { says: `${voice.name} · ${voiceAbout(voice)}`, action: wording("password-change") };
}

/** What the dialog says of the model's state at the line's right, and its download's button, if any. */
export function dialogSays(model: VoiceModel): { state: string; action: "Download" | "Cancel" | null } {
  if (model.state === "absent") return { state: wording("search-setup-not-downloaded"), action: "Download" };
  if (model.state === "downloading") return { state: `${percent(model)}%`, action: "Cancel" };
  return { state: wording("search-setup-ready"), action: null };
}

/** The line "Voice", which leads to Settings › Voices; in first run (`firstRun`) it opens the dialog in the screen `home` gives, says its download's size on this computer's account, which alone downloads, and is told of each state (`changed`). */
export function voiceLine(
  home: () => HTMLElement,
  firstRun?: { changed(): void },
): { node: HTMLElement; read(): void; model(): VoiceModel | null; at(said: string | null, change: (() => void) | null): void; local(): void } {
  const line = modelLine(wording("label-settings-voice"));
  let local = false;
  void account().then((who) => {
    local = who.local;
    if (now) show(now);
  }, () => {});
  let now: VoiceModel | null = null;
  let chosen: string | null = null;
  /** The dialog while it is open, and what shows the voice's state in it. */
  let shown: ((model: VoiceModel) => void) | null = null;
  /** Where the account has a provider: what the line says where the kind is at one, and the picker its button opens. */
  let away: { said: string | null; change: () => void } | null = null;

  const show = (model: VoiceModel) => {
    now = model;
    if (away?.said) {
      line.set(away.said, wording("setup-change"), null);
    } else {
      const { says, action } = lineSays(model, chosen, !!firstRun && local);
      line.set(says, action, model.failure);
    }
    line.open.hidden = !local && model.state !== "ready" && !away;
    shown?.(model);
    firstRun?.changed();
  };
  const { read, skip } = reading(
    () => Promise.all([getVoice(), getSettings()]),
    ([model, settings]) => {
      chosen = settings.voice;
      show(model);
    },
    line.wrong,
  );
  line.open.onclick = () => {
    if (away) return away.change();
    if (!firstRun) {
      location.hash = "#/settings/voices";
      return;
    }
    shown = voiceDialog(
      home(),
      { now: () => now!, chosen: () => chosen, local: () => local, skip, show, choose: (voice) => (chosen = voice) },
      () => (shown = null),
    );
  };
  read();
  const at = (said: string | null, change: (() => void) | null) => {
    away = change && { said, change };
    if (now) show(now);
  };
  return { node: line.node, read, model: () => now, at, local: () => (location.hash = "#/settings/voices") };
}

/** What the dialog "Voice" is given of its line: the model as it stands, the account's voice and whether this is
 * this computer's account; `skip` lets a reading under way go, `show` shows a model's state, `choose` keeps the voice stored. */
interface VoiceLine {
  now(): VoiceModel;
  chosen(): string | null;
  local(): boolean;
  skip(): void;
  show(model: VoiceModel): void;
  choose(voice: string | null): void;
}

/** Opens the dialog "Voice" in `home` (see the head); answers what shows the model's state in it while it is open, `closed` told when it closes. */
function voiceDialog(home: HTMLElement, line: VoiceLine, closed: () => void): (model: VoiceModel) => void {
  const model = line.now();
  const modelState = modelBox(wording("label-voices-model"), wording("voice-setup-on-this-computer-download", { bytes: bytes(model.size) }));
  const why = noticeBox();
  const main = el("button", { type: "button", className: "primary btn btn-primary" });
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const attempt = oneAtATime(why);
  let ticked = voiceOf(model, line.chosen()).id;
  /** The play buttons, which play only once the model is there. */
  const plays: HTMLButtonElement[] = [];
  const rows = model.voices.map((voice) => {
    const pick = el("input", { type: "radio", name: "voice", value: voice.id, checked: voice.id === ticked, ariaLabel: voice.name });
    const play = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: wording("voice-setup-play-a-sample-of", { name: voice.name }) }, icon("play"));
    plays.push(play);
    const row = el(
      "label",
      { className: "voice-row item item-voice" },
      pick,
      el("span", { className: "item-text" }, el("span", { className: "voice-name item-label" }, voice.name), el("span", { className: "meta" }, voiceAbout(voice))),
      play,
    );
    pick.onchange = () => (ticked = voice.id);
    play.onclick = (event) => {
      event.preventDefault();
      if (play.ariaPressed === "true") return stopReading();
      play.ariaPressed = "true";
      play.replaceChildren(icon("stop"));
      play.ariaLabel = wording("voice-setup-stop-the-sample-of", { name: voice.name });
      readAloud(sample(line.now().reads_in, voice.name), line.now().rate, (failed) => {
        play.ariaPressed = "false";
        play.replaceChildren(icon("play"));
        play.ariaLabel = wording("voice-setup-play-a-sample-of", { name: voice.name });
        if (failed) why.replaceChildren(failure(failed));
      }, { voice: voice.id });
    };
    return row;
  });
  const box = dialog(
    home,
    wording("label-settings-voice"),
    el(
      "div",
      { className: "dlg-body voice-setup" },
      modelState.node,
      el("p", { className: "hint" }, wording("voice-setup-messages-are-read-aloud")),
      el("div", { className: "fld" }, el("span", { className: "label" }, wording("label-settings-voice")), el("div", { className: "voice-rows group", role: "radiogroup", ariaLabel: wording("label-settings-voice") }, ...rows)),
      why,
    ),
    el("div", { className: "dfoot" }, main, cancel),
  );
  const shown = (model: VoiceModel) => {
    const { state, action } = dialogSays(model);
    modelState.show(model, state);
    const label = action === "Download" ? wording("update-download") : wording("voice-setup-use-this-voice");
    if (main.textContent !== label) main.textContent = label;
    main.hidden = action === "Download" && !line.local();
    for (const play of plays) play.disabled = model.state !== "ready";
    failedIn(why, model.failure);
  };
  main.onclick = () =>
    void attempt(async () => {
      if (main.textContent === wording("update-download")) {
        const model = await downloadVoice();
        line.skip();
        line.show(model);
        return;
      }
      line.choose((await changeSettings({ voice: ticked })).voice);
      line.skip();
      box.close();
      line.show(line.now());
    });
  cancel.onclick = () =>
    void attempt(async () => {
      if (line.now().state === "downloading" && line.local()) {
        const model = await cancelVoiceDownload();
        line.skip();
        line.show(model);
      }
      box.close();
    });
  box.addEventListener("close", () => {
    closed();
    stopReading();
  });
  shown(model);
  main.focus();
  return shown;
}
