// First run's first step: the user pastes the key, and the app says whose it is by how it begins. A key that
// is no provider's on the list has the provider found by its name or website, or its address entered; and
// without a key a server on this computer is used.
//
// `recognise` is the rule: the providers of the list whose keys begin as the key does (`KnownProvider::keys`),
// those with the longest such beginning, so that "sk-or-v1-…" is OpenRouter's though "sk-" is OpenAI's too.
// `keyStep` is the step, a form `.key-step` that shows one of its states at a time (`show`): nothing under the
// key while there is none and nothing was set by hand; the provider recognised (`.recognised`, with "Not this
// one?", after which a key that is still that provider's stays set by hand, `aside`); a choice between the few
// whose keys begin alike (`.several`, pills); or the switch between "Find by name" and "Enter address"
// (`.by-hand`). "Find by name" looks the name up in the list and asks the server for a website's API, without the
// key (`look`), each address found a line with "Use this" (`.found-list`). "No key?" asks the servers on this
// computer that the list knows for their models and offers those that answer (`servers`), with "Enter address"
// under them; in first run This computer's line first (`own`, setup/this-computer.ts). The step hands on whom
// the next one asks (`Asked`) through `go`, and sends the key nowhere itself.
// Gone through again, it begins with what is stored (`fill`). First run's way elsewhere (`elsewhere`) stands beside Continue, but not
// while the provider is set by hand, whose switch has "Enter address".
import { wording } from "../language/language";
import { findProvider, getProviders, listModels } from "../api/client";
import type { KnownProvider } from "../api/generated/KnownProvider";
import type { ProviderView } from "../api/generated/ProviderView";
import { atMost, el, failure, item, latest, pill, reason, segmented } from "../dom";
import { icon } from "../icons";
import { field, keyStored, listed as onList, plain } from "../models/provider-form";
import { comma } from "../format";

/** How many providers "Find by name" offers at most for a part of a name. */
const FOUND_MOST = 5;

/** The most characters a provider's own name may have, as the server has it (`NAME_LIMIT` in `crates/cw-provider/src/lib.rs`). */
const NAME_LIMIT = 60;

/** Whom the second step asks: the address, the key as the form gives it (left out, the stored one stays), and the user's own name for the provider, where one was asked for. */
export interface Asked {
  base_url: string;
  key: { api_key?: string };
  name?: string;
}

/**
 * The providers of `list` whose key `key` may be: those whose keys begin as it does, and of them the ones with
 * the longest such beginning. None for a key that begins as no provider's does; several where providers share
 * a beginning.
 */
export function recognise(key: string, list: KnownProvider[]): KnownProvider[] {
  let longest = 0;
  let fits: KnownProvider[] = [];
  for (const provider of list) {
    for (const start of provider.keys) {
      // A key is more than its beginning.
      if (key.length <= start.length || !key.startsWith(start) || start.length < longest) continue;
      if (start.length > longest) fits = [];
      longest = start.length;
      if (!fits.includes(provider)) fits.push(provider);
    }
  }
  return fits;
}

type Mode = "find" | "address";

export interface KeyStep {
  node: HTMLFormElement;
  /** The key's field, which has the focus when the step is come back to. */
  key: HTMLInputElement;
  /** The name the list has for the provider at `address`, if it is one of the list's. */
  named(address: string): string | undefined;
  /** Begins the step anew, with the provider that is stored, if one is. The key never comes back, only its end. */
  fill(stored: ProviderView | null): void;
}

/** The step's parts. */
type Parts = ReturnType<typeof parts>;

/** The step's state, and its parts. */
interface Step extends Parts {
  go: (asked: Asked) => void;
  /** The list of providers, once it has come. */
  providers: KnownProvider[];
  /** Whether the list has come, or will not: until then nothing is said of a key. */
  ready: boolean;
  /** The user sets the provider by hand, though the key was recognised or there is none: until another key is typed. */
  manual: boolean;
  /** The providers the user said the key is not of ("Not this one?", "None of these?"). */
  aside: KnownProvider[];
  mode: Mode;
  /** Of several providers whose keys begin alike, the one chosen. */
  chosen: KnownProvider | null;
  /** Whether the servers on this computer are shown, and the asking for them whose answer counts. */
  asking: object | null;
  /** The website the server was last asked about, and the asking. */
  website: string;
  search: () => Promise<void>;
  /** The way elsewhere beside Continue, where there is one: not there while the provider is set by hand, whose switch has "Enter address". */
  elsewhere?: HTMLElement;
  /** The line of This computer's models among the servers on this computer, where there is one. */
  own?: () => Promise<HTMLElement | null>;
}

