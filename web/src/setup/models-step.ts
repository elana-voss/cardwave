// First run's second step, "Models" (board "First run · step 2"; the owner's design of 2026-11-08, docs/design.md),
// and which step shows. A `.group` of lines: the key's (`keyText`, no button: "Back" returns to step 1), the chat
// model's (`chat`, its picker `listing`, its test `check`), the background model's (`workerLine`, `workerCheck`), the
// image model's (images-setup.ts, held until "Continue"); then "Language the AI writes in" (language-line.ts),
// stored at once.
//
// Without a chat model, the provider added last stands for the stored one (`storedFor`). With an address or key new to it, the step opens with the server's picks (`pick`, crates/cw-provider/src/picks.rs):
// a model of each kind, chat and background then tested with the small question, images not. While that runs, the
// lead under the title turns the one spinner and each open line a spinner alone; a line shows only its result, by
// the model's readable name (models-state.ts, which also holds the 8 s and 30 s rules and when Continue waits). A
// helper model that did not answer is stored as none: the chat model does its work. "Change" opens the picker of
// that kind. "Continue" stores the provider and the image model at once; this computer's account goes on
// to step 3, the folder of cards (cards-step.ts), another back to where the user came from. After step 3
// (`toDownloads`), where a download can be made, step 4 asks which (`choice`, downloads-step.ts); its button stores
// them as not through (`setup_downloads`) and shows their bars (`downloading`). Setup's end (`openApp`) stores the
// folder of cards step 3 held and imports its cards; views/setup.ts makes the state (`Setup`).
import { wording } from "../language/language";
import { failureWords } from "../language/errors";
import { changeSettings, getProvider, getProviderList, getSettings, pickModels, setProvider } from "../api/client";
import type { NamedPicks } from "../api/generated/NamedPicks";
import type { ProvidersView } from "../api/generated/ProvidersView";
import type { ProviderView } from "../api/generated/ProviderView";
import { announce, el, failure, item, reason, told } from "../dom";
import { useCardFolder } from "../library/card-folder";
import { imagesLine } from "../models/images-setup";
import { languageLine } from "../models/language-line";
import { modelLine, modelName, type models, type ModelTest } from "../models/provider-form";
import { LABELS } from "../setting-labels";
import type { cardsStep } from "./cards-step";
import { downloadsChosen, firstRunLeft, type downloadsChoice, type downloadsStep } from "./downloads-step";
import type { Asked, KeyStep, Stored } from "./key-step";
import { chatAction, greyed, keyLine, lead, workClock, type StepState } from "./models-state";

/** How much of a key the line for it shows, of a key at least so long: as the server tells of a stored one (`Provider::key_end` in `crates/cw-provider/src/lib.rs`, which has the same two numbers). */
const KEY_END = 4;
const KEY_END_FROM = 16;

/** What stands behind a model's name once its test passed, with the blue tick. */
export const tested = () => wording("setup-works");
/** The one spinner of the design system: the lead's, and an open line's alone. */
const spinner = () => el("span", { className: "spinner" });

/** A quiet button to Settings › Providers: step 1 says it to enter the address there. */
export const settingsButton = (words: string) => el("button", { type: "button", className: "btn btn-quiet", onclick: () => (location.hash = "#/settings/providers") }, words);

/** Step 2's elements; `home` is the screen, `whom` the address and key of step 1, `at` what the image line needs of the step. */
export function modelsParts(home: () => HTMLElement, whom: () => Asked, at: { picking(): boolean; names(): Record<string, string> }) {
  const keyLine = el("span", { className: "meta" });
  const chat = modelLine();
  const workerLine = modelLine(LABELS.advanced.background, wording("setup-the-helper-model"));
  const images = imagesLine(home, () => ({ base_url: whom().base_url, ...whom().key }), at);
  const language = languageLine();
  const confirm = el("button", { type: "button", className: "btn btn-primary btn-lg" }, wording("setup-continue"));
  const backButton = el("button", { type: "button", className: "btn btn-quiet" }, wording("setup-back"));
  const second = el(
    "div",
    { className: "setup-step flex f-col g-28", hidden: true },
    el("div", { className: "group" }, item(wording("setup-title-1"), keyLine, el("span")), chat.node, workerLine.node, images.node),
    language.notice,
    el("div", { className: "group" }, language.node),
    el("div", { className: "setup-actions flex ai-c g-10 wrap" }, confirm, backButton),
  );
  return { second, keyLine, chat, workerLine, images, confirm, backButton };
}

