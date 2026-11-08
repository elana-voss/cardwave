// First run's second step, "Models" (board "First run · step 2"), and which step shows. A `.group` of lines: the
// key's (`keyText`, no button: "Back" returns to step 1), the chat model's (`chat`, its picker `listing`, its test
// `check`), the background model's (`workerLine`, `workerCheck`), the image model's (images-setup.ts, held until
// "Confirm"), the voice's (voice-setup.ts) and the search model's (search-setup.ts), these two with the size of
// their download and, on this computer's account while not there, a switch of whether first run downloads it
// (`want`: the search model on at first, as it is recommended, the voice off); under the box what "Confirm"
// downloads in all (`totalText`), and the lines "Language the AI writes in" (language-line.ts) and, in the desktop
// app, "Companion figure" (companion-app.ts), both stored at once as in Settings.
//
// With an address or key new to it, the step opens with the server's picks (`pick`, crates/cw-provider/src/picks.rs):
// a model of each kind, chat and background then tested with the small question, images not. "Change" opens the
// picker of that kind. "Confirm" stores the provider and the image model at once; this computer's account goes on
// to step 3, the folder of cards (cards-step.ts), another back to where the user came from. After step 3
// (`toDownloads`), where a download chosen is still to make, first run's downloads are stored as not through
// (`setup_downloads`, which of them) and step 4 shows them (downloads-step.ts). Setup's end (`openApp`) stores the
// folder of cards step 3 held and imports its cards. The screen (views/setup.ts) makes the state (`Setup`) and
// starts it (`begin`).
import { wording } from "../language/language";
import { failureWords } from "../language/errors";
import { changeSettings, getProvider, getSettings, pickModels, setProvider } from "../api/client";
import type { Picks } from "../api/generated/Picks";
import type { ProviderView } from "../api/generated/ProviderView";
import type { SearchModel } from "../api/generated/SearchModel";
import type { SetupDownload } from "../api/generated/SetupDownload";
import type { VoiceModel } from "../api/generated/VoiceModel";
import { announce, el, failure, item, reason, switchBox, told } from "../dom";
import { useCardFolder } from "../library/card-folder";
import { figureLine } from "../library/companion-app";
import { bytes } from "../format";
import { imagesLine } from "../models/images-setup";
import { languageLine } from "../models/language-line";
import { modelLine, type models, type ModelTest } from "../models/provider-form";
import { searchLine } from "../models/search-setup";
import { LABELS } from "../setting-labels";
import { voiceLine } from "../voice/voice-setup";
import type { cardsStep } from "./cards-step";
import { downloadsChosen, firstRunLeft, type downloadsStep } from "./downloads-step";
import type { Asked, KeyStep } from "./key-step";

/** How much of a key the line for it shows, of a key at least so long: as the server tells of a stored one (`Provider::key_end` in `crates/cw-provider/src/lib.rs`, which has the same two numbers). */
const KEY_END = 4;
const KEY_END_FROM = 16;

/** What stands behind a model's name once its test passed, with the blue tick. */
export const tested = () => wording("setup-tested");
/** What the lines say while the server picks. */
const picking = () => wording("setup-picking");

/** A quiet button to Settings › Providers: step 1 says it to enter the address there, step 2 to configure the models there. */
export const settingsButton = (words: string) => el("button", { type: "button", className: "btn btn-quiet", onclick: () => (location.hash = "#/settings/providers") }, words);

