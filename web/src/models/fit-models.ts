// The models that fit this computer, in Settings › Providers' box "This computer" under its kind lines (board
// "Settings › Providers, models that fit", milestone 74): Cardwave's list and the folder's own GGUF files, a line
// each (`.item.fit-model`), indented: the name, and in grey its size and "Runs on this computer" or "Too large for this
// computer", then "downloading [n]%", "downloaded" or "used for [kinds]" (`fitSays`). One too large is greyed
// and has no button; one absent has "Download", one downloading its bar and "Cancel", one there, of Cardwave's
// list, "…" with Remove, which asks in the menu's place; a model is chosen for a kind only in Settings › Models. A download's failure stands in red under its line. The head's second line says the memory
// (`memoryLine`). What the box shares with the page is `FitPage`. A download's step changes only its line's words
// and bar (`stepOn`), so a menu or a question open on another line stays.
import { cancelFitModel, downloadFitModel, removeFitModel } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import type { FitModel } from "../api/generated/FitModel";
import type { FitView } from "../api/generated/FitView";
import type { PickedView } from "../api/generated/PickedView";
import { el, failure } from "../dom";
import { askUnder, menu } from "../dialogs";
import { bytes } from "../format";
import { percent } from "./downloaded";
import { kindOf } from "./kinds";
import { language, wording } from "../language/language";
import { failureWords } from "../language/errors";

/** What the box's lines need of the page. */
export interface FitPage {
  attempt(action: () => Promise<void>): Promise<boolean>;
  say(text: string): void;
  /** Takes the list anew, as an answer gave it. */
  fitted(now: FitView): void;
}

/** The head's second line: the memory, where the server could tell it, and the folder. */
export function memoryLine(memory: number | null, folder: string): string {
  return memory === null ? folder : wording("fit-models-gb-of-memory", { round: Math.round(memory / 1024 ** 3), folder });
}

/** The kinds at the model `file` of This computer `own`, by their names. */
export function usedFor(kinds: PickedView[], own: EntryView, file: string): string[] {
  return kinds.filter((each) => each.provider_id === own.id && each.model === file).map((each) => kindOf(each.kind).label);
}

/** What a model's line says in grey under its name. */
export function fitSays(model: FitModel, used: string[]): string {
  const fits = model.fits ? wording("fit-models-fits", { size: bytes(model.size) }) : wording("fit-models-too-large", { size: bytes(model.size) });
  if (model.state === "downloading") return wording("fit-models-downloading", { fits, percent: percent(model) });
  if (model.state === "absent") return fits;
  if (used.length) return wording("fit-models-used-for", { fits, kinds: new Intl.ListFormat(language()).format(used) });
  return model.offered ? wording("fit-models-downloaded", { fits }) : fits;
}

/** Whether `now` differs from `before` only in how far its downloads are. */
export function onlySteps(before: FitView, now: FitView): boolean {
  const shape = (fit: FitView) => JSON.stringify(fit.models.map(({ file, state, failure, fits }) => [file, state, failure, fits]));
  return before.memory === now.memory && shape(before) === shape(now);
}

/** Has the downloading lines in `box` say how far `fit`'s downloads are. */
export function stepOn(box: HTMLElement, fit: FitView): void {
  for (const model of fit.models.filter((each) => each.state === "downloading")) {
    const line = [...box.querySelectorAll<HTMLElement>(".fit-model")].find((each) => each.dataset.file === model.file);
    if (!line) continue;
    line.querySelector(".meta")!.textContent = fitSays(model, []);
    const done = line.querySelector<HTMLElement>("[role=progressbar] > div");
    if (done) done.style.width = `${percent(model)}%`;
  }
}

/** The lines of the models of `fit`, at This computer `own` with the account's `kinds`. */
export function fitLines(page: FitPage, fit: FitView, own: EntryView, kinds: PickedView[]): HTMLElement[] {
  return fit.models.map((model) => line(page, model, usedFor(kinds, own, model.file)));
}

function line(page: FitPage, model: FitModel, used: string[]): HTMLElement {
  const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, model.name), el("span", { className: "meta" }, fitSays(model, used)));
  const node = el("div", { className: "item item-sub fit-model" }, text);
  node.dataset.file = model.file;
  if (model.state === "downloading") {
    const done = el("div");
    done.style.width = `${percent(model)}%`;
    text.append(el("div", { className: "bar bar-fixed mt-8", role: "progressbar", ariaLabel: wording("voices-language-downloaded", { name: model.name }) }, done));
  }
  if (model.failure) text.append(failure(failureWords(model.failure)));
  const act = (call: () => Promise<FitView>) => () => void page.attempt(async () => page.fitted(await call()));
  if (model.state === "downloading") {
    node.append(el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("fit-models-cancel", { name: model.name }), onclick: act(() => cancelFitModel(model.file)) }, wording("common-cancel")));
  } else if (model.state === "absent") {
    if (model.fits) node.append(el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: wording("fit-models-download", { name: model.name }), onclick: act(() => downloadFitModel(model.file)) }, wording("update-download")));
    else text.classList.add("faded");
  } else if (model.offered) {
    node.append(there(page, model));
  }
  return node;
}

/** The tools of a model of Cardwave's list while it is there: "…" with Delete. */
function there(page: FitPage, model: FitModel): HTMLElement {
  const more = menu(wording("fit-models-model-menu-delete", { name: model.name }), [{ label: wording("common-delete"), shape: "trash", danger: true, action: () => ask() }]);
  const tools = el("div", { className: "provider-tools lv" }, more);
  function ask(): void {
    const remove = () =>
      void page.attempt(async () => {
        page.fitted(await removeFitModel(model.file));
        page.say(wording("fit-models-model-deleted", { name: model.name }));
      });
    askUnder(tools, more.querySelector("button")!, wording("fit-models-delete-this-model", { size: bytes(model.size) }), wording("common-delete"), remove);
  }
  return tools;
}
