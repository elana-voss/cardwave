// The kinds of model the account has, each at one of its providers (Settings › Providers and › Models): what a
// kind's line says, the models each provider offers (`catalogs`, asked once per provider and page, `forget` lets
// them go), and the model picker of one kind (`pickKind`, board "Model picker · one kind"): a dialog named by
// the kind ("Images model") with the search field "Model", the hint, and the list as part of it, the models of
// that kind of every provider under the provider's name (`.kind-group`), the one in use ticked and light blue
// (`.opt.on`), "Use this model" and Cancel. A provider that does not say what kind a model is has all its models
// under it and what is not known of it after its name (`Catalog.said`); one whose list did not come, or of which
// none of the kind came, says why, with "Retry". Taking a model of another provider moves the kind there
// (`pickModel` of api/client.ts). Search and Voice have first the group "This computer" with its downloaded
// model (`ProvidersView.own`, as the server names it), which takes the kind back from its provider (`unpickKind`).
import { pickModel, providerModels, unpickKind } from "../api/client";
import type { Catalog } from "../api/generated/Catalog";
import type { EntryView } from "../api/generated/EntryView";
import type { Kind } from "../api/generated/Kind";
import type { OfferedModel } from "../api/generated/OfferedModel";
import type { ProvidersView } from "../api/generated/ProvidersView";
import { el, failure, reason, told } from "../dom";
import { dialog } from "../dialogs";
import { icon } from "../icons";
import { field, modelCount } from "./provider-form";
import { LABELS } from "../setting-labels";
import { wording } from "../language/language";
import { failureWords } from "../language/errors";

/** Each kind of model: its line's name, its picker's title, and the hint over the picker's list. */
export const modelKinds = (): { kind: Kind; label: string; title: string; hint: string }[] => ([
  { kind: "chat", label: LABELS.settings.chat, title: wording("kinds-chat-model"), hint: wording("kinds-models-from-all-your") },
  { kind: "background", label: LABELS.advanced.background, title: wording("setup-helper-model"), hint: wording("kinds-models-from-all-your-2") },
  { kind: "images", label: LABELS.settings.images, title: wording("kinds-images-model"), hint: wording("kinds-models-from-all-your-3") },
  { kind: "search", label: LABELS.settings.search, title: wording("kinds-search-model"), hint: wording("kinds-models-on-this-computer") },
  { kind: "voice", label: LABELS.settings.voice, title: wording("label-voices-model"), hint: wording("kinds-models-on-this-computer-2") },
]);

export const kindOf = (kind: Kind) => modelKinds().find((each) => each.kind === kind)!;

/** Whether `model` is one of `kind`'s, where its provider says what kinds its models are. */
export const fits = (kind: Kind, model: OfferedModel) =>
  kind === "images" ? model.image : kind === "search" ? model.search : kind === "voice" ? model.voice : model.text;

/** The models of `kind` a provider offers: all of them where it does not say their kinds. */
export const offeredFor = (kind: Kind, catalog: Catalog) => (catalog.said ? catalog.models.filter((model) => fits(kind, model)) : catalog.models);

/** A provider's list of models as the page knows it: on its way, come, or why not. */
export type Listed = "asking" | Catalog | { error: string };

/** The providers' models, each asked once while the page is open. */
export interface Catalogs {
  /** What is known of the provider `id`'s models; asks for them where they were not asked. */
  of(id: number): Listed;
  /** Asks the provider `id` for its models anew. */
  ask(id: number): void;
  /** Lets every list go: a provider's address or key may be another now. */
  forget(): void;
  /** Has `show` told too whenever a list has come, until the answer is called. */
  listen(show: () => void): () => void;
}

/** Makes the providers' models of a page. `changed` is told whenever a list has come. */
export function catalogs(changed: () => void): Catalogs {
  const known = new Map<number, Listed>();
  const listening = new Set<() => void>();
  /** The asking whose answer counts, per provider. */
  const asking = new Map<number, object>();
  function ask(id: number): void {
    const mine = {};
    asking.set(id, mine);
    known.set(id, "asking");
    const came = (listed: Listed) => {
      if (asking.get(id) !== mine) return;
      known.set(id, listed);
      changed();
      for (const show of listening) show();
    };
    providerModels(id).then(
      (catalog) => came(catalog.failed && !catalog.models.length ? { error: failureWords(catalog.failed) } : catalog),
      (error) => came({ error: told(error) }),
    );
  }
  return {
    of(id) {
      if (!known.has(id)) ask(id);
      return known.get(id)!;
    },
    ask,
    forget() {
      known.clear();
      asking.clear();
    },
    listen(show) {
      listening.add(show);
      return () => listening.delete(show);
    },
  };
}

/** What a provider's "Not used" line says of its models. */
export function countOf(listed: Listed): string {
  if (listed === "asking") return wording("kinds-loading-models");
  if ("error" in listed) return wording("kinds-couldnt-load-the-models");
  return modelCount(listed.models.length);
}

/** Whether the model `id` of the provider `provider` thinks before it replies, as far as its list says. */
export function thinks(listed: Listed, id: string): boolean {
  return typeof listed === "object" && "models" in listed && listed.models.some((model) => model.id === id && model.thinks);
}

/** A provider's name as the server sends it, with the page's words for a server on this computer, which it sends unnamed. */
export const providerName = (name: string) => name || wording("kinds-this-computer");

/** Whether an address is a server on this computer. */
export const local = (address: string) => /^https?:\/\/(127\.0\.0\.1|localhost|\[::1\])(:|\/|$)/i.test(address);

