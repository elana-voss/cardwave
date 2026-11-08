// Settings › Voices, at `#/settings/voices` (board "Voices"), in the place of the dialog "Voice", which first run
// keeps (voice-setup.ts): "Settings / Voices"; while the voice model is not there, its grey box first, as the
// dialog has it (Claude), with Download or Cancel on this computer's account; then the group Voices, a line per
// voice (its round mark choosing the account's voice, its language or "Made from your recording", "Try", and on
// one made "…" with Rename and Delete, which asks in the line's place), Speed as the box's last line (0.5× to
// 2×, stored when let go) and "Make a voice from a recording" (make-voice.ts); Characters' voices, a line per
// card with a voice of its own (the voice's field, Try, and × on hover, back to the default voice) and "Set a
// voice for a character" (a form dialog of the character and the voice); Languages, English "Built in" and each
// other one's download with its bar, Download, Cancel or Remove (this computer's account's alone). "Try" reads
// a sample in the language messages are read in, and turns into Stop while it plays. While Voice is at a provider
// (`at_provider`), the voices are the provider's, each with its model under its name, without the grey box and
// "Make a voice from a recording"; one that lists none says so. Each group is drawn anew
// only when what it shows changed (`Part`), so a field open in another stays open; the event `voice` and the
// server heard again read the page anew.
import { wording } from "../language/language";
import { cardTitle } from "../card-title";
import { failureWords } from "../language/errors";
import { account } from "../account";
import {
  cancelVoiceDownload,
  changeSettings,
  deleteVoice,
  downloadVoice,
  downloadVoiceLanguage,
  getCharacterVoices,
  getSettings,
  getVoice,
  listCards,
  removeVoiceLanguage,
  renameVoice,
  setCharacterVoice,
  unsetCharacterVoice,
} from "../api/client";
import type { CharacterVoice } from "../api/generated/CharacterVoice";
import type { ServerEvent } from "../api/generated/ServerEvent";
import type { Settings } from "../api/generated/Settings";
import type { VoiceChoice } from "../api/generated/VoiceChoice";
import type { VoiceLanguage } from "../api/generated/VoiceLanguage";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { el, failure, item, latest, noticeBox, oneAtATime, selectField, type View } from "../dom";
import { askFirst, formDialog, menu } from "../dialogs";
import { bytes, decimal } from "../format";
import { actionWord, failedIn, modelBox, percent } from "../models/downloaded";
import { icon } from "../icons";
import { makeVoiceDialog } from "../voice/make-voice";
import { type Reader, readAloud, stopReading } from "../voice/voice";
import { dialogSays, sample, voiceAbout, voiceOf } from "../voice/voice-setup";
import { LABELS } from "../setting-labels";

/** What the page knows: the voice's state, the account's settings and characters' voices, and whether it is this computer's account. */
interface Page {
  node: HTMLElement;
  model: VoiceModel;
  settings: Settings;
  characters: CharacterVoice[];
  local: boolean;
  /** The "Try" button that plays, and what it plays. */
  trying: string | null;
  attempt: (action: () => Promise<void>) => Promise<boolean>;
  read(): Promise<void>;
  draw(): void;
}

/** A group of the page, drawn anew only when what it shows changed. */
function part(): { node: HTMLElement; show(key: unknown, make: () => HTMLElement[]): void } {
  const node = el("section");
  let drawn = "";
  return {
    node,
    show: (key, make) => {
      const now = JSON.stringify(key);
      if (now === drawn) return;
      drawn = now;
      node.replaceChildren(...make());
      node.hidden = !node.childElementCount;
    },
  };
}