/** Step 2's elements; `home` is the screen, `whom` the address and key of step 1, and `changed` told of the downloads' states. */
export function modelsParts(home: () => HTMLElement, whom: () => Asked, changed: () => void) {
  const keyLine = el("span", { className: "meta" });
  const chat = modelLine();
  const workerLine = modelLine(LABELS.advanced.background, wording("setup-the-helper-model"));
  const images = imagesLine(home, () => ({ base_url: whom().base_url, ...whom().key }));
  const voice = voiceLine(home, { changed });
  const search = searchLine(home, { changed });
  // Whether first run downloads each: the search model is recommended, the voice an option.
  const want = { voice: switchBox({ ariaLabel: wording("setup-want-voice"), onchange: changed }), search: switchBox({ ariaLabel: wording("setup-want-search"), checked: true, onchange: changed }) };
  // The switch says what it does and stands before "Change", so every line's Change is in one column.
  const switches = { voice: el("label", { className: "meta flex ai-c g-8" }, wording("voices-download"), want.voice), search: el("label", { className: "meta flex ai-c g-8" }, wording("voices-download"), want.search) };
  for (const [line, toggle] of [[voice, switches.voice], [search, switches.search]] as const) line.node.insertBefore(toggle, line.node.querySelector(".btn"));
  const total = el("p", { className: "hint setup-total" });
  const language = languageLine();
  const figure = figureLine();
  const confirm = el("button", { type: "button", className: "btn btn-primary btn-lg" }, wording("setup-confirm"));
  const backButton = el("button", { type: "button", className: "btn btn-quiet" }, wording("setup-back"));
  const second = el(
    "div",
    { className: "setup-step flex f-col g-28", hidden: true },
    el("div", { className: "group" }, item(wording("setup-title-1"), keyLine, el("span")), chat.node, workerLine.node, images.node, voice.node, search.node),
    language.notice,
    figure?.notice ?? null,
    el("div", { className: "group" }, language.node, figure?.node ?? null),
    total,
    el("div", { className: "setup-actions flex ai-c g-10 wrap" }, confirm, backButton, settingsButton(wording("setup-manually-models"))),
  );
  return { second, keyLine, chat, workerLine, images, voice, search, want, total, confirm, backButton };
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
  third: ReturnType<typeof downloadsStep>;
  notice: HTMLElement;
  attempt: (action: () => Promise<void>) => Promise<boolean>;
  /** The stored provider, when the setup is gone through again. */
  stored: ProviderView | null;
  /** Whether this computer's account it is, which alone downloads the voice and the search model. */
  local: boolean;
  /** The step shown; 0 until it is known whether a provider is stored. 3 is the folder of cards, 4 the downloads. */
  step: 0 | 1 | 2 | 3 | 4;
  /** Whom step 2 asks: the address and the key as step 1 gave them. Another address or key is another one of these. */
  asked: Asked | null;
  /** Whether the server is picking the models, what its picks came to, and why they did not come. */
  picking: boolean;
  picked: Picks | null;
  pickFailed: string;
  /** The chat model's ID, once it is chosen, and its test with this address and key. */
  model: string;
  check: ModelTest;
  /** The worker model's ID, "" for none: then the chat model does that work. */
  worker: string;
  workerCheck: ModelTest;
  /** The models of the address, asked with the key, for the picker. */
  listing: ReturnType<typeof models>;
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
  return typed || kept ? wording("setup-key-line", { provider, end }) : wording("setup-key-line-none", { provider });
}

/** What the line of the chat model says while none is chosen. */
function unchosen(s: Setup): string {
  if (s.picking) return picking();
  if (s.picked && !s.picked.listed && !s.picked.failed) return wording("setup-unlisted");
  return wording("setup-not-chosen");
}

/** What first run can download: the voice and the search model where they are not there, also one that is
 * downloading or failed, so that step 4 sees it through; on this computer's account alone. */
function toMake(local: boolean, voice: VoiceModel | null, search: SearchModel | null): { kind: SetupDownload; name: string; size: number }[] {
  if (!local) return [];
  return [
    ...(voice && voice.state !== "ready" ? [{ kind: "voice" as const, name: wording("setup-the-voice"), size: voice.size }] : []),
    ...(search && search.state !== "ready" ? [{ kind: "search" as const, name: wording("setup-the-search-model"), size: search.size }] : []),
  ];
}
/** The downloads first run makes: of those it can, the ones `want` chose. */
export const toDownload = (local: boolean, voice: VoiceModel | null, search: SearchModel | null, want: Record<SetupDownload, boolean>) =>
  toMake(local, voice, search).filter((one) => want[one.kind]);

/** The line under the box: what the main button downloads; where something `could` be, that nothing is now. */
export function totalText(made: { name: string; size: number }[], could: boolean): string {
  if (!made.length) return could ? wording("setup-nothing-now") : "";
  const what = made.map((one) => one.name).reduce((first, second) => wording("setup-and", { first, second }));
  return wording("setup-downloaded", { what });
}

/** The main button's words: "Download" with the size in all where something is downloaded, else "Confirm". */
export const confirmText = (made: { size: number }[]) => (made.length ? wording("setup-download-size", { size: bytes(made.reduce((sum, one) => sum + one.size, 0)) }) : wording("setup-confirm"));

/** Shows the step and what is known by now. */
export function show(s: Setup): void {
  s.first.node.hidden = s.step !== 1;
  s.second.hidden = s.step !== 2;
  s.cards.node.hidden = s.step !== 3;
  s.third.node.hidden = s.step !== 4;
  if (!s.step) return;
  // Another account than this computer's has neither the folder of cards nor the downloads.
  s.where.textContent = wording("setup-where", { step: s.step, steps: s.local ? 4 : 2 });
  s.title.textContent = ["", wording("setup-title-1"), wording("setup-title-2"), wording("setup-title-3"), wording("setup-title-4")][s.step];
  s.about.textContent = ["", wording("setup-about-1"), wording("setup-about-2"), wording("setup-about-3"), wording("setup-about-4")][s.step];
  const could = toMake(s.local, s.voice.model(), s.search.model());
  const made = could.filter((one) => s.want[one.kind].checked);
  s.total.textContent = totalText(made, could.length > 0);
  s.confirm.textContent = confirmText(made);
  // A switch shows while its download can be made.
  for (const kind of ["voice", "search"] as const) s.want[kind].parentElement!.hidden = !could.some((one) => one.kind === kind);
  if (s.step !== 2 || !s.asked) return;
  s.keyLine.textContent = keyText(s, s.asked);
  // What failed stands in red under the line, with "Retry" in it: the test of the model, or without a model the picks.
  const listFailed = s.picked?.failed ? wording("setup-no-list", { why: failureWords(s.picked.failed) }) : "";
  const failed = s.check.failed() || (!s.model && !s.picking ? s.pickFailed || listFailed : "");
  s.chat.show(s.model ? s.model + s.check.said() : unchosen(s), failed, s.model ? wording("setup-change") : wording("setup-choose"), s.check.said() === tested());
  const worker = s.picking ? picking() : s.worker ? s.worker + (s.workerCheck.said() || wording("setup-worker-does")) : wording("setup-same-as-chat");
  s.workerLine.show(worker, s.workerCheck.failed(), wording("setup-change"), s.workerCheck.said() === tested());
  s.confirm.disabled = !s.model || s.picking;
}