/** First run's state, and the parts its drawing reaches. */
export interface Setup extends ReturnType<typeof modelsParts> {
  /** The address the app opens at after first run: the screen the user came from. */
  back: string;
  node: HTMLElement;
  /** Which step it is, its name, and the line under it. */
  where: HTMLElement;
  title: HTMLElement;
  about: HTMLElement;
  first: KeyStep;
  cards: ReturnType<typeof cardsStep>;
  /** Step 4 as it asks which downloads, and then its bars, once they began (`downloading`). */
  choice: ReturnType<typeof downloadsChoice>;
  third: ReturnType<typeof downloadsStep>;
  downloading: boolean;
  notice: HTMLElement;
  attempt: (action: () => Promise<void>) => Promise<boolean>;
  /** The stored provider, when the setup is gone through again, else the one added last while no chat model is chosen. */
  stored: Stored | null;
  /** Whether this computer's account it is, which alone downloads the voice and the search model. */
  local: boolean;
  /** The step shown; 0 until it is known whether a provider is stored. 3 is the folder of cards, 4 the downloads. */
  step: 0 | 1 | 2 | 3 | 4;
  /** Whom step 2 asks: the address and the key as step 1 gave them. Another address or key is another one of these. */
  asked: Asked | null;
  /** The picks on their way (the asking whose answer counts), what they came to, and why they did not come. */
  picking: object | null;
  picked: NamedPicks | null;
  pickFailed: string;
  /** The chat model's ID, once it is chosen, and its test with this address and key. */
  model: string;
  check: ModelTest;
  /** The worker model's ID, "" for none: then the chat model does that work. */
  worker: string;
  workerCheck: ModelTest;
  /** Whether the user chose the worker model in its picker ("" included), which the picks then leave as it is. */
  workerChosen: boolean;
  /** The models of the address, asked with the key, for the picker. */
  listing: ReturnType<typeof models>;
  /** Makes open work slow after 8 s and gives it up after 30 s (`giveUp`). */
  clock: ReturnType<typeof workClock>;
}

/** Whose key it is and how it ends: the provider by the name the user gave it, else by its name in the list, else by where its API is. */
function keyText(s: Setup, { base_url, key, name }: Asked): string {
  let host = base_url;
  try {
    host = new URL(base_url).host;
  } catch {
    // As it was typed, then.
  }
  const typed = key.api_key?.trim();
  // A key typed counts; without one the stored key stays, with the address it was stored with.
  const same = s.stored?.base_url === base_url;
  const kept = typed === undefined && s.stored?.has_key && same;
  const end = typed && typed.length >= KEY_END_FROM ? typed.slice(-KEY_END) : kept ? (s.stored?.key_end ?? "") : "";
  // A name that was not asked for anew is the stored one, which stays with its address.
  const own = name ?? (same ? s.stored?.name : null);
  const provider = own || s.first.named(base_url) || host;
  return typed || kept ? keyLine(provider, end) : wording("setup-key-line-none", { provider });
}

/** What the line of the chat model says while none is chosen. */
function unchosen(s: Setup): string {
  if (s.picked && !s.picked.listed && !s.picked.failed) return wording("setup-unlisted");
  if (s.picked?.listed) return wording("setup-none-found");
  return wording("setup-not-chosen");
}

/** The readable names of the picks and the models listed, by ID. */
export const names = (s: Setup): Record<string, string> => ({ ...s.listing.got()?.names, ...s.picked?.names });

