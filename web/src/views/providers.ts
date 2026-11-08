// Settings › Providers, at `#/settings/providers` (board "Providers"): "Settings / Providers", a grey box per
// provider (`.group.provider`) in the order added, and "Add provider" (first run's step 1, setup/key-step.ts,
// in a dialog). A box's head (`.provider-head`): the name, where it is (`whereOf`) and "…" with Edit (address
// and key, "Remove key") and Remove (asks in the menu's place). Under it a line per kind at it, what model it
// uses, chosen only in Settings › Models (proposal 18 of 88, the owner), under a model that thinks or whose thinking is off the line "Thinking" (`thinkingSays`),
// whose switch has the server try the forms of turning it off; a provider no kind is at says "Not used · [n]
// models"; a ComfyUI has the line "Workflow" (`workflowChoices`), the background model finding
// where the words go, which under a saved workflow says that it uses its own models and size (`workflowNote`). This computer's account has first the box "This computer" (`.group.this-computer`, no
// `.provider`): the memory and the folder of its GGUF models, or "Not set up", with "Choose"/"Change" (dialogs.ts's
// dialog "Folder"), no Edit or Remove, no "Not used"; under its kind lines the models that fit (fit-models.ts).
// The event `provider` and the server heard again read the page anew, `local_models` that list; the lists of
// models are asked once per page, and again after an Edit, a folder or a model downloaded or removed. Each part of a box is a function of
// the page's shared state (`Page`), which `providersView` makes.
import { wording } from "../language/language";
import { account } from "../account";
import { addProvider, changeProviderEntry, getFitModels, getProviderList, removeProvider, setThinking, setThisComputer, setWorkflow } from "../api/client";
import type { EntryView } from "../api/generated/EntryView";
import type { FitView } from "../api/generated/FitView";
import type { Kind } from "../api/generated/Kind";
import type { PickedView } from "../api/generated/PickedView";
import type { ProvidersView } from "../api/generated/ProvidersView";
import type { ServerEvent } from "../api/generated/ServerEvent";
import { announce, el, failure, item, latest, noticeBox, oneAtATime, reason, selectField, switchBox, type Choice, type View } from "../dom";
import { askUnder, dialog, folderDialog, formDialog, menu } from "../dialogs";
import { fitLines, memoryLine, onlySteps, stepOn } from "../models/fit-models";
import { icon } from "../icons";
import { type Catalogs, catalogs, countOf, local, modelKinds, providerName, thinks } from "../models/kinds";
import { field, keyStored, plain } from "../models/provider-form";
import { keyStep } from "../setup/key-step";
import { LABELS } from "../setting-labels";

/** A provider's picked kinds, in the order of `modelKinds`. */
const pickedAt = (view: ProvidersView, id: number) => modelKinds().flatMap(({ kind }) => view.kinds.filter((each) => each.kind === kind && each.provider_id === id));
/** The provider of this computer's models, where the account has one. */
const ownOf = (view: ProvidersView | null) => view?.providers.find((provider) => provider.folder !== null);

/** Where a provider is, as its box says: the host, or the whole address of a server on this computer; and its key. */
export function whereOf(provider: EntryView): string {
  let where = provider.base_url;
  if (!local(where)) {
    try {
      where = new URL(where).host;
    } catch {
      // An address that is no URL is shown as it is.
    }
  }
  if (provider.key_end) return wording("providers-key-end", { where, end: provider.key_end });
  return provider.has_key ? wording("providers-key-saved", { where }) : wording("providers-no-key", { where });
}

/** What the line "Thinking" says, or `null` where it has none: a model that does not think and whose thinking was never turned off. */
export function thinkingSays(picked: PickedView, thinker: boolean, provider: string): string | null {
  if (picked.thinking === "cannot") return wording("providers-thinking-cannot", { provider });
  if (picked.thinking === "off") return wording("providers-thinking-off");
  return thinker ? wording("providers-thinking-on") : null;
}