/** Asks the model its small question, at the address and with the key of step 1. */
const test = (s: Setup) => s.check.ask({ base_url: s.asked!.base_url, model: s.model, ...s.asked!.key });
/** Asks the worker model its small question, as the chat model is asked. */
const testWorker = (s: Setup) => s.workerCheck.ask({ base_url: s.asked!.base_url, model: s.worker, ...s.asked!.key });

export function choose(s: Setup, id: string): void {
  s.model = id;
  test(s);
}

/** Has the server pick a model of each kind for whom step 1 said, then tests the chat and the background model. */
function pick(s: Setup): void {
  const asked = s.asked!;
  [s.picking, s.picked, s.pickFailed] = [true, null, ""];
  show(s);
  pickModels({ base_url: asked.base_url, ...asked.key }).then(
    (picks) => {
      if (s.asked !== asked) return;
      [s.picking, s.picked] = [false, picks];
      s.model = picks.chat ?? "";
      s.worker = picks.background ?? "";
      if (picks.images) s.images.hold(picks.images);
      // Not for a screen that was left meanwhile: the test is a question nobody would see answered.
      if (s.node.isConnected && s.model) test(s);
      if (s.node.isConnected && s.worker) testWorker(s);
      show(s);
    },
    (error) => {
      if (s.asked !== asked) return;
      [s.picking, s.pickFailed] = [false, wording("setup-no-picks", { why: told(error) })];
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
    [s.model, s.worker] = ["", ""];
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
    if (s.check.failed()) test(s);
    else pick(s);
  };
  s.workerLine.change.onclick = () =>
    s.listing.pick(s.worker || s.model, wording("setup-helper-model"), (id) => {
      // The chat model taken is none, as the server stores it: the chat model does that work, whichever it is later.
      s.worker = id === s.model ? "" : id;
      s.workerCheck.forget();
      if (s.worker) testWorker(s);
      else show(s);
    });
  s.workerLine.retry.onclick = () => {
    s.workerLine.change.focus();
    testWorker(s);
  };
  s.confirm.onclick = () => void confirm(s);
  s.cards.backButton.onclick = () => {
    s.step = 2;
    show(s);
    s.confirm.focus();
  };
  s.cards.go.onclick = () => {
    s.cards.take(true);
    void toDownloads(s);
  };
  s.cards.skip.onclick = () => {
    s.cards.take(false);
    void toDownloads(s);
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
    // model as the line says it, "" for none; the image model at the same provider.
    const image = s.images.held();
    await setProvider({ base_url, model: s.model, worker_model: s.worker, ...key, ...(name !== undefined && { name }), ...(image && { image_model: image }) });
    if (!s.local) return openApp(s);
    await s.cards.offer();
    s.step = 3;
    show(s);
    s.cards.focus();
  });

/** After the folder of cards: on to the downloads, or into the app where there are none. */
const toDownloads = (s: Setup) =>
  s.attempt(async () => {
    const want = { voice: s.want.voice.checked, search: s.want.search.checked };
    const chosen = toDownload(s.local, s.voice.model(), s.search.model(), want).map((one) => one.kind);
    if (!chosen.length) return openApp(s);
    await changeSettings({ setup_downloads: chosen });
    downloadsChosen();
    s.step = 4;
    show(s);
    s.third.read();
  });

/** Reads the stored provider: without one first run begins at step 1, with one at step 2, nothing asked until changed, and at step 4 while its downloads are not through. */
export function begin(s: Setup, local: Promise<boolean>): void {
  Promise.all([getProvider(), getSettings(), local])
    .then(
      ([provider, settings, here]) => {
        s.stored = provider;
        s.local = here;
        s.step = provider ? (firstRunLeft(settings) && here ? 4 : 2) : 1;
        s.first.fill(provider);
        if (s.step === 4) s.third.read();
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