/** What the step's work has come to (models-state.ts). */
export const stepState = (s: Setup): StepState => ({
  open: !!s.picking || s.check.asking() || s.workerCheck.asking(),
  slow: s.clock.slow(),
  chat: s.model,
  chatFailed: !!s.check.failed(),
  workerFailed: !!s.worker && !!s.workerCheck.failed(),
  noList: !!s.pickFailed || !!s.picked?.failed,
  keyRefused: s.picked?.failed?.details?.said === "did not take the key",
});

/** Gives up the work still open after 30 s: no spinner turns for ever. */
export function giveUp(s: Setup): void {
  const why = wording("error-timed-out", { whose: "model_server" });
  if (s.picking) [s.picking, s.pickFailed] = [null, wording("setup-no-picks", { why })];
  s.check.giveUp(why);
  s.workerCheck.giveUp(why);
  show(s);
}

/** Shows the step and what is known by now. */
export function show(s: Setup): void {
  s.first.node.hidden = s.step !== 1;
  s.second.hidden = s.step !== 2;
  s.cards.node.hidden = s.step !== 3;
  s.choice.node.hidden = s.step !== 4 || s.downloading;
  s.third.node.hidden = s.step !== 4 || !s.downloading;
  if (!s.step) return;
  // Another account than this computer's has neither the folder of cards nor the downloads.
  s.where.textContent = wording("setup-where", { step: s.step, steps: s.local ? 4 : 2 });
  s.title.textContent = ["", wording("setup-title-1"), wording("setup-title-2"), wording("setup-title-3"), wording("setup-title-4")][s.step];
  const state = stepState(s);
  s.clock.run(state.open);
  // Step 2's line under the title is its lead, with the one spinner while work is open.
  const about = ["", wording("setup-about-1"), lead(state), wording("setup-about-3"), s.downloading ? wording("setup-about-4") : wording("setup-about-4-choose")][s.step];
  s.about.replaceChildren(...(s.step === 2 && state.open ? [spinner()] : []), about);
  s.choice.draw(s.local);
  if (s.step !== 2 || !s.asked) return;
  s.keyLine.textContent = keyText(s, s.asked);
  // What failed stands in red under the line, with "Try again" beside it: the test of the model, or without a model the picks.
  const listFailed = s.picked?.failed ? wording("setup-no-list", { why: failureWords(s.picked.failed) }) : "";
  const failed = s.check.failed() || (!s.model && !s.picking ? s.pickFailed || listFailed : "");
  const known = names(s);
  /** A line's result: the spinner alone while open, else the name with whether it answered. */
  const result = (id: string, check: ModelTest, otherwise: string) =>
    check.asking() ? spinner() : modelName(id, known) + (check.passed() ? tested() : check.failed() ? wording("setup-no-answer") : otherwise);
  const chat = s.picking && !s.model ? spinner() : s.model ? result(s.model, s.check, "") : unchosen(s);
  s.chat.show(chat, failed, chatAction(!!s.model, !!s.picking), s.check.passed());
  const worker = s.picking && !s.worker ? spinner() : s.worker ? result(s.worker, s.workerCheck, wording("setup-worker-does")) : wording("setup-same-as-chat");
  // A helper model that did not answer: the chat model does its work, and the line says so.
  const workerFailed = s.workerCheck.failed() && `${s.workerCheck.failed()} ${wording("setup-helper-falls-back")}`;
  s.workerLine.show(worker, workerFailed, wording("setup-change"), s.workerCheck.passed());
  s.images.draw();
  s.confirm.disabled = greyed(state);
}

/** Asks the model its small question, at the address and with the key of step 1. */
const test = (s: Setup) => s.check.ask({ base_url: s.asked!.base_url, model: s.model, ...s.asked!.key });
/** Asks the worker model its small question, as the chat model is asked. */
const testWorker = (s: Setup) => s.workerCheck.ask({ base_url: s.asked!.base_url, model: s.worker, ...s.asked!.key });