/** What the field "Workflow" offers: ComfyUI's default one, then the saved ones by name, and the one picked where ComfyUI no longer has it. */
export function workflowChoices(names: string[], picked: string | null): Choice[] {
  const all = picked !== null && !names.includes(picked) ? [...names, picked] : names;
  return [{ value: "", label: wording("providers-comfy-default") }, ...all.map((name) => ({ value: name, label: name.replace(/\.json$/i, "") }))];
}

/** What the line "Workflow" says under it of the workflow picked: a saved one's own models and size; nothing of the default. */
export function workflowNote(picked: string | null): string | null {
  return picked === null ? null : wording("providers-workflow-note");
}

/** What the parts of the page share: its node, what it shows, and how it is changed and read anew. */
interface Page {
  node: HTMLElement;
  view: ProvidersView | null;
  /** Whether the account is this computer's, whose models it may run. */
  local: boolean;
  /** The kind whose thinking is being turned on or off. */
  turning: Kind | null;
  /** The provider whose workflow is being picked. */
  finding: number | null;
  /** This computer's models that fit, once its folder is chosen. */
  fit: FitView | null;
  lists: Catalogs;
  attempt: ReturnType<typeof oneAtATime>;
  say: typeof announce;
  took(now: ProvidersView): void;
  /** Takes This computer's models anew, and has its list of models asked again where the files there changed. */
  fitted(now: FitView): void;
  draw(): void;
  read(): Promise<void>;
  readFit(): Promise<void>;
}

/** A kind's line, and its line "Thinking" where it has one. */
function kindLines(page: Page, provider: EntryView, picked: PickedView): HTMLElement[] {
  const { label } = modelKinds().find((each) => each.kind === picked.kind)!;
  const line = item(label, picked.model, el("span"));
  const said = thinkingSays(picked, thinks(page.lists.of(provider.id), picked.model), providerName(provider.name));
  if (!said) return [line];
  const about = el("span", { className: "meta" }, page.turning === picked.kind ? wording("providers-testing-model") : said);
  let control: HTMLElement = el("span");
  if (picked.thinking !== "cannot") {
    const on = switchBox({ checked: picked.thinking === "on", ariaLabel: wording("providers-thinking-of", { label }), disabled: page.turning !== null });
    on.onchange = () =>
      void page.attempt(async () => {
        page.turning = picked.kind;
        page.draw();
        try {
          page.took(await setThinking(picked.kind, on.checked));
        } finally {
          page.turning = null;
          page.draw();
        }
      });
    control = on;
  }
  const thinking = item(wording("providers-thinking"), about, control);
  thinking.classList.add("thinking", "item-sub");
  return [line, thinking];
}

/** A ComfyUI's line "Workflow", with the field of its saved workflows. */
function workflowLine(page: Page, provider: EntryView, names: string[]): HTMLElement {
  const about = el("span", { className: "meta" }, page.finding === provider.id ? wording("providers-testing-workflow") : wording("providers-workflows-from"));
  const choices = workflowChoices(names, provider.workflow);
  const field = selectField(choices, provider.workflow ?? "", (name) =>
    void page.attempt(async () => {
      page.finding = provider.id;
      page.draw();
      try {
        page.took(await setWorkflow(provider.id, name || null));
        page.say(name ? wording("providers-pictures-by", { name: choices.find((each) => each.value === name)!.label }) : wording("providers-pictures-default"));
      } finally {
        page.finding = null;
        page.draw();
      }
    }), { ariaLabel: wording("providers-workflow"), disabled: page.finding !== null });
  const note = workflowNote(provider.workflow);
  return el("div", { className: "item item-sub workflow" }, el("div", { className: "item-text" }, el("span", { className: "item-label" }, wording("providers-workflow")), about, note && el("span", { className: "meta" }, note)), field.node);
}

/** The line of a provider no kind is at: how many models it has. */
function unused(page: Page, provider: EntryView): HTMLElement {
  return item(wording("providers-not-used"), countOf(page.lists.of(provider.id)), el("span"));
}

