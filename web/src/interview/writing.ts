// The read-back's foot (boards MkWriting, MkWriteFailed, MkDeclined): the button that writes, the row while it writes,
// the failure in red over the button, and a model's refusal with its two ways on. "Try another model" lists the
// account's text models, but the chat model and the one just tried, each "[model] · [provider]"; the pick holds for
// this writing alone and is stored nowhere.
//
// Trap: the list comes over the network: the button stands off until it is there, and stays off with none. A provider
// that does not answer is left out of it.
import { getProviderList, providerModels } from "../api/client";
import type { OtherModel } from "../api/generated/OtherModel";
import { menuOn, type MenuItem } from "../dialogs";
import { el } from "../dom";
import { wording } from "../language/language";

type Other = OtherModel & { label: string };

const button = (className: string, words: string, press: () => void) => el("button", { type: "button", className, onclick: press }, words);

/** The models to offer instead of the chat model and `tried`. */
export async function otherModels(tried: OtherModel | null): Promise<Other[]> {
  const list = await getProviderList();
  const chat = list.kinds.find((picked) => picked.kind === "chat");
  const offers = await Promise.allSettled(list.providers.map((entry) => providerModels(entry.id)));
  const same = (one: OtherModel, other: OtherModel | null | undefined) => other?.provider_id === one.provider_id && other.model === one.model;
  return offers.flatMap((offer, at) => {
    if (offer.status === "rejected") return []; // A provider down has nothing to offer; the others do.
    const entry = list.providers[at];
    return offer.value.models
      .filter((model) => model.text)
      .map((model) => ({ provider_id: entry.id, model: model.id, label: wording("interview-model-provider", { model: model.id, provider: entry.name }) }))
      .filter((one) => !same(one, chat) && !same(one, tried));
  });
}

/** "Write the character", with the failure over it where the last writing failed. */
export function writeRow(why: string | null, press: () => void): HTMLElement {
  const write = el("div", { className: "flex f-col g-6" }, el("div", {}, button("btn btn-primary", wording("interview-make"), press)), el("p", { className: "hint" }, wording("interview-make-after")));
  if (why === null) return write;
  return el("div", { className: "flex f-col g-10" }, el("p", { className: "m0 c-danger fs-small", role: "alert" }, why), write);
}

/** The button while the character is written, and Stop. */
export function writingRow(stop: () => void): HTMLElement {
  const busy = el("button", { type: "button", className: "btn btn-primary", disabled: true }, wording("gen-writing"));
  return el("div", { className: "flex g-8" }, busy, button("btn btn-secondary", wording("gen-stop"), stop));
}

/** The refusal in the page's ink, and its two ways on. */
export function declinedRow(args: { why: string; tried: OtherModel | null; pick: (model: OtherModel) => void; without: () => void }): HTMLElement {
  const { why, tried, pick, without } = args;
  const off = el("button", { type: "button", className: "btn btn-secondary", disabled: true }, wording("interview-try-another"));
  const own = button("btn btn-secondary", wording("interview-without-topic"), without);
  const row = el("div", { className: "flex g-8 wrap" }, off, own);
  void otherModels(tried).then(
    (models) => {
      if (models.length === 0) return;
      const items: MenuItem[] = models.map(({ label, provider_id, model }) => ({ label, action: () => pick({ provider_id, model }) }));
      const open = el("button", { type: "button", className: "btn btn-secondary" }, wording("interview-try-another"));
      off.replaceWith(el("div", { className: "model-menu" }, menuOn(open, items)));
    },
    () => {}, // No list: the button stays off, and the other way stands.
  );
  return el("div", { className: "flex f-col g-10" }, el("p", { className: "m0", role: "alert" }, why), row);
}
