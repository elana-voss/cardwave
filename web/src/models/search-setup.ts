// The search model: the line "Search" of the settings' group Models and of first run's step 2, and the dialog
// "Search" it opens (the board "Settings › Models › Voice", whose shape serves Search too): the model, bge-m3,
// which runs on this computer, its size and its state (not downloaded, downloading with how far, ready, or
// reading the cards), a bar while it downloads, why the last download or the model failed in red, and one
// button, Download, Cancel or Remove. Nothing is downloaded before "Download" is pressed.
//
// `searchLine` makes the line and owns the dialog it opens; its `read` asks the server for the model's state
// anew, for both, on the event `search` (a step of the download, its end, a card read) and when the server is
// heard again; a reading answered late is not taken (`reading`); the parts both share are `downloaded.ts`'s. What each says is `lineSays` and `dialogSays`;
// in first run's step 2 the line says the size of the download "Confirm" makes.
// The model serves every account, so only this computer's account has the dialog. Where the account has a provider
// (`at`, from the group Models), the line's button opens the picker of the kind, whose "This computer" opens the
// dialog after (`local`); where Search is at a provider, the line says "[model] · [provider]" and how many cards
// that model has yet to read.
import { account } from "../account";
import { cancelSearchDownload, downloadSearchModel, getSearchModel, removeSearchModel } from "../api/client";
import type { SearchModel } from "../api/generated/SearchModel";
import { bytes } from "../format";
import { type Action, modelDialog, modelLine, percent, reading } from "./downloaded";
import { wording } from "../language/language";

/** What the line says of the model under its name, and its button; in first run the size of a download "Confirm" makes. */
export function lineSays(model: SearchModel, firstRun = false): { says: string; action: string } {
  if (model.state === "absent" && firstRun) return { says: wording("models-download-recommended", { name: model.name, size: bytes(model.size) }), action: wording("password-change") };
  if (model.state === "absent") return { says: wording("providers-not-set-up"), action: wording("downloaded-set-up") };
  if (model.state === "downloading") return { says: wording("models-downloading", { name: model.name, percent: String(percent(model)) }), action: wording("password-change") };
  const reading = model.left > 0 ? wording("search-setup-reading-cards-left", { left: model.left }) : "";
  return { says: wording("models-on-this-computer", { name: model.name, reading }), action: wording("password-change") };
}

/** What the dialog says of the model's state at the line's right, and its one button. */
export function dialogSays(model: SearchModel): { state: string; action: Action } {
  if (model.state === "absent") return { state: wording("search-setup-not-downloaded"), action: "Download" };
  if (model.state === "downloading") return { state: `${percent(model)}%`, action: "Cancel" };
  return { state: model.left > 0 ? wording("search-setup-reading-cards-left-2", { left: model.left }) : wording("search-setup-ready"), action: "Remove" };
}

/** The line "Search", with the dialog it opens in the screen `home` gives; `firstRun` has it say its download's size on this computer's account, which alone downloads, and is told of each state (`changed`). */
export function searchLine(
  home: () => HTMLElement,
  firstRun?: { changed(): void },
): { node: HTMLElement; read(): void; model(): SearchModel | null; at(said: string | null, change: (() => void) | null): void; local(): void } {
  const line = modelLine(wording("label-settings-search"));
  let local = false;
  void account().then((who) => {
    local = who.local;
    line.open.hidden = !local && !away;
    if (now) show(now);
  }, () => {});
  let now: SearchModel | null = null;
  /** The dialog while it is open, and what shows the model's state in it. */
  let shown: ((model: SearchModel) => void) | null = null;
  /** Where the account has a provider: what the line says where the kind is at one, and the picker its button opens. */
  let away: { said: string | null; change: () => void } | null = null;

  const show = (model: SearchModel) => {
    now = model;
    if (away?.said) {
      line.set(away.said + (model.left > 0 ? wording("search-setup-reading-cards-left", { left: model.left }) : ""), wording("setup-change"), model.failure);
    } else {
      const { says, action } = lineSays(model, !!firstRun && local);
      line.set(says, action, model.failure);
    }
    line.open.hidden = !local && !away;
    shown?.(model);
    firstRun?.changed();
  };
  const { read, skip } = reading(getSearchModel, show, line.wrong);
  line.open.onclick = () => (away ? away.change() : open());
  /** The dialog of this computer's model, on this computer's account. */
  const open = () => {
    if (!local || !now) return;
    shown = modelDialog(
      home(),
      wording("label-settings-search"),
      wording("search-setup-on-this-computer-download", { name: now.name, bytes: bytes(now.size) }),
      wording("search-setup-the-librarys-search-then"),
      now,
      dialogSays,
      { Download: downloadSearchModel, Cancel: cancelSearchDownload, Remove: removeSearchModel },
      (model) => {
        skip();
        show(model);
      },
      () => (shown = null),
    );
  };
  read();
  const at = (said: string | null, change: (() => void) | null) => {
    away = change && { said, change };
    if (now) show(now);
  };
  return { node: line.node, read, model: () => now, at, local: open };
}