export function choose(s: Setup, id: string): void {
  s.model = id;
  s.clock.restart();
  test(s);
}

/** Has the server pick a model of each kind for whom step 1 said, then tests the chat and the background model. */
function pick(s: Setup): void {
  const asked = s.asked!;
  // The asking whose answer counts: another address or key, or giving up, makes another or none (not `s.asked`,
  // which step 1 gives anew also with the same address and key).
  const mine = {};
  [s.picking, s.picked, s.pickFailed] = [mine, null, ""];
  show(s);
  pickModels({ base_url: asked.base_url, ...asked.key }).then(
    (picks) => {
      if (s.picking !== mine) return;
      [s.picking, s.picked] = [null, picks];
      // A model the user chose meanwhile stays, and is tested already, "Same as the chat model" too; a worker model
      // that is the chat model now is none, as the server stores it.
      const chose = { chat: !!s.model, worker: s.workerChosen };
      s.model ||= picks.chat ?? "";
      if (!chose.worker) s.worker = picks.background ?? "";
      if (s.worker && s.worker === s.model) {
        s.worker = "";
        s.workerCheck.forget();
      }
      if (picks.images && !s.images.held()) s.images.hold(picks.images);
      // Not for a screen that was left meanwhile: the test is a question nobody would see answered.
      if (s.node.isConnected && s.model && !chose.chat) test(s);
      if (s.node.isConnected && s.worker && !chose.worker) testWorker(s);
      show(s);
    },
    (error) => {
      if (s.picking !== mine) return;
      [s.picking, s.pickFailed] = [null, wording("setup-no-picks", { why: told(error) })];
      show(s);
    },
  );
}

/** Goes on to step 2 with whom step 1 said: the picks and the tests are of the address and the key they were asked with. */
export function toModels(s: Setup, next: Asked): void {
  s.step = 2;
  const moved = s.asked?.base_url !== next.base_url;
  const rekeyed = s.asked?.key.api_key !== next.key.api_key;
  s.asked = next;
  if (moved || rekeyed) {
    [s.model, s.worker, s.workerChosen] = ["", "", false];
    s.images.forget();
    s.check.forget();
    s.workerCheck.forget();
    pick(s);
  }
  show(s);
  s.chat.change.focus();
}

/** Step 2's buttons. */
export function wire(s: Setup): void {
  s.backButton.onclick = () => {
    s.step = 1;
    show(s);
    s.first.key.focus();
  };
  // With a provider that was stored, the picker asks for the models when it wants them first.
  s.chat.change.onclick = () => s.listing.pick(s.model);
  s.chat.retry.onclick = () => {
    // The button goes while it is asked again.
    s.chat.change.focus();
    s.clock.restart();
    if (s.check.failed()) test(s);
    else pick(s);
  };
  s.workerLine.change.onclick = () =>
    s.listing.pick(s.worker || s.model, wording("setup-helper-model"), (id) => {
      // The chat model taken is none, as the server stores it: the chat model does that work, whichever it is later.
      s.worker = id === s.model ? "" : id;
      s.workerChosen = true;
      s.workerCheck.forget();
      s.clock.restart();
      if (s.worker) testWorker(s);
      else show(s);
    });
  s.workerLine.retry.onclick = () => {
    s.workerLine.change.focus();
    s.clock.restart();
    testWorker(s);
  };
  s.confirm.onclick = () => void confirm(s);
  s.choice.go.onclick = () => void download(s);
  s.choice.back.onclick = () => {
    s.step = 3;
    show(s);
    s.cards.focus();
  };
  s.cards.backButton.onclick = () => {
    s.step = 2;
    show(s);
    s.confirm.focus();
  };
  s.cards.go.onclick = () => {
    s.cards.take(true);
    toDownloads(s);
  };
  s.cards.skip.onclick = () => {
    s.cards.take(false);
    toDownloads(s);
  };
}