/** The lines under a provider's head: its kinds, else "Not used", and a ComfyUI's "Workflow". */
function linesOf(page: Page, provider: EntryView): { picked: PickedView[]; lines: HTMLElement[] } {
  const picked = pickedAt(page.view!, provider.id);
  const lines = picked.length ? picked.flatMap((each) => kindLines(page, provider, each)) : [unused(page, provider)];
  const listed = page.lists.of(provider.id);
  if (typeof listed === "object" && "models" in listed && listed.workflows) lines.push(workflowLine(page, provider, listed.workflows));
  return { picked, lines };
}

/** The box "This computer": the folder of its models, chosen in the dialog "Folder" (opened in the box), and, once chosen, its lines. */
function ownBox(page: Page, provider: EntryView | undefined): HTMLElement {
  const folder = provider?.folder ?? null;
  const choose = () =>
    folderDialog(node, wording("label-settings-folder"), folder ?? "", wording("setup-models-example"), wording("setup-models-says"), async (typed) => {
      const now = await setThisComputer(typed);
      page.lists.forget();
      page.fit = null;
      page.took(now);
      await page.readFit();
      page.say(wording("providers-folder-saved"));
    });
  const button = el("button", { type: "button", className: "btn btn-secondary on-box", ariaLabel: folder ? wording("providers-change-folder") : wording("providers-choose-folder"), onclick: choose }, folder ? wording("providers-change") : wording("downloaded-set-up"));
  const where = folder === null ? wording("providers-folder-not-set-up") : page.fit ? memoryLine(page.fit.memory, folder) : folder;
  const head = item(el("span", { className: "item-label semi" }, LABELS.providers.thisComputer), where, el("div", { className: "provider-tools lv" }, button));
  head.classList.add("provider-head", "item-line");
  const kinds = provider ? pickedAt(page.view!, provider.id) : [];
  const lines = kinds.flatMap((each) => kindLines(page, provider!, each));
  if (provider && page.fit) lines.push(...fitLines(page, page.fit, provider, page.view!.kinds));
  const node = el("div", { className: "group this-computer" }, head, ...lines);
  if (provider) node.dataset.provider = String(provider.id);
  return node;
}

/** A provider's box. */
function box(page: Page, provider: EntryView): HTMLElement {
  const more = menu(wording("providers-menu"), [
    { label: wording("common-edit"), shape: "edit", action: () => edit(page, provider) },
    { label: wording("providers-remove"), shape: "trash", danger: true, apart: true, action: () => ask() },
  ]);
  const tools = el("div", { className: "provider-tools lv" }, more);
  const head = item(el("span", { className: "item-label semi" }, providerName(provider.name)), el("span", { className: "meta" }, whereOf(provider)), tools);
  head.classList.add("provider-head", "item-line");
  const { picked, lines } = linesOf(page, provider);
  const node = el("div", { className: "group provider" }, head, ...lines);
  node.dataset.provider = String(provider.id);

  /** Asks on a line of its own under the name, the menu hidden, whether the provider is to be removed, with the models of each kind at it. */
  function ask(): void {
    const remove = () =>
      void page.attempt(async () => {
        await removeProvider(provider.id);
        await page.read();
        page.say(wording("providers-removed", { name: providerName(provider.name) }));
      });
    askUnder(tools, more.querySelector("button")!, picked.length ? wording("providers-remove-with-models") : wording("providers-remove-ask"), wording("providers-remove"), remove);
  }
  return node;
}

