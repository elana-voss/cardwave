// What the lines of a model the app downloads share (Search, Dictation and Voice; the board "Settings › Models ›
// Voice"): the settings' line with its name, what it says, its button and why it failed in red (`modelLine`); the
// dialog's grey box with the model's name, what it is, its state at the right and the bar while it downloads
// (`modelBox`); the dialog of Search and Dictation around it, with its one button (`modelDialog`); how far a download is (`percent`); and a reading of the state that is not taken when answered
// late (`reading`). Images is set up in the model picker and has none of it.
import { el, failure, newest, noticeBox, oneAtATime, reason } from "../dom";
import { dialog } from "../dialogs";
import { midSentence, wording } from "../language/language";
import { failedWords } from "../language/errors";
import type { ErrorBody } from "../api/generated/ErrorBody";

/** What a downloaded model's state says in both. */
type Download = { state: string; done: number; size: number; failure: ErrorBody | null };

/** How far a download is, in whole hundredths. */
export const percent = ({ done, size }: { done: number; size: number }) => Math.floor((done * 100) / Math.max(size, 1));

/** Shows the words of `why` in red in `where`, or nothing, and leaves it be where it says so already. */
export function failedIn(where: HTMLElement, why: ErrorBody | null): void {
  const failed = failedWords(why) ?? "";
  if (where.textContent !== failed) where.replaceChildren(...(failed ? [failure(failed)] : []));
}

/** The settings' line `label`: `set` shows what it says, its button `action` and why the model failed. */
export function modelLine(label: string) {
  const says = el("span", { className: "meta" });
  const wrong = el("div", { className: "item-wrong" });
  const open = el("button", { type: "button", className: "btn btn-secondary on-box", disabled: true }, wording("downloaded-set-up"));
  const node = el("div", { className: "item" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), says), open, wrong);
  const set = (said: string, action: string, failed: ErrorBody | null) => {
    says.textContent = said;
    open.textContent = action;
    open.ariaLabel = wording("downloaded-text", { action, toLowerCase: midSentence(label) });
    open.disabled = false;
    failedIn(wrong, failed);
  };
  return { node, open, wrong, set };
}

/** The dialog's grey box of the model `label`, `about` under its name, `tool` (a button) at the right after its state; `show` gives it the state `said`. */
export function modelBox(label: string, about: string, tool?: HTMLElement) {
  const state = el("span", { className: "meta" });
  const bar = el("div", { className: "bar" }, el("div"));
  const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), el("span", { className: "meta" }, about));
  const node = el("div", { className: "group" }, el("div", { className: "item f-col ai-st g-8" }, el("div", { className: "flex jc-sb g-12" }, text, tool ? el("div", { className: "flex ai-c g-12" }, state, tool) : state), bar));
  const show = (model: Download, said: string) => {
    state.textContent = said;
    bar.hidden = model.state !== "downloading";
    (bar.firstElementChild as HTMLElement).style.width = `${percent(model)}%`;
  };
  return { node, show };
}

/** The one button of `modelDialog`, by the model's state. */
export type Action = "Download" | "Cancel" | "Remove";
/** The word of a download's button, of what it does. */
export const actionWord = (action: Action) =>
  action === "Download" ? wording("voices-download") : action === "Cancel" ? wording("voices-cancel") : wording("voices-delete");

/**
 * The dialog `title` of a model downloaded to this computer (Search's, Dictation's), in the screen `home`: the grey
 * box of `model` with `about`, `text` under it, why the last attempt failed in red and one button, Download, Cancel
 * or Remove, as `says` tells; a press asks the button's function of `asks` and hands its answer to `took`. Returns
 * what shows a newer state, until the dialog closes (`closed`).
 */
export function modelDialog<M extends Download>(
  home: HTMLElement,
  title: string,
  about: string,
  text: string,
  model: M,
  says: (model: M) => { state: string; action: Action },
  asks: Record<Action, () => Promise<M>>,
  took: (model: M) => void,
  closed: () => void,
): (model: M) => void {
  const modelState = modelBox(wording("downloaded-local"), about);
  const why = noticeBox();
  const button = el("button", { type: "button", className: "btn btn-primary" });
  const attempt = oneAtATime(why);
  const box = dialog(home, title, modelState.node, el("p", { className: "m0" }, text), why, el("div", { className: "dfoot" }, button));
  box.classList.add("model-dialog");
  let action: Action = "Download";
  const show = (model: M) => {
    const said = says(model);
    modelState.show(model, said.state);
    action = said.action;
    if (button.textContent !== actionWord(action)) {
      const focused = document.activeElement === button;
      button.textContent = actionWord(action);
      button.className = `btn ${action === "Download" ? "btn-primary" : "btn-secondary"}`;
      if (focused) button.focus();
    }
    failedIn(why, model.failure);
  };
  button.onclick = () => void attempt(async () => took(await asks[action]()));
  box.addEventListener("close", closed);
  show(model);
  button.focus();
  return show;
}

/** Asks `ask` anew at each `read`, and hands the answer to `take`, unless a later one was asked or `skip` was. */
export function reading<T>(ask: () => Promise<T>, take: (answer: T) => void, wrong: HTMLElement) {
  const order = newest();
  const read = () => {
    const mine = order.ask();
    ask().then(
      (answer) => void (order.take(mine) && take(answer)),
      (error) => void (order.take(mine) && wrong.replaceChildren(failure(reason(error)))),
    );
  };
  /** Makes a reading on its way stale, as an answer of the server's own came. */
  const skip = () => void order.ask();
  return { read, skip };
}