/** The step's elements: the key, what is said of it, the way by hand, "No key?" with what it found, and Continue. */
function parts() {
  const key = el("input", { name: "api_key", className: "field", type: "password", autocomplete: "off", placeholder: wording("setup-key-placeholder") });
  const listFailed = el("div", { role: "status" });
  // The key is one provider's.
  const whose = el("b");
  const notThis = el("button", { type: "button", className: "textbtn" }, wording("setup-not-this"));
  const recognised = el("div", { className: "banner bg-fill recognised", role: "status" }, el("span", { className: "ic-inline" }, icon("check", 16)), el("span", { className: "f-grow" }, wording("setup-recognised"), whose), notThis);
  // It may be one of a few.
  const choice = el("div", { className: "pills", role: "group", ariaLabel: wording("setup-provider") });
  const noneOf = el("button", { type: "button", className: "textbtn" }, wording("setup-none-of-these"));
  const several = el("div", { className: "several flex f-col g-10" }, el("p", null, wording("setup-several")), choice, noneOf);
  // By hand: found by its name or website, or its address entered.
  const unknown = el("p", { className: "hint c-ink m0 unknown" }, wording("setup-unknown"));
  const how = el("div");
  const query = el("input", { name: "find", className: "field f-grow", autocomplete: "off", spellcheck: false, placeholder: wording("setup-find-example") });
  const find = el("button", { type: "button", className: "btn btn-secondary" }, wording("setup-find"));
  const found = el("div", { className: "found-list flex f-col g-10", role: "status" });
  const finding = el("div", { className: "by-hand-part flex f-col g-14" }, field(wording("setup-find-field"), query, wording("setup-find-hint"), find), found);
  const name = el("input", { name: "name", className: "field", autocomplete: "off" });
  atMost(name, NAME_LIMIT);
  const address = el("input", { name: "base_url", className: "field", type: "url", placeholder: "https://example.com/v1" });
  const entering = el(
    "div",
    { className: "by-hand-part flex f-col g-14" },
    field(wording("setup-address"), address, wording("setup-address-hint")),
    field(wording("setup-name"), name, wording("setup-name-hint")),
  );
  const byHand = el("div", { className: "by-hand flex f-col g-14" }, unknown, how, finding, entering);
  const next = el("button", { type: "submit", className: "btn btn-primary btn-lg" }, wording("setup-continue"));
  // Without a key: a program on this computer (the only place naming the example, LM Studio or Ollama).
  const local = el("button", { type: "button", className: "textbtn" }, wording("setup-local"));
  const noKey = el("p", { className: "hint m0 no-key" }, wording("setup-no-key"), local);
  // What a server on this computer answers comes right under its line, before Continue.
  const servers = el("div", { className: "found-list servers flex f-col g-10", role: "status", hidden: true });
  const node = el(
    "form",
    { className: "flex f-col g-14 key-step", hidden: true },
    field(wording("setup-api-key"), key, listFailed),
    recognised,
    several,
    byHand,
    noKey,
    servers,
    el("div", { className: "setup-actions flex ai-c g-10 wrap" }, next),
  );
  return { node, key, listFailed, whose, notThis, recognised, choice, noneOf, several, unknown, how, query, find, found, finding, name, address, entering, byHand, next, local, noKey, servers };
}

/**
 * Makes first run's first step. `go` is given whom the next step asks, once the user has said, and `listed` is
 * told when the list of providers has come, by which an address has a name. `own` makes This computer's line,
 * which goes on with the address it is given.
 */
