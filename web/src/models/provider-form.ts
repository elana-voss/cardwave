// The parts of first run and the settings that set a model up: `field`, a control under its label (`.fld`:
// the label, the control, with the button that acts on it beside it in `.find`, and the hint); `keyStored`, what
// a key's field says of a key stored; `modelName`, a model as the user reads it; `plain` and `listed`, by which the list of providers finds its provider at
// an address (one with `localhost` is the list's `127.0.0.1`); `modelCount`, `listedCount` and `askingWords()`, words
// the screens say of an address's models.
// A model as the screens have it: `modelLine`, its line in a box of lines (`.item.model`: what it says, the
// button that sets the model, "Retry", and under them what failed, `.item-wrong`); `modelTest`, the test of a
// model and what it came to; `models`, the models an address lists (`ask`, let go by `forget`) with `pick`, the
// model picker of first run and the coding team, a `dialog` with the class `picker` around a `suggest` whose
// list is part of the dialog, over whose list `counted` says how many models are listed and how many of them
// have what was typed, or why none came, with "Retry". Each drops an answer that is not its last asking's.
// `offering` is what a model's field offers of them, at most `OFFERED` at a time.
import { listModels, testModel } from "../api/client";
import type { KnownProvider } from "../api/generated/KnownProvider";
import type { ListedModels } from "../api/generated/ListedModels";
import type { ListModels } from "../api/generated/ListModels";
import type { NamedModels } from "../api/generated/NamedModels";
import type { ProviderView } from "../api/generated/ProviderView";
import type { TestModel } from "../api/generated/TestModel";
import { el, failure, reason, suggest, told } from "../dom";
import { clause } from "../format";
import { dialog } from "../dialogs";
import { icon } from "../icons";
import { wording } from "../language/language";

/** How many of an address's models a field offers at a time: a provider may list thousands. */
const OFFERED = 200;

/** An address as the server keeps it: without space around it and a slash at its end. */
export const plain = (address: string) => address.trim().replace(/\/+$/, "");

/** A model as the user reads it: the name models.dev gives, else the last part of its ID in words, each with a capital. */
export function modelName(id: string, names?: Record<string, string>): string {
  const known = names?.[id];
  if (known) return known;
  const last = id.split("/").pop() || id;
  return last
    .split(/[-_\s]+/)
    .filter(Boolean)
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join(" ");
}

/** An address as the list would have it: this machine by its number, as the list has the servers on it. */
const asListed = (address: string) => plain(address).replace(/^http:\/\/localhost/i, "http://127.0.0.1");

/** What a key's field says in its place while a key is stored: which one, by its end, as far as that is told. */
export const keyStored = (provider: Pick<ProviderView, "has_key" | "key_end"> | null) => (provider?.has_key ? (provider.key_end ? wording("provider-form-is-saved", { key_end: provider.key_end }) : wording("provider-form-a-key-is-saved")) : "");

/** The provider of `list` whose API is at `address`. */
export const listed = (list: KnownProvider[], address: string) => list.find((provider) => provider.base_url === asListed(address));

/** How many models a list has, in words. */
export const modelCount = (count: number) => wording("provider-form-models", { count });

/** How many models an address has listed, in words, and that more did not come, where that is so. */
export const listedCount = ({ models, more }: ListedModels) => (more ? wording("provider-form-listed-not-all", { count: models.length }) : wording("provider-form-listed", { count: models.length }));

/** What a form says while an address is asked for its models. */
export const askingWords = () => (wording("provider-form-asking-the-provider-for"));

/**
 * What the model picker says under its list: how many models the address lists, and how many of them have what
 * was `typed` into its field, if anything was.
 */
export function counted(list: ListedModels, typed: string): string {
  if (!list.models.length) return wording("provider-form-the-provider-lists-no");
  const part = typed.trim();
  const have = part ? wording("provider-form-have", { count: offering(() => list.models, Infinity)(part).length, part }) : "";
  return wording("provider-form-or-type-the-models", { listedCount: listedCount(list), have });
}

/**
 * What a model's field offers of `models` for what was typed into it: those whose ID holds every word typed,
 * whatever its order or case, at most `most`. Each word narrows on its own (as the Flutter app's model filter
 * does), so "deepseek flash" finds "deepseek-…-flash", which the whole string, with its space, never matched.
 */
export const offering =
  (models: () => string[], most = OFFERED) =>
  (typed: string) => {
    const parts = typed.toLowerCase().split(/\s+/).filter(Boolean);
    return models()
      .filter((id) => parts.every((part) => id.toLowerCase().includes(part)))
      .slice(0, most);
  };

/**
 * A control under its label, with a hint that is not part of its name, and beside it the button that acts on it,
 * if it has one. `around` is what the control stands in, if it brings more than itself.
 */