/** The address a provider's heading adds in grey: a server on this computer the user did not name, which the server calls only that. */
export function addressOf(provider: EntryView): string | null {
  if (provider.own_name !== null || provider.folder !== null || !local(provider.base_url)) return null;
  try {
    return new URL(provider.base_url).host;
  } catch {
    return provider.base_url;
  }
}

/** What a kind's line says: its model and, where `at` names it, its provider. */
export function says(view: ProvidersView, kind: Kind, at = true): string | null {
  const picked = view.kinds.find((each) => each.kind === kind);
  if (!picked) return null;
  const provider = view.providers.find((each) => each.id === picked.provider_id);
  return at && provider ? `${picked.model} · ${providerName(provider.name)}` : picked.model;
}

/**
 * Opens the model picker of `kind` in `home`, over the models of every provider in `view`, the kind's model
 * marked; the model taken is stored at once, and the account as it stands then goes to `taken`.
 */
export function pickKind(home: HTMLElement, kind: Kind, view: ProvidersView, lists: Catalogs, taken: (now: ProvidersView) => void): void {
  const { title, hint } = kindOf(kind);
  const now = view.kinds.find((each) => each.kind === kind);
  const own = view.own.find((each) => each.kind === kind)?.model;
  // `provider` null: this computer's model.
  let chosen: { provider: number | null; model: string } | null = now ? { provider: now.provider_id, model: now.model } : own ? { provider: null, model: own } : null;
  const search = el("input", { name: "model_search", className: "field", placeholder: wording("kinds-search-the-models"), autocomplete: "off" });
  const list = el("div", { className: "kind-list rel", role: "listbox", ariaLabel: wording("settings-models") });
  const wrong = el("div");
  const use = el("button", { type: "submit", className: "primary btn btn-primary" }, wording("kinds-use-this-model"));
  const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
  const form = el(
    "form",
    { className: "dlg-body" },
    field(wording("kinds-model"), search),
    el("p", { className: "hint kind-hint" }, hint),
    list,
    wrong,
    el("div", { className: "actions flex g-8" }, use, cancel),
  );
  const box = dialog(home, title, form);
  box.classList.add("picker", "kind-picker");
  cancel.onclick = () => box.close();

  /** One provider's heading and its models of the kind that have what is typed. */
  function group(provider: EntryView): HTMLElement[] {
    const listed = lists.of(provider.id);
    const known = typeof listed === "object" && "models" in listed && !listed.said;
    const address = addressOf(provider);
    const head = el(
      "div",
      { className: "kind-group ogh" },
      providerName(provider.name),
      address !== null && el("span", { className: "meta" }, wording("kinds-address", { address })),
      known && el("span", { className: "meta" }, wording("kinds-type-unknown")),
    );
    if (listed === "asking") return [head, el("p", { className: "meta kind-note" }, wording("kinds-asking-the-provider"))];
    const failed = (error: string) => {
      const again = el("button", { type: "button", className: "link textbtn" }, wording("setup-try-again"));
      again.onclick = () => lists.ask(provider.id);
      return [head, el("div", { className: "kind-note listed" }, failure(reason(error)), again)];
    };
    if ("error" in listed) return failed(listed.error);
    const typed = search.value.trim().toLowerCase();
    const models = offeredFor(kind, listed).filter((model) => model.id.toLowerCase().includes(typed));
    // A list that came in part (the picture models without the text models) says why where the kind has none.
    if (!models.length && listed.failed && !typed) return failed(failureWords(listed.failed));
    if (!models.length) return typed ? [] : [head, el("p", { className: "meta kind-note" }, wording("kinds-no-such-model"))];
    return [head, ...models.map((model) => option(provider.id, model.id, model.id))];
  }
  /** A model's line, ticked where it is the one chosen. */
  function option(provider: number | null, id: string, label: string): HTMLElement {
    const on = chosen?.provider === provider && chosen.model === id;
    const line = el("button", { type: "button", role: "option", className: on ? "opt on" : "opt", ariaSelected: String(on) }, el("span", null, label), on && icon("check", 16));
    line.onclick = () => {
      chosen = { provider, model: id };
      draw();
    };
    line.ondblclick = () => form.requestSubmit();
    return line;
  }
  /** The group "This computer", where the kind has a model of its own that has what is typed. */
  function ownGroup(): HTMLElement[] {
    if (!own || !own.toLowerCase().includes(search.value.trim().toLowerCase())) return [];
    return [el("div", { className: "kind-group ogh" }, wording("label-providers-this-computer")), option(null, own, wording("kinds-own-on-this-computer", { own }))];
  }
  function draw(): void {
    const top = list.scrollTop;
    list.replaceChildren(...ownGroup(), ...view.providers.flatMap(group));
    list.scrollTop = top;
    use.disabled = !chosen;
  }
  search.addEventListener("input", draw);
  form.onsubmit = async (event) => {
    event.preventDefault();
    if (!chosen) return;
    use.disabled = true;
    try {
      const after = chosen.provider === null ? await unpickKind(kind) : await pickModel(kind, { provider_id: chosen.provider, model: chosen.model });
      box.close();
      taken(after);
    } catch (error) {
      wrong.replaceChildren(failure(reason(error)));
      use.disabled = false;
    }
  };
  draw();
  // Each list that comes is shown while the picker is open.
  box.addEventListener("close", lists.listen(draw));
  search.focus();
}