/** "Try" for `what`, read by `reader` with `name` in its sample. */
function tryButton(page: Page, what: string, name: string, reader: Reader): HTMLButtonElement {
  const playing = page.trying === what;
  const button = el("button", { type: "button", className: "btn btn-quiet btn-icon", ariaLabel: playing ? wording("voices-stop", { name }) : wording("voices-try", { name }), disabled: page.model.state !== "ready" && !page.model.at_provider }, icon(playing ? "stop" : "play", 16));
  button.onclick = () => {
    if (playing) return stopReading();
    page.trying = what;
    page.draw();
    readAloud(sample(page.model.reads_in, name), page.model.rate, (failed) => {
      if (page.trying === what) page.trying = null;
      page.draw();
      if (failed) page.node.querySelector(".note")!.replaceChildren(failure(failed));
    }, reader);
  };
  return button;
}

/** The voice model's grey box, while it is not there: its button (Download, Cancel) at the line's right, in place of "Not downloaded". */
function modelPart(page: Page): HTMLElement[] {
  const model = page.model;
  if (model.state === "ready" || model.at_provider) return [];
  const { state, action } = dialogSays(model);
  const button = el("button", { type: "button", className: action === "Download" ? "btn btn-primary" : "btn btn-secondary" }, action ? actionWord(action) : "");
  button.hidden = !action || !page.local;
  button.onclick = () => void page.attempt(async () => {
    page.model = await (action === "Download" ? downloadVoice() : cancelVoiceDownload());
    page.draw();
  });
  const box = modelBox(LABELS.voices.model, wording("voices-model-about", { size: bytes(model.size) }), button);
  box.show(model, action === "Download" && !button.hidden ? "" : state);
  const why = el("div");
  failedIn(why, model.failure);
  return [box.node, why];
}

/** A voice's line in the group Voices. */
function voiceLine(page: Page, voice: VoiceChoice, chosen: string): HTMLElement {
  const pick = el("input", { type: "radio", name: "voice", checked: voice.id === chosen, ariaLabel: wording("voices-default-of", { name: voice.name }) });
  pick.onchange = () => void page.attempt(async () => {
    page.settings = await changeSettings({ voice: voice.id });
    page.draw();
  });
  const line = el("div", { className: "item item-voice" }, pick, el("div", { className: "item-text" }, el("span", { className: "item-label" }, voice.name), el("span", { className: "meta" }, voiceAbout(voice))), tryButton(page, voice.id, voice.name, { voice: voice.id }));
  if (voice.own) {
    const back = () => page.draw();
    line.append(
      menu(wording("voices-menu"), [
        { label: wording("voices-rename"), shape: "edit", action: () => rename(page, voice) },
        {
          label: wording("common-delete"),
          shape: "trash",
          danger: true,
          action: () =>
            askFirst(line, wording("voices-delete-ask", { name: voice.name }), wording("common-delete"), () => void page.attempt(async () => {
              page.model = await deleteVoice(voice.id);
              page.characters = await getCharacterVoices();
              page.draw();
            }), () => {
              line.replaceWith(voiceLine(page, voice, chosen));
              back();
            }),
        },
      ]),
    );
  }
  return line;
}

function rename(page: Page, voice: VoiceChoice): void {
  const input = el("input", { id: "voice-name", className: "field", type: "text", value: voice.name, maxLength: 60, autocomplete: "off" });
  const box = formDialog(page.node, wording("voices-rename-title"), [el("label", { htmlFor: input.id }, wording("voices-name")), input], async () => {
    page.model = await renameVoice(voice.id, input.value);
    page.draw();
    box.close();
  });
  input.select();
}

/** The line Speed: a slider of 0.5× to 2×, stored when let go. */
function speedLine(page: Page): HTMLElement {
  const said = (speed: number) => wording("voices-speed-value", { speed: decimal(speed, 1) });
  const value = page.settings.voice_speed / 100;
  const shown = el("span", { className: "meta lv-val" }, said(value));
  const slider = el("input", { type: "range", min: "0.5", max: "2", step: "0.1", value: String(value), ariaLabel: wording("voices-speed") });
  slider.oninput = () => (shown.textContent = said(Number(slider.value)));
  slider.onchange = () => void page.attempt(async () => {
    page.settings = await changeSettings({ voice_speed: Math.round(Number(slider.value) * 100) });
    page.draw();
  });
  return item(LABELS.voices.speed, wording("voices-speed-about"), el("div", { className: "lv" }, slider, shown));
}

