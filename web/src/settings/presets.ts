// The group "Model presets" of the page "Advanced": chat models kept under names with their provider and
// sampling, one put in use as the chat model (Settings › Models). `presetsGroup` is `.settings-group.presets`:
// its name with "New preset" (`.group-head`), why something failed (`.note`), the lines (`.item.preset`),
// and what a preset is. A line says the name, "· in use" while the chat model is what it holds, and `about`;
// while pointed at or focused (`.reveal.preset-tools`), "Use" and "More" (Edit, Duplicate, Delete, which asks
// under its line by `askUnder`). "New preset" and Edit are form dialogs: the name, and for Edit the switch
// that has the preset take the chat model and sampling in use.
//
// The page is `PresetForm`: one store at a time (`alone`) and what it reads anew after a preset was put in use
// (`stored`). Use's notice has "Undo" where a chat model was stored before, which puts it back by its number.
// The list is read anew after every change, as which is in use goes by what is stored (`read`); the line acted
// on has the focus then by its "More" (`after`), else "New preset". The notice speaks only while the page is
// in view (`say`).
import { wording } from "../language/language";
import { providerName } from "../models/kinds";
import { changePreset, createPreset, deletePreset, duplicatePreset, listPresets, usePreset } from "../api/client";
import type { PresetView } from "../api/generated/PresetView";
import { announce, atMost, el, item, latest, noticeBox, oneAtATime, switchBox } from "../dom";
import { askUnder, formDialog, menu } from "../dialogs";
import { icon } from "../icons";

/** How many signs a preset's name may have, as the server counts them (`NAME_LIMIT` in crates/cw-provider/src/lib.rs). */
const MAX_NAME = 60;

/** What a preset's line says under its name: whose API it asks, the model, and the temperature where one is set. */
export const about = ({ provider, model, temperature }: PresetView) => [providerName(provider), model, temperature !== null && wording("preset-temperature", { value: String(temperature) })].filter(Boolean).join(" · ");

/** The page the presets stand on, as far as they need it. */
export interface PresetForm {
  /** Runs a store unless the page has one on its way, and answers whether it was begun. */
  alone(store: () => Promise<unknown>): Promise<boolean>;
  /** Shows what is stored now: a preset put in use changed the sampling. */
  stored(): void;
}

/** The group "Model presets". `home` is the screen its dialogs stand in. */
export function presetsGroup(home: () => HTMLElement, form: PresetForm): { node: HTMLElement; read(): Promise<void> } {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const add = el("button", { type: "button", className: "btn btn-quiet", onclick: () => name() }, icon("plus", 16), wording("preset-new"));
  const box = el("div", { className: "group", hidden: true });
  const node = el("section", { className: "settings-group presets" }, el("div", { className: "gh" }, el("h2", null, wording("preset-model-presets")), add), notice, box, el("p", { className: "hint mt-8" }, wording("preset-what")));

  /** Says what was done, as `announce` does, unless the page was left meanwhile: the notice would stand on another screen. */
  const say: typeof announce = (...said) => {
    if (node.isConnected) announce(...said);
  };

  const read = latest(notice, listPresets, (presets) => {
    box.replaceChildren(...presets.map(row));
    box.hidden = !presets.length;
  });

  /**
   * Reads the list anew after something was done to the preset `id`, whose line has the focus then; `null`, or a
   * preset that has no line, gives it to "New preset".
   */
  async function after(id: number | null): Promise<void> {
    await read();
    (box.querySelector<HTMLButtonElement>(`[data-preset="${id}"] .menu > button`) ?? add).focus();
  }

  /**
   * Puts the preset `id` in the stored provider's place, which the form shows then, and answers the number
   * under which the one before is kept.
   */
  async function put(id: number): Promise<number | null> {
    const { before } = await usePreset(id);
    form.stored();
    return before;
  }

  /**
   * Says that a preset is in use, with the way back to the provider `before`. Where the page was storing at
   * that moment the way back is offered again, and where it failed, the notice says why.
   */
  function used(text: string, before: number | null): void {
    if (before === null) return say(text);
    say(text, async () => {
      const back = async () => {
        await put(before);
        await read();
      };
      if (!(await form.alone(back))) used(text, before);
    });
  }

  /** One preset's line. */
  function row(preset: PresetView): HTMLElement {
    const use = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-use"));
    use.onclick = () =>
      void form.alone(() =>
        attempt(async () => {
          const before = await put(preset.id);
          await after(preset.id);
          used(wording("preset-using", { name: preset.name }), before);
        }),
      );
    const copy = () =>
      void attempt(async () => {
        const made = await duplicatePreset(preset.id);
        await after(made.id);
        say(wording("preset-added", { name: made.name }));
      });
    const more = menu(wording("common-more"), [
      { label: wording("common-edit"), shape: "edit", action: () => name(preset) },
      { label: wording("common-duplicate"), shape: "copy", action: copy },
      { label: wording("common-delete"), shape: "trash", danger: true, apart: true, action: () => ask() },
    ]);
    const tools = el("div", { className: "reveal preset-tools flex g-4" }, !preset.in_use && use, more);
    const line = item(el("span", { className: "item-label" }, preset.name, preset.in_use && el("span", { className: "meta" }, wording("common-in-use"))), el("span", { className: "meta" }, about(preset)), tools);
    line.classList.add("preset", "row");
    line.dataset.preset = String(preset.id);

    /** Asks under the line whether the preset is to be deleted, which cannot be taken back. */
    function ask(): void {
      const remove = () =>
        void attempt(async () => {
          await deletePreset(preset.id);
          await after(null);
          say(wording("preset-deleted", { name: preset.name }));
        });
      askUnder(tools, more.querySelector("button")!, wording("preset-delete-ask"), wording("common-delete"), remove);
    }
    return line;
  }

  /**
   * Opens the dialog that names a preset: a new one, which keeps the chat model and sampling in use, or
   * `preset`, which is called otherwise there and, where its switch says so, holds those from then on.
   */
  function name(preset?: PresetView): void {
    const called = el("input", { id: "preset-name", className: "field", name: "preset_name", value: preset?.name ?? "", required: true, autocomplete: "off" });
    atMost(called, MAX_NAME);
    const take = switchBox({ name: "take_form" });
    const taking = el("label", { className: "switch-line flex ai-c g-10" }, el("span", { className: "f-grow" }, wording("preset-replace")), take);
    const hint = preset
      ? wording("preset-replace-hint")
      : wording("preset-keeps-hint");
    const fields = [el("div", { className: "fld" }, el("label", { htmlFor: called.id }, wording("preset-name")), called, preset ? taking : null, el("small", { className: "meta" }, hint))];
    const asked = formDialog(home(), preset ? wording("preset-edit") : wording("preset-new"), fields, async () => {
      const kept = preset ? await changePreset(preset.id, { name: called.value, replace: take.checked }) : await createPreset({ name: called.value });
      asked.close();
      await after(kept.id);
      say(wording("preset-saved", { name: kept.name }));
    });
    // The name is what is typed there, so its field has the focus, not the × before it.
    called.focus();
  }

  return { node, read };
}
