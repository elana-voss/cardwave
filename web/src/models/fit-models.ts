// The models that fit this computer, in Settings › Providers' box "This computer" under its kind lines (board
// "Settings › Providers, models that fit", milestone 74; plainer in 144): Cardwave's list, a line each
// (`.item.fit-model`), indented: the name, and in grey "Runs on this computer" or "Too large for this computer",
// then "downloading [n]%", "downloaded" or "used for [kinds]" (`fitSays`). Behind the box's "Details" stand the
// folder's own GGUF files by their file names, and while it is open every line says its size too. The head says
// what runs (`runsLine`); "Details" the memory and the folder (`memoryLine`). One too large is greyed and has no
// button; one absent has "Download", one downloading its bar and "Cancel", one there, of Cardwave's list, "…" with
// Remove, which asks in the menu's place; a model is chosen for a kind only in Settings › Models. A download's
// failure stands in red under its line. What the box shares with the page is `FitPage`. A download's step changes
// only its line's words and bar (`stepOn`), so a menu or a question open on another line stays.
import { cancelFitModel, downloadFitModel, removeFitModel } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import type { FitModel } from "../api/generated/FitModel";
import type { FitView } from "../api/generated/FitView";
import type { PickedView } from "../api/generated/PickedView";
import { el, failure } from "../dom";
import { menuDeleting } from "../dialogs";
import { bytes, names } from "../format";
import { percent } from "./downloaded";
import { kindOf } from "./kinds";
import { modelCount } from "./provider-form";
import { wording } from "../language/language";
import { failureWords } from "../language/errors";

/** What the box's lines need of the page. */
export interface FitPage {
  attempt(action: () => Promise<void>): Promise<boolean>;
  say(text: string): void;
  /** Takes the list anew, as an answer gave it. */
  fitted(now: FitView): void;
}

/** The line behind "Details": the memory, where the server could tell it, and the folder. */
export function memoryLine(memory: number | null, folder: string): string {
  return memory === null ? folder : wording("fit-models-gb-of-memory", { round: Math.round(memory / 1024 ** 3), folder });
}

/** The kinds at the model `file` of This computer `own`, by their names. */
export function usedFor(kinds: PickedView[], own: EntryView, file: string): string[] {
  return kinds.filter((each) => each.provider_id === own.id && each.model === file).map((each) => kindOf(each.kind).label);
}

/** What a model's line says in grey under its name; its size only where `sized` (while "Details" is open). */
export function fitSays(model: FitModel, used: string[], sized = false): string {
  const says = model.fits ? wording("fit-models-fits") : wording("fit-models-too-large");
  const fits = sized ? wording("fit-models-sized", { size: bytes(model.size), says }) : says;
  if (model.state === "downloading") return wording("fit-models-downloading", { fits, percent: percent(model) });
  if (model.state === "absent") return fits;
  if (used.length) return wording("fit-models-used-for", { fits, kinds: names(used) });
  return model.offered ? wording("fit-models-downloaded", { fits }) : fits;
}

/** Whether `now` differs from `before` only in how far its downloads are. */
export function onlySteps(before: FitView, now: FitView): boolean {
  const shape = (fit: FitView) => JSON.stringify(fit.models.map(({ file, state, failure, fits }) => [file, state, failure, fits]));
  return before.memory === now.memory && shape(before) === shape(now);
}

/** What the box's head says runs: how many models are there and fit, or that none is yet. */
export function runsLine(fit: FitView): string {
  const ready = fit.models.filter((model) => model.fits && model.state === "downloaded").length;
  return ready ? wording("providers-this-computer-runs", { models: modelCount(ready) }) : wording("providers-this-computer-none");
}

/** Has the downloading lines in `box` say how far `fit`'s downloads are, sized as `sized` says. */
export function stepOn(box: HTMLElement, fit: FitView, sized: boolean): void {
  for (const model of fit.models.filter((each) => each.state === "downloading")) {
    const line = [...box.querySelectorAll<HTMLElement>(".fit-model")].find((each) => each.dataset.file === model.file);
    if (!line) continue;
    line.querySelector(".meta")!.textContent = fitSays(model, [], sized);
    const done = line.querySelector<HTMLElement>("[role=progressbar] > div");
    if (done) done.style.width = `${percent(model)}%`;
  }
}

/** Has every model's line in `box` say its size or not, as `sized` says, at This computer `own` with the account's `kinds`. */
export function resize(box: HTMLElement, fit: FitView, own: EntryView, kinds: PickedView[], sized: boolean): void {
  for (const line of box.querySelectorAll<HTMLElement>(".fit-model")) {
    const model = fit.models.find((each) => each.file === line.dataset.file);
    if (model) line.querySelector(".meta")!.textContent = fitSays(model, usedFor(kinds, own, model.file), sized);
  }
}

/** The lines of the models of `fit`, at This computer `own` with the account's `kinds`: Cardwave's list `shown`,
 * the folder's own files (by their file names) behind "Details"; sizes only where `sized`. */
export function fitLines(page: FitPage, fit: FitView, own: EntryView, kinds: PickedView[], sized: boolean): { shown: HTMLElement[]; behind: HTMLElement[] } {
  const of = (offered: boolean) => fit.models.filter((model) => model.offered === offered).map((model) => line(page, model, usedFor(kinds, own, model.file), sized));
  return { shown: of(true), behind: of(false) };
}

function line(page: FitPage, model: FitModel, used: string[], sized: boolean): HTMLElement {
  const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, model.name), el("span", { className: "meta" }, fitSays(model, used, sized)));
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
  const remove = () =>
    void page.attempt(async () => {
      page.fitted(await removeFitModel(model.file));
      page.say(wording("fit-models-model-deleted", { name: model.name }));
    });
  const question = () => wording("fit-models-delete-this-model", { size: bytes(model.size) });
  const more = menuDeleting(wording("fit-models-model-menu-delete", { name: model.name }), [], { label: wording("common-delete"), question, yes: wording("common-delete"), action: remove });
  return el("div", { className: "provider-tools lv" }, more);
}