export function field(label: string, input: HTMLInputElement, hint?: string | HTMLElement, beside?: HTMLElement, around: HTMLElement = input): HTMLElement {
  input.id = `provider-${input.name}`;
  const note = typeof hint === "string" ? el("small", { className: "hint" }, hint) : hint;
  const control = beside ? el("div", { className: "find flex ai-c g-8" }, around, beside) : around;
  input.classList.add("field");
  return el("div", { className: "fld" }, el("label", { className: "label", htmlFor: input.id }, label), control, note);
}

/** A model's line in a box of lines. */
export interface ModelLine {
  node: HTMLElement;
  /** The button that sets the model. */
  change: HTMLButtonElement;
  /** Asks again for what failed; it shows while something has. */
  retry: HTMLButtonElement;
  /** What the line says under its name, with the blue tick after it where `ticked`, what failed, if anything, and what its button does: "Change", "Choose", "Set up". */
  show(says: string | Node, failed: string, action: string, ticked?: boolean): void;
}

/**
 * Makes a model's line, the chat model's unless `label` and `what` name another: its name over what it says, at the
 * right the button that sets the model and "Retry", and under them, as wide as the line, what failed, in red.
 */
export function modelLine(label = wording("page-chat"), what = wording("settings-the-chat-model")): ModelLine {
  const says = el("span", { className: "meta" });
  const wrong = el("div", { className: "item-wrong" });
  const change = el("button", { type: "button", className: "btn btn-secondary on-box" });
  const retry = el("button", { type: "button", className: "btn btn-secondary on-box", hidden: true }, wording("setup-try-again"));
  const text = el("div", { className: "item-text" }, el("span", { className: "item-label" }, label), says);
  return {
    node: el("div", { className: "item model" }, text, change, retry, wrong),
    change,
    retry,
    show(said, failed, action, ticked = false) {
      says.replaceChildren(said, ...(ticked ? [el("span", { className: "c-accent" }, icon("check", 14))] : []));
      if (wrong.textContent !== failed) wrong.replaceChildren(...(failed ? [failure(failed)] : []));
      retry.hidden = !failed;
      change.textContent = action;
      change.ariaLabel = wording("provider-form-text", { action, what });
    },
  };
}

/** The test of a chat model, as a screen asks for it and says what it came to. */
export interface ModelTest {
  /** What stands behind the model's name while it is tested and when it has passed. */
  said(): string;
  /** That the test failed and why, or nothing. */
  failed(): string;
  /** Whether the test is on its way, and whether it passed. */
  asking(): boolean;
  passed(): boolean;
  /** Ends a test on its way as failed, for `why`: it took too long. Its answer, when it comes, no longer counts. */
  giveUp(why: string): void;
  /**
   * Asks the model a small question. It costs a few tokens, so a screen asks when the model is set or "Retry" pressed, not by itself.
   * `own`: a model of This computer, which has no key or address to check, so its failure says what to do instead.
   */
  ask(whom: TestModel, own?: boolean): void;
  /** Lets go what a test came to, and one on its way: it was of another model, address or key. */
  forget(): void;
}

/** Makes the test of a screen's chat model. `changed` is told when a test begins and when its answer has come; `passed` is what stands behind the model's name then. */
export function modelTest(changed: () => void, passed = wording("provider-form-test-passed")): ModelTest {
  let tested: "no" | "asking" | "passed" | { failed: string; own?: boolean } = "no";
  /** The test whose answer counts. */
  let testing: object | null = null;
  /** Whether the last test asked is of This computer's model, for `giveUp`'s words too. */
  let ownModel = false;
  return {
    said: () => (tested === "asking" ? wording("provider-form-testing") : tested === "passed" ? passed : ""),
    failed() {
      if (typeof tested !== "object") return "";
      const failed = clause(tested.failed);
      return tested.own ? wording("provider-form-test-failed-own", { failed }) : wording("provider-form-test-failed", { failed });
    },
    asking: () => tested === "asking",
    passed: () => tested === "passed",
    giveUp(why) {
      if (tested !== "asking") return;
      testing = null;
      tested = { failed: why, own: ownModel };
      changed();
    },
    ask(whom, own = false) {
      const mine = (testing = {});
      ownModel = own;
      tested = "asking";
      changed();
      testModel(whom)
        .then(
          () => "passed" as const,
          (error) => ({ failed: told(error), own }),
        )
        .then((outcome) => {
          if (mine !== testing) return;
          tested = outcome;
          changed();
        });
    },
    forget() {
      testing = null;
      tested = "no";
    },
  };
}