/** The id of the account's voice: the one chosen, else the first; none where there is no voice to choose. */
const chosenOf = (page: Page) => (page.model.voices.length ? voiceOf(page.model, page.settings.voice).id : "");

function voicesPart(page: Page): HTMLElement[] {
  const chosen = chosenOf(page);
  const make = el("button", { type: "button", className: "btn btn-secondary", onclick: () => makeVoiceDialog(page.node, page.model.rate, () => void page.read()) }, icon("mic", 16), wording("voices-make"));
  const failed = page.model.at_provider && page.model.failure;
  const none = item(failed ? wording("voices-provider-failed") : wording("voices-provider-none"), failed ? failure(failureWords(failed)) : el("span", { className: "meta" }, wording("voices-provider-own")), el("span"));
  return [
    el("div", { className: "gh" }, el("h2", null, wording("voices-voices"))),
    el("p", { className: "hint" }, wording("voices-voices-about")),
    el("div", { className: "group", role: "radiogroup", ariaLabel: wording("voices-default") }, ...(page.model.voices.length ? page.model.voices.map((voice) => voiceLine(page, voice, chosen)) : [none]), speedLine(page)),
    ...(page.model.at_provider ? [] : [el("div", { className: "mt-10" }, make)]),
  ];
}

/** The voices to pick in a field. */
const choices = (page: Page) => page.model.voices.map((voice) => ({ value: voice.id, label: voice.name }));

function characterLine(page: Page, character: CharacterVoice): HTMLElement {
  // A voice kept of this computer while Voice is at a provider, or the other way round, is not read in: the account's is.
  const kept = page.model.voices.some((voice) => voice.id === character.voice) ? character.voice : chosenOf(page);
  const field = selectField(choices(page), kept, (voice) => void page.attempt(async () => {
    page.characters = await setCharacterVoice(character.card_id, voice);
    page.draw();
  }), { ariaLabel: wording("voices-voice-of", { name: character.name }) });
  const back = el("button", { type: "button", className: "btn btn-quiet btn-icon btn-sm reveal", ariaLabel: wording("voices-back-default"), title: wording("voices-back-default") }, icon("close", 16));
  back.onclick = () => void page.attempt(async () => {
    page.characters = await unsetCharacterVoice(character.card_id);
    page.draw();
  });
  return item(character.name, cardTitle(character.title), el("div", { className: "lv" }, field.node, tryButton(page, `card-${character.card_id}`, character.name, { card: character.card_id }), back));
}

/** The dialog "Set a voice for a character": the character, of the cards without a voice of their own, and the voice. */
async function setForCharacter(page: Page): Promise<void> {
  const cards = (await listCards({ sort: "name" })).filter((card) => !page.characters.some((had) => had.card_id === card.id));
  let card = "";
  let voice = chosenOf(page);
  const who = selectField(cards.map((one) => ({ value: String(one.id), label: one.names[0] && one.names[0] !== one.title ? wording("voices-name-title", { name: one.names[0], title: cardTitle(one.title) }) : cardTitle(one.title) })), card, (value) => (card = value), { id: "voice-character", placeholder: cards.length ? wording("voices-choose-character") : wording("voices-all-have") });
  const which = selectField(choices(page), voice, (value) => (voice = value), { id: "voice-voice" });
  const box = formDialog(page.node, wording("voices-set-for"), [el("label", { htmlFor: "voice-character" }, wording("voices-character")), who.node, el("label", { htmlFor: "voice-voice" }, wording("voices-voice")), which.node], async () => {
    if (!card) throw new Error(wording("voices-character-first"));
    page.characters = await setCharacterVoice(Number(card), voice);
    page.draw();
    box.close();
  });
}

