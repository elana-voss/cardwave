// Dictation's model: the line "Dictation", the last of the settings' group Models, and the dialog "Dictation" it
// opens, made as Search's (`modelDialog`, the board "Settings › Models › Voice"): the model, Whisper large-v3-turbo, which
// runs on this computer's graphics card, its size and its state (not downloaded, downloading with how far, ready), a
// bar while it downloads, why the last download failed in red, and one button, Download, Cancel or Remove. Nothing
// is downloaded before "Download" is pressed (Claude).
//
// `dictationLine` makes the line and owns its dialog; its `read` asks the server anew, on the event `dictation` and
// when the server is heard again; a reading answered late is not taken (`reading`). The model serves every account,
// so only this computer's account has the button and the dialog.
import { account } from "../account";
import { cancelDictationDownload, downloadDictation, getDictation, removeDictation } from "../api/client";
import type { DictationModel } from "../api/generated/DictationModel";
import { bytes } from "../format";
import { type Action, modelDialog, modelLine, percent, reading } from "../models/downloaded";
import { wording } from "../language/language";

/** What the line says of the model under its name, and its button. */
export function lineSays(model: DictationModel): { says: string; action: string } {
  if (model.state === "absent") return { says: wording("providers-not-set-up"), action: wording("downloaded-set-up") };
  if (model.state === "downloading") return { says: wording("models-downloading", { name: model.name, percent: String(percent(model)) }), action: wording("password-change") };
  return { says: wording("models-on-this-computer", { name: model.name, reading: "" }), action: wording("password-change") };
}

/** What the dialog says of the model's state at the line's right, and its one button. */
export function dialogSays(model: DictationModel): { state: string; action: Action } {
  if (model.state === "absent") return { state: wording("search-setup-not-downloaded"), action: "Download" };
  if (model.state === "downloading") return { state: `${percent(model)}%`, action: "Cancel" };
  return { state: wording("search-setup-ready"), action: "Remove" };
}

/** The line "Dictation", with the dialog it opens in the screen `home` gives. */
export function dictationLine(home: () => HTMLElement): { node: HTMLElement; read(): void } {
  const line = modelLine(wording("label-settings-dictation"));
  let local = false;
  let now: DictationModel | null = null;
  /** What shows the model's state in the dialog while it is open. */
  let shown: ((model: DictationModel) => void) | null = null;
  const show = (model: DictationModel) => {
    now = model;
    const { says, action } = lineSays(model);
    line.set(says, action, model.failure);
    line.open.hidden = !local;
    shown?.(model);
  };
  void account().then((who) => {
    local = who.local;
    if (now) show(now);
  }, () => {});
  line.open.hidden = true;
  const { read, skip } = reading(getDictation, show, line.wrong);
  line.open.onclick = () => {
    if (!local || !now) return;
    shown = modelDialog(
      home(),
      wording("label-settings-dictation"),
      wording("dictation-setup-on-this-computers-graphics", { name: now.name, bytes: bytes(now.size) }),
      wording("dictation-setup-the-microphone-beside-the"),
      now,
      dialogSays,
      { Download: downloadDictation, Cancel: cancelDictationDownload, Remove: removeDictation },
      (model) => {
        skip();
        show(model);
      },
      () => (shown = null),
    );
  };
  read();
  return { node: line.node, read };
}