export function keyStep(go: (asked: Asked) => void, listed: () => void = () => {}, own?: (use: (base_url: string) => void) => Promise<HTMLElement | null>, elsewhere?: HTMLElement): KeyStep {
  const made = parts();
  if (elsewhere) made.next.after(elsewhere);
  const k: Step = {
    ...made,
    go,
    own: own && (() => own((base_url) => go({ base_url, key: { api_key: "" } })).catch(() => null)),
    elsewhere,
    providers: [],
    ready: false,
    manual: false,
    aside: [],
    mode: "find",
    chosen: null,
    asking: null,
    website: "",
    search: latest(
      made.found,
      () => findProvider({ website: k.website }),
      (answer) => {
        if (answer) k.found.replaceChildren(el("div", { className: "group" }, line(k, answer.name ?? wording("setup-found"), answer.base_url, () => typedKey(k))));
        else k.found.replaceChildren(...nothing(k, wording("setup-no-api", { website: k.website })));
      },
    ),
  };
  wire(k);
  setMode(k, "find");
  show(k);
  getProviders()
    .then(
      (list) => (k.providers = list),
      // Without the list no key is recognised: the provider is found by its website, or its address entered.
      (error) => void k.listFailed.replaceChildren(failure(reason(error))),
    )
    .finally(() => {
      k.ready = true;
      show(k);
      listed();
    });
  return { node: k.node, key: k.key, named: (at) => onList(k.providers, at)?.name, fill: (stored) => fill(k, stored) };
}

/** Begins the step anew with what is stored: its address and the name the user gave it, set by hand until another key is typed. */
function fill(k: Step, stored: ProviderView | null): void {
  k.key.value = "";
  k.key.placeholder = keyStored(stored) || wording("setup-key-placeholder");
  k.chosen = null;
  k.asking = null;
  k.aside = [];
  k.found.replaceChildren();
  k.query.value = "";
  k.manual = !!stored;
  k.name.value = stored?.name ?? "";
  k.address.value = stored?.base_url ?? "";
  setMode(k, stored ? "address" : "find");
  show(k);
}

const typed = (k: Step) => k.key.value.trim();
/** The key as it goes on: one typed counts, and without one the stored key stays, at the address it was stored with. */
const typedKey = (k: Step) => (typed(k) ? { api_key: typed(k) } : {});

/** The step's buttons and fields. */
function wire(k: Step): void {
  k.find.onclick = () => void look(k);
  // Enter in the field looks, and does not go on.
  k.query.onkeydown = (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    void look(k);
  };
  k.local.onclick = () => void askServers(k);
  k.notThis.onclick = k.noneOf.onclick = () => {
    k.aside = state(k).fits;
    k.manual = true;
    show(k);
    (k.mode === "find" ? k.query : k.address).focus();
  };
  k.key.oninput = () => {
    // Another key is judged anew, but not one that is of the providers the user set aside, as the same key is
    // when it is mended: that it is another's stays said. A key taken out of the field leaves what is set by
    // hand as it is: the address may be one that needs no key.
    const { fits } = state(k);
    const still = fits.length === k.aside.length && fits.every((one) => k.aside.includes(one));
    k.manual = !k.byHand.hidden && (typed(k) === "" || still);
    show(k);
  };
  k.node.onsubmit = (event) => {
    event.preventDefault();
    const { fits, hand } = state(k);
    if (hand) {
      if (k.mode === "find") return void look(k);
      return k.go({ base_url: plain(k.address.value), key: typedKey(k), name: k.name.value.trim() });
    }
    const provider = fits.length > 1 ? k.chosen : fits[0];
    if (provider) k.go({ base_url: provider.base_url, key: typedKey(k) });
  };
}

/** Sets how the provider is set by hand, and shows the switch as it stands then. */
function setMode(k: Step, now: Mode): void {
  k.mode = now;
  const choices: [Mode, string][] = [
    ["find", wording("setup-find-by-name")],
    ["address", wording("setup-enter-address")],
  ];
  k.how.replaceChildren(
    segmented<Mode>(wording("setup-how"), choices, k.mode, (picked) => {
      k.mode = picked;
      show(k);
      (k.mode === "find" ? k.query : k.address).focus();
    }),
  );
}

/** Leads to "Enter address", from where nothing was found. */
function enter(k: Step): void {
  k.manual = true;
  // The servers on this computer were not it: their list goes.
  k.asking = null;
  setMode(k, "address");
  show(k);
  k.address.focus();
}

/** Whose the key in the field may be (`fits`), and whether the provider is set by hand (`hand`): nothing is said before the list has come. */
function state(k: Step): { fits: KnownProvider[]; hand: boolean } {
  const fits = k.ready ? recognise(typed(k), k.providers) : [];
  return { fits, hand: k.ready && (k.manual || (typed(k) !== "" && !fits.length)) };
}