/** Edit: the provider's address and key; the key's field says the key stored, and "Remove key" takes it off. */
function edit(page: Page, provider: EntryView): void {
  const address = el("input", { name: "base_url", className: "field", value: provider.base_url, required: true, autocomplete: "off" });
  const key = el("input", { name: "api_key", className: "field f-grow", type: "password", autocomplete: "off", placeholder: keyStored(provider) });
  let removing = false;
  const drop = el("button", { type: "button", className: "btn btn-secondary", hidden: !provider.has_key }, wording("providers-remove-key"));
  drop.onclick = () => {
    removing = true;
    key.value = "";
    key.placeholder = wording("providers-key-removed");
    drop.hidden = true;
  };
  const asked = formDialog(page.node, wording("providers-edit"), [field(wording("setup-address"), address), field(wording("setup-api-key"), key, wording("providers-keep-key"), drop)], async () => {
    const typed = key.value.trim();
    await changeProviderEntry(provider.id, { base_url: plain(address.value), ...(typed ? { api_key: typed } : removing ? { api_key: "" } : {}) });
    asked.close();
    page.lists.forget();
    await page.read();
    page.say(wording("providers-saved", { name: providerName(provider.name) }));
  });
  address.focus();
}

/** "Add provider": first run's step 1 in a dialog; what it hands on is added. */
function adding(page: Page): void {
  const wrong = el("div");
  const step = keyStep((asked) => {
    wrong.replaceChildren();
    addProvider({ base_url: asked.base_url, ...asked.key, ...(asked.name ? { name: asked.name } : {}) }).then(
      async (added) => {
        shown.close();
        await page.read();
        page.say(wording("providers-added", { name: providerName(added.name) }));
      },
      (error) => wrong.replaceChildren(failure(reason(error))),
    );
  });
  const shown = dialog(page.node, wording("providers-add"), el("div", { className: "add-provider" }, step.node, wrong));
  shown.classList.add("adding-provider");
  step.fill(null);
  step.node.hidden = false;
  step.key.focus();
}

export function providersView(): View {
  const notice = noticeBox();
  const boxes = el("div", { className: "provider-boxes flex f-col g-32" });
  const add = el("button", { type: "button", className: "btn btn-secondary", onclick: () => adding(page) }, icon("plus", 16), wording("providers-add"));
  const node = el(
    "section",
    { className: "main main-form providers" },
    el("header", { className: "pbar" }, el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-providers")))),
    el("div", { className: "page-col mt-12" }, el("p", { className: "hint" }, wording("providers-about")), notice, boxes, el("div", null, add)),
  );
  const draw = (): void => {
    if (!page.view) return;
    const own = ownOf(page.view);
    const others = page.view.providers.filter((provider) => provider !== own).map((provider) => box(page, provider));
    boxes.replaceChildren(...(page.local ? [ownBox(page, own)] : []), ...others);
  };
  const page: Page = {
    node,
    view: null,
    local: false,
    turning: null,
    finding: null,
    fit: null,
    lists: catalogs(() => draw()),
    attempt: oneAtATime(notice),
    say: (...said) => {
      if (node.isConnected) announce(...said);
    },
    took: (now) => {
      page.view = now;
      draw();
    },
    fitted: (now) => {
      const there = (fit: FitView | null) => fit?.models.filter((model) => model.state === "downloaded").map((model) => model.file).join("|");
      const own = ownOf(page.view);
      if (own && page.fit && there(page.fit) !== there(now)) page.lists.ask(own.id);
      const steps = page.fit !== null && onlySteps(page.fit, now);
      page.fit = now;
      if (steps) stepOn(boxes, now);
      else draw();
    },
    draw,
    read: latest(notice, () => Promise.all([getProviderList(), account()]), ([now, me]) => {
      page.view = now;
      page.local = me.local;
      const own = ownOf(now);
      if (!own) page.fit = null;
      draw();
      if (page.local && own && !page.fit) void page.readFit();
    }),
    readFit: latest(notice, getFitModels, (now) => page.fitted(now)),
  };

  void page.read();
  return {
    node: node,
    onEvent: (event: ServerEvent) => {
      if (event.type === "provider") void page.read();
      if (event.type === "local_models" && page.fit) void page.readFit();
    },
    onConnected: () => void page.read(),
  };
}
