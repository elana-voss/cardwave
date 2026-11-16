// First run: what the app shows a user who has no model provider yet, in four steps. Step 1 takes the key and says
// whose it is, or has the provider found or its address entered, or a server on this computer used, This
// computer's own models among them (`keyStep`, setup/key-step.ts, setup/this-computer.ts). Step 2 opens with a
// model of each kind picked from the key and tested, and the language the AI writes in (setup/models-step.ts).
// Step 3, this computer's account's, takes a folder of cards, imported when setup ends (setup/cards-step.ts). Step
// 4 asks which of the search model and the voice to download, then downloads them (setup/downloads-step.ts). "Enter the provider's address in Settings" leads to Settings › Providers;
// a provider there and no chat model chosen opens setup at step 2 for it (`begin`), at start and from the chat too.
//
// Step 1 has the field of "Language of the app" alone at the top right, above the key's field (settings/app-language.ts),
// and at its foot "Restore a backup", this computer's account's, which opens the restore screen (`restoreStep`: no
// board yet, so the Restore dialog's parts; restored, every page starts anew with the backup's provider).
// At `#/setup`, a screen without the rail (`route` in main.ts hides it): the logo beside "Cardwave" with which
// step it is at the right (`.setup-top`), the step's name and a line under it (`.setup-head`), then the step.
import { wording } from "../language/language";
import { account } from "../account";
import { el, newest, noticeBox, oneAtATime, type View } from "../dom";
import logo from "../logo.png";
import { modelTest, models } from "../models/provider-form";
import { cardsStep } from "../setup/cards-step";
import { downloadsChoice, downloadsStep } from "../setup/downloads-step";
import { keyStep } from "../setup/key-step";
import { restoreParts } from "../settings/backup";
import { appLanguageLine } from "../settings/app-language";
import { begin, choose, giveUp, modelsParts, names, settingsButton, openApp, show, tested, toModels, wire, type Setup } from "../setup/models-step";
import { workClock } from "../setup/models-state";
import { thisComputerLine } from "../setup/this-computer";

/** `back` is the address the app opens at after first run: the screen the user came from. */
export function setupView(back: string): View {
  const head = { where: el("span", { className: "meta setup-where" }), title: el("h1", { className: "card-title-narrow" }), about: el("p", { className: "m0 c-grey" }) };
  const first = keyStep(
    (next) => toModels(s, next),
    () => show(s),
    (use) => thisComputerLine(() => node, use),
    // "Enter the provider's address in Settings" stands beside Continue (board FirstRunStep1).
    settingsButton(wording("setup-manually")),
  );
  const appLanguage = appLanguageLine();
  // The field alone, at the form's top right: it says what it is by itself (the owner, 2026-11-08).
  first.node.prepend(appLanguage.notice, el("div", { className: "flex jc-e" }, appLanguage.field));
  /** Opens or leaves the restore screen. */
  const restoring = (open: boolean) => {
    s.restoring = open;
    show(s);
    // The button pressed went away with its screen: the focus goes into the one that opened, or back to the link.
    (open ? restore.querySelector<HTMLElement>("button") : restoreLink.querySelector<HTMLElement>("button"))?.focus();
  };
  const restoreLink = el("p", { className: "m0", hidden: true }, el("button", { type: "button", className: "textbtn", onclick: () => restoring(true) }, wording("backup-restore-title")));
  first.node.append(restoreLink);
  const restore = restoreStep(() => restoring(false));
  const parts = modelsParts(() => node, () => s.asked!, { picking: () => !!s.picking, names: () => names(s) });
  const choice = downloadsChoice(() => node, () => show(s));
  const third = downloadsStep(() => openApp(s), () => !!cards.chosen());
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const cards = cardsStep(() => node, attempt);
  const node = el(
    "section",
    { className: "fr-main setup" },
    el(
      "div",
      { className: "fr-col" },
      el("div", { className: "flex ai-c jc-sb g-12" }, el("div", { className: "fr-brand setup-brand" }, el("img", { className: "logo-lg", src: logo, alt: "" }), wording("app-name")), head.where),
      el("div", { className: "flex f-col g-6 setup-head" }, head.title, head.about),
      first.node,
      restore,
      parts.second,
      cards.node,
      choice.node,
      third.node,
      notice,
    ),
  );
  const s: Setup = {
    ...parts,
    ...head,
    back,
    node,
    first,
    restoreLink,
    restore,
    restoring: false,
    cards,
    choice,
    third,
    downloading: false,
    notice,
    attempt,
    stored: null,
    local: false,
    step: 0,
    asked: null,
    picking: false,
    picks: newest(),
    picked: null,
    pickFailed: "",
    model: "",
    check: modelTest(() => show(s), tested()),
    worker: "",
    workerChosen: false,
    workerCheck: modelTest(() => show(s), tested()),
    listing: models(node, () => ({ base_url: s.asked!.base_url, ...s.asked!.key }), () => show(s), (id) => choose(s, id)),
    clock: workClock(
      () => show(s),
      () => giveUp(s),
    ),
  };
  wire(s);
  begin(
    s,
    account().then(
      (who) => who.local,
      () => false,
    ),
  );
  return {
    node: node,
    onEvent: (event) => {
      if (event.type === "search") choice.search.read();
      if (event.type === "voice") choice.voice.read();
      if ((event.type === "search" || event.type === "voice") && s.step === 4) third.read();
    },
    onConnected: () => {
      choice.search.read();
      choice.voice.read();
      if (s.step === 4) third.read();
    },
  };
}

/** The restore screen's form, hidden; `back` returns to step 1. */
function restoreStep(back: () => void): HTMLFormElement {
  const parts = restoreParts();
  const failed = noticeBox();
  const run = oneAtATime(failed);
  const node = el(
    "form",
    { className: "flex f-col g-14 restore-step", hidden: true },
    ...parts.fields,
    failed,
    el(
      "div",
      { className: "setup-actions flex ai-c g-10 wrap" },
      el("button", { type: "submit", className: "btn btn-primary btn-lg" }, wording("backup-restore")),
      el("button", { type: "button", className: "btn btn-secondary", onclick: back }, wording("setup-back")),
    ),
  );
  node.onsubmit = (event) => {
    event.preventDefault();
    void run(parts.restore);
  };
  return node;
}