function charactersPart(page: Page): HTMLElement[] {
  const add = el("button", { type: "button", className: "btn btn-secondary", onclick: () => void page.attempt(() => setForCharacter(page)) }, icon("plus", 16), wording("voices-set-for"));
  return [el("div", { className: "gh" }, el("h2", null, wording("voices-characters"))), ...(page.characters.length ? [el("div", { className: "group" }, ...page.characters.map((one) => characterLine(page, one)))] : []), el("div", { className: "mt-10" }, add)];
}

/** What a language's line says under its name, and its button. */
export function languageSays(language: VoiceLanguage): { says: string; action: "Download" | "Cancel" | "Remove" } {
  const size = bytes(language.size);
  if (language.state === "downloading") return { says: wording("voices-downloading", { size, percent: String(percent(language)) }), action: "Cancel" };
  if (language.state === "ready") return { says: wording("voices-downloaded", { size }), action: "Remove" };
  return { says: wording("voices-download-size", { size }), action: "Download" };
}

function languageLine(page: Page, language: VoiceLanguage): HTMLElement {
  const { says, action } = languageSays(language);
  const button = el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("voices-action-of", { action: actionWord(action), name: language.name }) }, actionWord(action));
  button.hidden = !page.local;
  button.onclick = () => void page.attempt(async () => {
    page.model = await (action === "Download" ? downloadVoiceLanguage(language.id) : removeVoiceLanguage(language.id));
    page.draw();
  });
  const about = el("span", { className: "meta" }, says);
  const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, language.name), about);
  if (language.state === "downloading") {
    const done = el("div");
    done.style.width = `${percent(language)}%`;
    text.append(el("div", { className: "bar bar-fixed mt-8", role: "progressbar", ariaLabel: wording("voices-language-downloaded", { name: language.name }) }, done));
  }
  if (language.failure) text.append(failure(failureWords(language.failure)));
  return el("div", { className: "item" }, text, button);
}

function languagesPart(page: Page): HTMLElement[] {
  const english = item(LABELS.voices.english, wording("voices-built-in"), el("span"));
  return [el("div", { className: "gh" }, el("h2", null, wording("voices-languages"))), el("div", { className: "group" }, english, ...page.model.languages.map((language) => languageLine(page, language)))];
}

export function voicesView(): View {
  const notice = noticeBox();
  const [modelGroup, voices, characters, languages] = [part(), part(), part(), part()];
  const node = el(
    "section",
    { className: "main main-form voices" },
    el("header", { className: "pbar" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-voices")))),
    el("div", { className: "page-col mt-12" }, notice, modelGroup.node, voices.node, characters.node, languages.node),
  );
  let shown = false;
  const page: Page = {
    node,
    model: null!,
    settings: null!,
    characters: [],
    local: false,
    trying: null,
    attempt: oneAtATime(notice),
    read: latest(notice, () => Promise.all([getVoice(), getSettings(), getCharacterVoices(), account()]), ([model, settings, characters, me]) => {
      Object.assign(page, { model, settings, characters, local: me.local });
      shown = true;
      page.draw();
    }),
    draw: () => {
      if (!shown) return;
      const { model, settings, characters: had, local, trying } = page;
      modelGroup.show([model.state, model.done, model.failure, local], () => modelPart(page));
      voices.show([model.voices, model.state, model.at_provider, model.failure, model.reads_in, settings.voice, settings.voice_speed, trying], () => voicesPart(page));
      characters.show([had, model.voices, model.state, model.at_provider, trying], () => charactersPart(page));
      languages.show([model.languages, local], () => languagesPart(page));
    },
  };
  void page.read();
  return {
    node: node,
    onEvent: (event: ServerEvent) => {
      if (event.type === "voice" || event.type === "settings") void page.read();
    },
    onConnected: () => void page.read(),
    left: stopReading,
  };
}
