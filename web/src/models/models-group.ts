// A group of model lines over the account's providers, as Settings has it in "Models" (Chat and Images, then
// Voice and Search as `more`) and Settings › Advanced in "Helper model" (Helper). Each line is its kind's model and provider, with "Change", which opens the model picker of that
// kind (kinds.ts). Traps: a reading that comes after a later one is not taken (`latest`); where a kind's model
// or provider is another after one, what its test came to goes, and the providers' lists of models where a
// provider's address or key is.
import { getProviderList } from "../api/client";
import type { Kind } from "../api/generated/Kind";
import type { ProvidersView } from "../api/generated/ProvidersView";
import { el, group, latest, noticeBox } from "../dom";
import { catalogs, kindOf, pickKind, says } from "./kinds";
import { modelLine, modelTest } from "./provider-form";
import { wording } from "../language/language";

/** Opens first run, which begins with what is stored and leads back here when it is confirmed. */
export const setup = () => (location.hash = "#/setup");

/** A line at a group's foot that is told where its kind is (Voice, Search). */
export type MoreLine = { node: HTMLElement; at(said: string | null, change: (() => void) | null): void; local(): void; kind: Kind };

/**
 * The group `title`: `lead` first (Settings' line to Providers), then a line per kind of `kinds` (with what its
 * picker calls the model), then `more`, each told where its kind is at a provider (`at`: "[model] · [provider]")
 * and, where the account has a provider, given the picker of the kind for its button, whose "This computer" then
 * opens what the line opens on its own (`local`); `foot` last, lines of no kind (Dictation); `onList` is told each
 * list read (Settings' line to Providers). A model taken
 * is stored at once; Chat's and Background's are asked a small question then, at their provider's address with
 * its key: what the test comes to stands in the line. Without a background model its line says the chat model
 * does that work; without a chat model Chat says "Not configured" with "Set up", which opens first run.
 */
export function modelsGroup(options: { title: string; kinds: [Kind, string][]; lead?: HTMLElement[]; more?: MoreLine[]; foot?: HTMLElement[]; onList?: (now: ProvidersView) => void }): { node: HTMLElement; read(): void } {
  const { title, lead = [], more = [], foot = [], onList } = options;
  const notice = noticeBox();
  /** The account's providers and kinds; not set until the server has said. */
  let view: ProvidersView | undefined;
  const lists = catalogs(() => {});
  /** A kind's line, and the test of its model where it has one. */
  const line = (kind: Kind, what: string) => {
    const shown = modelLine(kindOf(kind).label, what);
    const check = kind === "images" ? null : modelTest(draw);
    const test = () => {
      const picked = view?.kinds.find((each) => each.kind === kind);
      const provider = view?.providers.find((each) => each.id === picked?.provider_id);
      if (picked && provider && node.isConnected) check?.ask({ base_url: provider.base_url, model: picked.model });
    };
    shown.change.onclick = () => (view?.kinds.some((each) => each.kind === "chat") || view?.providers.length ? pickKind(node, kind, view, lists, took(test)) : setup());
    shown.retry.onclick = () => {
      // The button goes while it is asked again.
      shown.change.focus();
      test();
    };
    return { kind, shown, check };
  };
  const lines = options.kinds.map(([kind, what]) => line(kind, what));
  /** Shows what a pick stored, and has its model tested. */
  const took = (test: () => void) => (now: ProvidersView) => {
    view = now;
    draw();
    test();
  };
  const node = group(
    title,
    null,
    notice,
    el("div", { className: "group" }, ...lead, ...lines.map(({ shown }) => shown.node), ...more.map((line) => line.node), ...foot),
  );

  function draw(): void {
    const chat = view && says(view, "chat");
    for (const line of more) {
      const taken = (now: ProvidersView) => {
        took(() => {})(now);
        // The voice of the model taken is chosen on the page Voices.
        if (line.kind === "voice" || !now.kinds.some((each) => each.kind === line.kind)) line.local();
      };
      line.at(view ? says(view, line.kind) : null, view?.providers.length ? () => view && pickKind(node, line.kind, view, lists, taken) : null);
    }
    for (const { kind, shown, check } of lines) {
      shown.change.disabled = view === undefined;
      if (!view) {
        shown.show("", "", wording("password-change"));
        continue;
      }
      const model = says(view, kind);
      const tested = check?.said() ?? "";
      // The background model says what it does (the owner, 2026-10-15).
      const does = kind === "background" && !tested ? wording("setup-worker-does") : "";
      if (model) shown.show(model + (tested || does), check?.failed() ?? "", wording("password-change"));
      else if (kind === "chat") shown.show(wording("models-group-not-configured"), "", wording("downloaded-set-up"));
      else if (kind === "background") shown.show(chat ? wording("setup-same-as-chat") : wording("models-group-not-configured"), "", wording("password-change"));
      else shown.show(wording("providers-not-set-up"), "", wording("downloaded-set-up"));
    }
  }
  const read = latest(notice, getProviderList, (now) => {
    const where = (of: ProvidersView | undefined) => JSON.stringify(of?.providers.map(({ id, base_url, key_end, has_key }) => [id, base_url, key_end, has_key]));
    if (view !== undefined && where(now) !== where(view)) lists.forget();
    for (const { kind, check } of lines) {
      if (view !== undefined && says(now, kind) !== says(view, kind)) check?.forget();
    }
    view = now;
    draw();
    onList?.(now);
  });
  // Until the server has said what is stored the lines say nothing; where it does not say, the group says why.
  draw();
  void read();
  return { node, read: () => void read() };
}