/** Shows the state the step is in, by the key that stands in its field. */
function show(k: Step): void {
  const { fits, hand } = state(k);
  if (k.chosen && !fits.includes(k.chosen)) k.chosen = null;
  k.recognised.hidden = hand || fits.length !== 1;
  k.several.hidden = hand || fits.length < 2;
  k.byHand.hidden = !hand;
  // Said of a key alone: one the user set aside with "Not this one?" was recognised.
  k.unknown.hidden = !typed(k) || fits.length > 0;
  k.finding.hidden = k.mode !== "find";
  k.entering.hidden = k.mode !== "address";
  // A field that does not show is not asked for.
  k.address.required = hand && k.mode === "address";
  k.whose.textContent = fits[0]?.name ?? "";
  k.choice.replaceChildren(
    ...fits.map((provider) =>
      pill(provider.name, provider === k.chosen, () => {
        k.chosen = provider;
        show(k);
        k.next.focus();
      }),
    ),
  );
  // "Find by name" goes on by "Use this", Continue greyed meanwhile; elsewhere Continue does, once it is known where to.
  k.next.disabled = hand ? k.mode === "find" : fits.length > 1 ? !k.chosen : fits.length < 1;
  if (k.elsewhere) k.elsewhere.hidden = hand;
  // Without a key the way to a server on this computer is there, whatever else is.
  k.noKey.hidden = !k.ready || (hand && typed(k) !== "");
  k.servers.hidden = k.noKey.hidden || !k.asking;
}

/** A line of what was found: what it is, its address, and the button that goes on with it. */
function line(k: Step, called: string, base_url: string, key: () => { api_key?: string }): HTMLElement {
  const use = el("button", { type: "button", className: "btn btn-secondary on-box", onclick: () => k.go({ base_url, key: key() }) }, wording("setup-use-this"));
  return item(called, base_url, use);
}
/** The way to "Enter address", from where the provider was not found. */
const entry = (k: Step) => el("button", { type: "button", className: "btn btn-secondary as-s", onclick: () => enter(k) }, wording("setup-enter-address"));
/** Says that nothing was found, with the way to "Enter address". */
const nothing = (k: Step, said: string) => [el("p", { className: "meta m0" }, said), entry(k)];

/** Looks for the provider that was typed: by its name in the list, else as a website, which the server asks without the key. */
async function look(k: Step): Promise<void> {
  const wanted = k.query.value.trim();
  if (!wanted || k.find.disabled) return;
  const lower = wanted.toLowerCase();
  const called = k.providers.filter((provider) => provider.name.toLowerCase() === lower);
  const known = called.length ? called : k.providers.filter((provider) => provider.name.toLowerCase().includes(lower)).slice(0, FOUND_MOST);
  if (known.length) return void k.found.replaceChildren(el("div", { className: "group" }, ...known.map((provider) => line(k, provider.name, provider.base_url, () => typedKey(k)))));
  if (!wanted.includes(".")) return void k.found.replaceChildren(...nothing(k, wording("setup-not-listed", { name: wanted })));
  k.website = wanted;
  k.find.disabled = true;
  k.found.replaceChildren(el("p", { className: "meta m0" }, wording("setup-looking")));
  await k.search();
  k.find.disabled = false;
}

/** The servers on this computer that the list knows are asked for their models, without a key: one that answers is there. */
async function askServers(k: Step): Promise<void> {
  const mine = (k.asking = {});
  k.servers.replaceChildren(el("p", { className: "meta m0" }, wording("setup-looking-servers")));
  show(k);
  const here = k.providers.filter((provider) => provider.local);
  const [answers, own] = await Promise.all([
    Promise.all(
      here.map((provider) =>
        listModels({ base_url: provider.base_url, api_key: "" }).then(
          () => true,
          () => false,
        ),
      ),
    ),
    k.own?.() ?? null,
  ]);
  if (mine !== k.asking) return;
  const there = here.filter((_, at) => answers[at]);
  // A server on this computer is used without a key: the one in the field is another provider's, if there is one.
  // Another server, which is not on the list, has its address entered.
  const lines = [...(own ? [own] : []), ...there.map((provider) => line(k, provider.name, provider.base_url, () => ({ api_key: "" })))];
  const group = lines.length ? [el("div", { className: "group" }, ...lines)] : [];
  const names = here.map((provider) => provider.name).join(comma());
  if (there.length) k.servers.replaceChildren(...group, entry(k));
  else k.servers.replaceChildren(...group, ...nothing(k, (own ? wording("setup-no-other-server", { names }) : wording("setup-no-server", { names }))));
}
