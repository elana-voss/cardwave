// The image model: the line "Images" of first run's step 2, whose "Set up" or "Change" opens the model picker as
// "Image model", offering the image models the address of step 1 lists with its key (`asked`; a ComfyUI's
// checkpoints too). The model taken, or first run's pick (`hold`), is held until "Confirm" stores it (`held`).
// While the picks are on their way (`at.picking`) and none is held, the line shows the spinner alone; a model
// held, by its readable name alone, nothing having been tried (Fable's design of step 2). `draw` shows it anew.
// Settings › Models has the line of the kind Images instead (kinds.ts).
//
// `imageSays` is what the line says: "Not set up", the model, or the model and its own address's host.
import { getImages, listImageModels } from "../api/client";
import type { ImageModelView } from "../api/generated/ImageModelView";
import type { ListModels } from "../api/generated/ListModels";
import { el, failure, newest, reason } from "../dom";
import { modelLine, modelName, models } from "./provider-form";
import { wording } from "../language/language";

/** What the line says under its name, and its button. */
export function imageSays(model: ImageModelView | null): { says: string; action: string } {
  if (!model) return { says: wording("images-not-set-up"), action: wording("downloaded-set-up") };
  if (!model.base_url) return { says: model.model, action: wording("password-change") };
  let host = model.base_url;
  try {
    host = new URL(model.base_url).host;
  } catch {
    // As it was typed, then.
  }
  return { says: `${model.model} · ${host}`, action: wording("password-change") };
}

/** The line "Images", with the picker it opens in the screen `home` gives; `asked` is the address and key of step 1, `at` whether the picks are on their way and the models' readable names. */
export function imagesLine(
  home: () => HTMLElement,
  asked: () => ListModels,
  at: { picking(): boolean; names(): Record<string, string> },
): { node: HTMLElement; read(): void; draw(): void; held(): string; hold(model: string): void; forget(): void } {
  const shown = modelLine(wording("label-settings-images"), wording("settings-the-image-model"));
  /** The stored image model, `null` for none; not set until the server has said. */
  let stored: ImageModelView | null | undefined;
  /** The model taken in first run, not stored yet. */
  let chosen = "";
  const draw = () => {
    const { says, action } = imageSays(chosen ? { model: chosen, base_url: null, has_key: false, key_end: null } : (stored ?? null));
    const waiting = !chosen && at.picking();
    shown.show(waiting ? el("span", { className: "spinner" }) : chosen ? modelName(chosen, at.names()) : stored === undefined ? "" : says, "", action);
    shown.retry.hidden = true;
  };
  const take = (model: string) => {
    chosen = model;
    draw();
  };
  shown.change.onclick = () => {
    // Asked anew at each opening: the address or its key may be another since.
    const listing = models(home(), asked, () => {}, take, listImageModels);
    listing.pick(chosen || stored?.model || "", wording("images-setup-image-model"));
  };
  const order = newest();
  const read = () => {
    const mine = order.ask();
    getImages().then(
      (model) => {
        if (!order.take(mine)) return;
        stored = model;
        draw();
      },
      (error) => {
        if (!order.take(mine)) return;
        shown.node.querySelector(".item-wrong")?.replaceChildren(failure(reason(error)));
      },
    );
  };
  // Drawn first by the step (`draw`): `at` reaches the step's state, made after this line.
  read();
  return {
    node: shown.node,
    read,
    draw,
    held: () => chosen,
    hold: take,
    forget() {
      chosen = "";
      draw();
    },
  };
}