/** The app opens where the user came from, and says that the models are set up. */
export function openApp(s: Setup): void {
  announce(wording("setup-set-up"), undefined, true);
  // The folder step 3 held: stored now, and its cards imported with the import panel, which outlives this screen.
  const folder = s.cards.chosen();
  s.cards.forget();
  if (folder) void useCardFolder(folder).catch((error) => announce(wording("setup-folder-not-kept", { why: told(error) })));
  // In first run's place: the way back from there does not lead through a setup that is done.
  location.replace(s.back);
}

/** Stores the provider with the models and the image model taken, then goes on to the folder of cards, or into the app. */
const confirm = (s: Setup) =>
  s.attempt(async () => {
    const { base_url, key, name } = s.asked!;
    // All at once (the server stores all of it or nothing): the values for a reply left as they are; the worker
    // model as the line says it, "" for none, for one that did not answer or for the chat model itself; the image
    // model at the same provider.
    const image = s.images.held();
    const worker = s.workerCheck.failed() || s.worker === s.model ? "" : s.worker;
    await setProvider({ base_url, model: s.model, worker_model: worker, ...key, ...(name !== undefined && { name }), ...(image && { image_model: image }) });
    if (!s.local) return openApp(s);
    await s.cards.offer();
    s.step = 3;
    show(s);
    s.cards.focus();
  });

/** After the folder of cards: on to step 4, which asks for the downloads, or into the app where none can be made. */
function toDownloads(s: Setup): void {
  if (!s.choice.could(s.local).length) return openApp(s);
  s.step = 4;
  show(s);
  s.choice.go.focus();
}

/** Step 4's button: starts the downloads switched on, or opens the app with both off. */
const download = (s: Setup) =>
  s.attempt(async () => {
    const chosen = s.choice.chosen(s.local).map((one) => one.kind);
    if (!chosen.length) return openApp(s);
    await changeSettings({ setup_downloads: chosen });
    downloadsChosen();
    s.downloading = true;
    show(s);
    s.third.read();
  });

/** Whom setup begins with: the stored provider, else the one added last, as with "Enter the provider's address in Settings" while no chat model is chosen; none begins at step 1. */
export function storedFor(provider: ProviderView | null, list: ProvidersView | undefined): Stored | null {
  if (provider) return provider;
  // One that only makes the pictures (a ComfyUI) lists no chat model: it is passed over.
  const picturesOnly = (id: number) => {
    const kinds = list?.kinds.filter((k) => k.provider_id === id) ?? [];
    return kinds.length > 0 && kinds.every((k) => k.kind === "images");
  };
  const last = list?.providers.filter((p) => !picturesOnly(p.id)).at(-1);
  return last ? { base_url: last.base_url, name: last.own_name, has_key: last.has_key, key_end: last.key_end } : null;
}

/** Reads the stored provider: without one first run begins at step 1, with one at step 2, nothing asked until changed, and at step 4 while its downloads are not through. A provider added but no chat model chosen begins at step 2 with its models picked, as from a key; the key kept at its address goes with them. */
export function begin(s: Setup, local: Promise<boolean>): void {
  // The list is only a way to step 2: unread, setup begins at step 1 as without it.
  const list = getProviderList().catch(() => undefined);
  Promise.all([getProvider(), getSettings(), local, list])
    .then(
      ([provider, settings, here, added]) => {
        const kept = storedFor(provider, added);
        s.stored = kept;
        s.local = here;
        s.step = provider ? (firstRunLeft(settings) && here ? 4 : 2) : kept ? 2 : 1;
        // Downloads not through bring a start back to their bars.
        s.downloading = s.step === 4;
        s.first.fill(kept);
        if (s.step === 4) s.third.read();
        if (kept && !provider) toModels(s, { base_url: kept.base_url, key: {} });
        if (!provider) return;
        s.asked = { base_url: provider.base_url, key: {} };
        s.model = provider.model;
        s.worker = provider.worker_model ?? "";
      },
      (error) => {
        s.step = 1;
        s.notice.replaceChildren(failure(reason(error)));
      },
    )
    .finally(() => show(s));
}