/** The models an address lists, as a screen asks for them and has one of them picked. */
export interface Models {
  /** The list of models, if it came. */
  got(): NamedModels | null;
  /** Why no list of models came, if none did. */
  failed(): string;
  /** Whether the address is being asked. */
  asking(): boolean;
  /** Asks the address for its models, with the key. Only the last asking's answer counts. */
  ask(): void;
  /** Lets the list go, and an asking on its way: they are of another address or key. The picker asks anew. */
  forget(): void;
  /** Opens the model picker, called `title`, with `model` in its field; the model taken goes to `take`, else to the `choose` of `models`. */
  pick(model: string, title?: string, take?: (id: string) => void): void;
}

/**
 * Makes the models of a screen's address and their picker, a window in `home`: a field that offers the models the
 * address lists, and takes an ID typed as well. `whom` says which address is asked, with which key, `changed` is
 * told whenever what is known of the list is something else, and `choose` is given the model taken, where `pick`
 * names no other. `lister` asks for the list: the provider's models, or its image models (images-setup.ts).
 */
export function models<A = ListModels>(
  home: HTMLElement,
  whom: () => A,
  changed: () => void,
  choose: (id: string) => void = () => {},
  lister: (asked: A) => Promise<NamedModels> = listModels as (asked: A) => Promise<NamedModels>,
): Models {
  /** The models the address listed, why none came, or that they are on their way; `null` while it was not asked. */
  let listed: NamedModels | { failed: string } | "asking" | null = null;
  /** The asking whose answer counts. */
  let asking: object | null = null;
  /** Tells the model picker, while it is open, that the list of models has changed. */
  let picker: (() => void) | null = null;
  const got = () => (listed && typeof listed === "object" && "models" in listed ? listed : null);
  const failed = () => (listed && typeof listed === "object" && "failed" in listed ? listed.failed : "");

  function ask(): void {
    const mine = (asking = {});
    /** Takes what the asking has come to, unless a later one counts by now. */
    const came = (now: NonNullable<typeof listed>) => {
      if (mine !== asking) return;
      listed = now;
      picker?.();
      changed();
    };
    came("asking");
    lister(whom()).then(came, (error) => came({ failed: told(error) }));
  }

  return {
    got,
    failed,
    asking: () => listed === "asking",
    ask,
    forget() {
      asking = null;
      listed = null;
    },
    pick(model, title = wording("kinds-chat-model"), take = choose) {
      // Under a name of its own: the screen may have a field for the model too. It opens empty, a search (board
      // ModelPicker), the model in use ticked in the list; sent empty, the model stays.
      const input = el("input", { name: "chat_model", placeholder: wording("kinds-search-the-models") });
      const hint = el("p", { className: "hint kind-hint", role: "status" });
      const offered = suggest(
        input,
        offering(() => got()?.models ?? []),
        true,
        model,
        // Each line the model's readable name, its ID in grey under it (Fable's design of first run's step 2).
        (id) => modelName(id, got()?.names),
      );
      const cancel = el("button", { type: "button", className: "btn btn-secondary" }, wording("common-cancel"));
      // The foot (`.dfoot`) stands outside the form, as the board ModelPicker draws it; Enter in the one field sends the form all the same.
      const form = el("form", { className: "dlg-body" }, field(wording("kinds-model"), input, undefined, undefined, offered.node), hint, offered.list);
      const use = el("button", { type: "button", className: "btn btn-primary", onclick: () => form.requestSubmit() }, wording("kinds-use-this-model"));
      const box = dialog(home, title, form, el("div", { className: "dfoot" }, use, cancel));
      box.classList.add("picker");
      cancel.onclick = () => box.close();
      form.onsubmit = (event) => {
        event.preventDefault();
        const id = input.value.trim();
        box.close();
        if (!id) return;
        take(id);
      };
      /** Says over the list, which is part of the window, what is known of the address's models. */
      const say = () => {
        if (listed === "asking") return void hint.replaceChildren(wording("kinds-asking-the-provider"));
        const list = got();
        // The model the field opened with, or one taken from the list, narrows nothing and is counted in nothing.
        if (list) return void hint.replaceChildren(counted(list, offered.typed()));
        if (!failed()) return;
        // Why no list came, with the way to ask again: the model's ID can be typed all the same.
        const again = el("button", { type: "button", className: "textbtn" }, wording("setup-try-again"));
        again.onclick = () => {
          input.focus();
          ask();
        };
        hint.replaceChildren(failure(reason(failed())), again);
      };
      picker = () => {
        say();
        if (got() && document.activeElement === input) offered.open();
      };
      input.addEventListener("input", say);
      box.addEventListener("close", () => (picker = null));
      input.focus();
      // The models are asked for when they are wanted first, where the screen has not asked, here; and again after a
      // list that did not come, which may come now.
      if (listed && !failed()) picker();
      else ask();
    },
  };
}
