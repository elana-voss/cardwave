// First run: what the app shows a user who has no model provider yet, in four steps. Step 1 takes the key and says
// whose it is, or has the provider found or its address entered, or a server on this computer used, This
// computer's own models among them (`keyStep`, setup/key-step.ts, setup/this-computer.ts). Step 2 opens with a
// model of each kind picked from the key and tested, the voice and the search model with their downloads, and
// the language the AI writes in (setup/models-step.ts). Step 3, this computer's account's, takes a folder of cards,
// imported when setup ends (setup/cards-step.ts). Step 4 downloads the voice and the search model
// (setup/downloads-step.ts). "Enter the provider's address in Settings" leads to Settings › Providers.
//
// Step 1 has "Language of the app" above the key's field (settings/app-language.ts), as Settings has it.
// At `#/setup`, a screen without the rail (`route` in main.ts hides it): the logo beside "Cardwave" with which
// step it is at the right (`.setup-top`), the step's name and a line under it (`.setup-head`), then the step.
import { wording } from "../language/language";
import { account } from "../account";
import { el, noticeBox, oneAtATime, type View } from "../dom";
import logo from "../logo.png";
import { modelTest, models } from "../models/provider-form";
import { cardsStep } from "../setup/cards-step";
import { downloadsStep } from "../setup/downloads-step";
import { keyStep } from "../setup/key-step";
import { appLanguageLine } from "../settings/app-language";
import { begin, choose, modelsParts, settingsButton, openApp, show, tested, toModels, wire, type Setup } from "../setup/models-step";
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
  first.node.prepend(appLanguage.notice, el("div", { className: "group" }, appLanguage.node));
  const parts = modelsParts(() => node, () => s.asked!, () => show(s));
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
    third,
    notice,
    attempt,
    stored: null,
    local: false,
    step: 0,
    asked: null,
    picking: false,
    picked: null,
    pickFailed: "",
    model: "",
    check: modelTest(() => show(s), tested()),
    worker: "",
    workerCheck: modelTest(() => show(s), tested()),
    listing: models(node, () => ({ base_url: s.asked!.base_url, ...s.asked!.key }), () => show(s), (id) => choose(s, id)),
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
      if (event.type === "search") parts.search.read();
      if (event.type === "voice") parts.voice.read();
      if ((event.type === "search" || event.type === "voice") && s.step === 4) third.read();
    },
    onConnected: () => {
      parts.search.read();
      parts.voice.read();
      if (s.step === 4) third.read();
    },
  };
}
