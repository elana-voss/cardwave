// First run: what the app shows a user who has no model provider yet, in four steps. Step 1 takes the key and says
// whose it is, or has the provider found or its address entered, or a server on this computer used, This
// computer's own models among them (`keyStep`, setup/key-step.ts, setup/this-computer.ts). Step 2 opens with a
// model of each kind picked from the key and tested, and the language the AI writes in (setup/models-step.ts).
// Step 3, this computer's account's, takes a folder of cards, imported when setup ends (setup/cards-step.ts). Step
// 4 asks which of the search model and the voice to download, then downloads them (setup/downloads-step.ts). "Enter the provider's address in Settings" leads to Settings › Providers.
//
// Step 1 has the field of "Language of the app" alone at the top right, above the key's field (settings/app-language.ts).
// At `#/setup`, a screen without the rail (`route` in main.ts hides it): the logo beside "Cardwave" with which
// step it is at the right (`.setup-top`), the step's name and a line under it (`.setup-head`), then the step.
import { wording } from "../language/language";
import { account } from "../account";
import { el, noticeBox, oneAtATime, type View } from "../dom";
import logo from "../logo.png";
import { modelTest, models } from "../models/provider-form";
import { cardsStep } from "../setup/cards-step";
import { downloadsChoice, downloadsStep } from "../setup/downloads-step";
import { keyStep } from "../setup/key-step";
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
    picking: null,
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
