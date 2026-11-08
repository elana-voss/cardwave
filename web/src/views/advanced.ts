// Account settings, the page "Advanced" (board "Settings › Advanced"), what is seldom changed (the split into
// basic and advanced, milestone 70): the groups "Helper model" (the server's `worker_model`;
// ../models/models-group.ts), "Chat without a character" (`plainGroup`), Library (`describeLines`), Data
// (`dataGroup`: export; the thumbnails keep in check by themselves, so the cache has no line), then
// "Sampling", the account's values for a reply for the chat model, the model presets (../settings/presets.ts) and the
// prompt presets (../settings/prompt-presets.ts), and last "Your own CSS" (../settings/own-css.ts) in a box of its own. Each
// setting stands here or in Settings, never in both.
//
// At `#/settings/advanced`: a page under the settings as the Trash is, with the path "Settings / Advanced", to
// which the settings' last box leads (`advancedGroup` in settings.ts). Sampling's six values stand in two
// columns (`.sampling`), one in a narrow window, each a text field for a number with a decimal point, kept as it
// is typed: no Save. A value out of its range, or no number, is red (`.wrong`), with its range under it, and
// is not kept; the others are, each change a store of all of them (`setSampling`), the last typed going last.
// A preset put in use, a store in another window (the event `provider`) and the server heard again have the
// values and the background model read anew, a field typed into since keeping what was typed; the settings
// changed in another window (the event `settings`) every line that shows one. One store at a time (`oneStore`)
// for a preset put in use; the presets are read anew after the values, as which is in use goes by them.
import { wording } from "../language/language";
import { failureWords } from "../language/errors";
import {
  changeSettings,
  describeCards,
  getDescribing,
  getDescribingAgain,
  getSampling,
  getSettings,
  describeAllAgain,
  setSampling,
  stopDescribingAgain,
} from "../api/client";
import type { Describing } from "../api/generated/Describing";
import type { DescribingAgain } from "../api/generated/DescribingAgain";
import type { ExportFormat } from "../api/generated/ExportFormat";
import type { Sampling } from "../api/generated/Sampling";
import type { ServerEvent } from "../api/generated/ServerEvent";
import type { Style } from "../api/generated/Style";
import { el, failure, group, item, newest, noticeBox, oneAtATime, reason, savedChoice, selectField, type View } from "../dom";
import { clause } from "../format";
import { modelsGroup } from "../models/models-group";
import { ownCssGroup } from "../settings/own-css";
import { lineFiller, settingSwitch } from "../settings/setting-lines";
import { presetsGroup } from "../settings/presets";
import { promptPresetsGroup } from "../settings/prompt-presets";
import { field } from "../models/provider-form";
import { LABELS } from "../setting-labels";

/** The sampling values, in the order of the page, with their ranges; whole numbers have none after the point. */
export const SAMPLING: { key: keyof Sampling; label: () => string; whole: boolean; min?: number; max?: number; hint?: () => string }[] = [
  { key: "context_size", label: () => wording("advanced-context-size"), whole: true, min: 512, hint: () => wording("advanced-context-hint") },
  { key: "temperature", label: () => wording("advanced-temperature"), whole: false, min: 0, max: 2, hint: () => wording("advanced-temperature-about") },
  { key: "top_p", label: () => wording("advanced-top-p"), whole: false, min: 0, max: 1, hint: () => wording("advanced-top-p-about") },
  { key: "frequency_penalty", label: () => wording("advanced-frequency"), whole: false, min: -2, max: 2, hint: () => wording("advanced-frequency-about") },
  { key: "presence_penalty", label: () => wording("advanced-presence"), whole: false, min: -2, max: 2, hint: () => wording("advanced-presence-about") },
  { key: "seed", label: () => wording("advanced-seed"), whole: true, hint: () => wording("advanced-seed-about") },
];

/** What a value's field holds as its value: `null` for empty, `undefined` where it is no number or out of its range. */
export function valueOf(typed: string, { whole, min, max }: (typeof SAMPLING)[number]): number | null | undefined {
  const text = typed.trim().replace(",", ".").replace("−", "-");
  if (!text) return null;
  const value = Number(text);
  if (!Number.isFinite(value) || (whole && !Number.isInteger(value))) return undefined;
  if ((min !== undefined && value < min) || (max !== undefined && value > max)) return undefined;
  return value;
}

/** What a value's field shows of the value `key` of `kept`: empty where it has none. */
const textOf = (kept: Sampling, key: keyof Sampling) => (kept[key] === null || kept[key] === undefined ? "" : String(kept[key]));

/** What a value's hint says while it is wrong. */
const range = ({ whole, min, max }: (typeof SAMPLING)[number]) =>
  min !== undefined && max !== undefined
    ? wording("advanced-from-to", { min: String(min).replace("-", "−"), max: String(max).replace("-", "−") })
    : min !== undefined
      ? wording("advanced-whole-from", { min: String(min) })
      : whole
        ? wording("advanced-whole")
        : wording("advanced-number");

/**
 * Runs a store unless one is on its way from this page, in which case it is not begun; answers whether it was.
 */
function oneStore(): (store: () => Promise<unknown>) => Promise<boolean> {
  let storing = false;
  return async (store) => {
    if (storing) return false;
    storing = true;
    try {
      await store();
    } finally {
      storing = false;
    }
    return true;
  };
}

/** The part "Sampling": its fields, kept as typed, and `read`, which shows what is stored. */
function samplingPart() {
  const notice = noticeBox();
  const fields = SAMPLING.map((value) => {
    const input = el("input", { name: value.key, className: "field", type: "text", inputMode: "decimal", autocomplete: "off" });
    const about = el("small", { className: "hint" }, value.hint?.() ?? "");
    return { ...value, input, about, node: field(value.label(), input, about) };
  });
  /** What each field showed when it was last filled: one that holds otherwise now was typed into. */
  let shown: string[] = fields.map(() => "");
  /** The stores on their way: the answer of one that is not the last is not shown. */
  let sending = 0;

  /** Shows the values `kept`, but in the fields typed into since they were last filled where `typed` says so. */
  function fill(kept: Sampling, typed = false): void {
    fields.forEach(({ key, input }, index) => {
      const text = textOf(kept, key);
      if (!typed || input.value === shown[index]) input.value = text;
      shown[index] = text;
    });
  }

  /** Keeps every value that is right, as it stands now. */
  async function keep(): Promise<void> {
    const values: Sampling = {} as Sampling;
    for (const value of fields) {
      const now = valueOf(value.input.value, value);
      const wrong = now === undefined;
      value.input.classList.toggle("wrong", wrong);
      value.input.ariaInvalid = String(wrong);
      value.about.textContent = wrong ? range(value) : (value.hint?.() ?? "");
      // A wrong value is not kept: the stored one stays.
      (values as Record<string, number | null>)[value.key] = wrong ? (valueOf(shown[fields.indexOf(value)], value) ?? null) : now;
    }
    const mine = ++sending;
    try {
      const kept = await setSampling(values);
      if (mine !== sending) return;
      shown = fields.map(({ key }) => textOf(kept, key));
      notice.replaceChildren();
    } catch (error) {
      if (mine === sending) notice.replaceChildren(failure(reason(error)));
    }
  }
  for (const { input } of fields) input.addEventListener("input", () => void keep());

  const node = el(
    "section",
    { className: "sampling-part flex f-col" },
    el("div", null, el("h2", { className: "t-heading" }, wording("advanced-sampling")), el("p", { className: "hint" }, wording("advanced-sampling-about"))),
    notice,
    el("div", { className: "sampling" }, ...fields.map(({ node }) => node)),
  );
  /** Reads what is stored; `typed` keeps what was typed into a field since it was last filled. */
  async function read(typed = true): Promise<void> {
    try {
      fill(await getSampling(), typed);
    } catch (error) {
      notice.replaceChildren(failure(reason(error)));
    }
  }
  return { node, read };
}

const formats = (): [ExportFormat, string][] => ([
  ["sillytavern_v3", wording("advanced-sillytavern-v3")],
  ["ccv4", wording("advanced-ccv4")],
]);

/** What the line "Cards described" says of how far the describing has come. */
function describedText({ waiting, left }: Describing): string {
  if (waiting > 0) return wording("advanced-describing", { count: String(waiting) });
  if (left === 0) return wording("advanced-all-described");
  return wording("advanced-not-described", { count: left });
}

/** The temporary line "Interview style" (the owner's yes): which of the three ways the interview asks; Tree at the start. */
function interviewLine(): HTMLElement[] {
  const wrong = el("div", { className: "item-wrong" });
  const options: [Style, string][] = [
    ["tree", wording("advanced-interview-tree")],
    ["cloud", wording("advanced-interview-cloud")],
    ["hybrid", wording("advanced-interview-hybrid")],
  ];
  const choice = savedChoice<Style>(
    LABELS.advanced.interview,
    options,
    wrong,
    () => getSettings().then((settings) => settings.interview_style),
    (style) => changeSettings({ interview_style: style }).then((settings) => settings.interview_style),
  );
  return [item(LABELS.advanced.interview, wording("advanced-interview-about"), choice.node), wrong];
}

/**
 * What a button's server call and a fresh reading share: only the answer to the newest question is shown (a reading
 * sent before a press is older than the press's answer; one sent since, newer), and a reading's failure stands in `why`.
 */
function freshest<T>(get: () => Promise<T>, show: (now: T) => void, why: HTMLElement) {
  const order = newest();
  return {
    read() {
      const mine = order.ask();
      get().then(
        (now) => void (order.take(mine) && show(now)),
        (error) => void (order.take(mine) && why.replaceChildren(failure(reason(error)))),
      );
    },
    async press(call: () => Promise<T>) {
      const mine = order.ask();
      const now = await call();
      if (order.take(mine)) show(now);
    },
  };
}

/** Rewrites a line's failure only when its words changed. */
function showFailed(why: HTMLElement, failed: string) {
  if (why.textContent !== failed) why.replaceChildren(...(failed ? [failure(failed)] : []));
}

/**
 * The two lines of "Library" for the cards the worker model describes: the switch that has it describe each card
 * imported, which is the server's setting and off until it is set, and "Characters described": "Describe characters" describes
 * every character not described yet, "Describe all again" every character not in the Trash anew, a Stop while it runs. The
 * line says how far either has come; why the last that failed did stands under it, each in its own place. The cost
 * stands in the line (tools/needs_measure.py again-cost; no dialog). `read` asks how far anew: when the line is made,
 * and when the server tells of a card queued or described.
 */
function describeLines(): { lines: HTMLElement[]; read(): void; readSwitch(): void } {
  const wrong = el("div", { className: "item-wrong" });
  const attempt = oneAtATime(wrong);
  const label = LABELS.advanced.describe;
  const { toggle, show: showSwitch } = settingSwitch(attempt, label, "describe_imported");
  const says = el("span", { className: "meta" });
  const why = el("div", { className: "item-wrong" });
  const whyAgain = el("div", { className: "item-wrong" });
  const button = el("button", { type: "button", className: "btn btn-secondary on-box", disabled: true }, wording("advanced-describe-cards"));
  const againButton = el("button", { type: "button", className: "btn btn-secondary on-box", disabled: true }, wording("advanced-describe-again"));
  let describing: Describing | null = null;
  let again: DescribingAgain | null = null;
  const say = () => {
    if (again && again.waiting > 0) says.textContent = wording("advanced-describe-again-far", { done: again.done, all: again.done + again.waiting });
    else if (again && again.characters === 0) says.textContent = wording("advanced-no-characters");
    else if (describing) says.textContent = describedText(describing);
  };
  const cards = freshest(
    getDescribing,
    (now) => {
      describing = now;
      button.disabled = now.waiting > 0 || now.left === 0;
      say();
      showFailed(why, now.waiting === 0 && now.failure ? wording("advanced-failed", { count: now.failed, failure: clause(failureWords(now.failure)) }) : "");
    },
    why,
  );
  const characters = freshest(
    getDescribingAgain,
    (now) => {
      again = now;
      const running = now.waiting > 0;
      againButton.textContent = running ? wording("advanced-describe-again-stop") : wording("advanced-describe-again");
      againButton.disabled = !running && now.characters === 0;
      say();
      showFailed(whyAgain, !running && now.failure ? wording("advanced-describe-again-failed", { count: now.failed, failure: clause(failureWords(now.failure)) }) : "");
    },
    whyAgain,
  );
  const refused = el("div", { className: "item-wrong" }); // its own place: the readings rewrite `why` and `whyAgain`
  const pressing = oneAtATime(refused);
  button.onclick = () => pressing(() => cards.press(describeCards));
  againButton.onclick = () => pressing(() => characters.press(again && again.waiting > 0 ? stopDescribingAgain : describeAllAgain));
  const read = () => {
    cards.read();
    characters.read();
  };
  const readSwitch = () =>
    void getSettings().then(showSwitch, (error) => wrong.replaceChildren(failure(reason(error))));
  readSwitch();
  read();
  const switchLine = item(label, wording("advanced-describe-about"), toggle);
  const describedLine = item(LABELS.advanced.described, says, button);
  says.after(el("span", { className: "meta" }, wording("advanced-describe-again-about")));
  switchLine.append(wrong);
  describedLine.append(againButton, refused, why, whyAgain);
  return {
    lines: [switchLine, describedLine],
    read,
    readSwitch,
  };
}

/**
 * The group "Chat without a character": the one text every such chat's AI is told (the owner, 2026-10-18), its
 * `{{date}}` and `{{time}}` filled in at each message, written in place and saved on leaving it, each save after
 * the one before, so a change left while one is on its way is not lost.
 */
function plainGroup(): { node: HTMLElement; read(): void } {
  const notice = noticeBox();
  let saving = Promise.resolve();
  const told = el("textarea", { className: "field on-box w100 bb", ariaLabel: LABELS.advanced.told, rows: 2, disabled: true });
  let kept = "";
  const grow = () => {
    told.style.height = "auto";
    told.style.height = `${told.scrollHeight}px`;
  };
  told.oninput = grow;
  told.onblur = () => {
    const text = told.value;
    saving = saving.then(async () => {
      if (text === kept) return;
      notice.replaceChildren();
      try {
        kept = (await changeSettings({ plain_prompt: text })).plain_prompt;
      } catch (error) {
        notice.replaceChildren(failure(reason(error)));
      }
    });
  };
  const read = () =>
    void getSettings().then((settings) => {
      kept = settings.plain_prompt;
      if (document.activeElement !== told) told.value = kept;
      told.disabled = false;
      requestAnimationFrame(grow);
    }, () => {});
  read();
  const node = group(
    wording("advanced-plain"),
    null,
    notice,
    el(
      "div",
      { className: "group" },
      el(
        "div",
        { className: "item plain-told f-col ai-st g-10" },
        el("div", { className: "item-text" }, el("span", { className: "item-label" }, LABELS.advanced.told), el("span", { className: "meta" }, wording("advanced-told-about"))),
        told,
      ),
    ),
  );
  return { node, read };
}

/**
 * The group "Data" of Advanced: what Export writes (its format, and whether a CCV4 card holds each text's
 * earlier versions).
 */
function dataGroup(): { node: HTMLElement; read(): void } {
  const notice = noticeBox();
  const attempt = oneAtATime(notice);
  const format = selectField(
    formats().map(([value, label]) => ({ value, label })),
    formats()[0][0],
    (value) =>
      attempt(async () => {
        try {
          kept = (await changeSettings({ export_format: value as ExportFormat })).export_format;
        } finally {
          // A choice the server did not take is not shown as made.
          format.value = kept;
        }
      }),
    { id: "export-format", disabled: true, wide: true },
  );
  const historyLabel = LABELS.advanced.history;
  const history = settingSwitch(attempt, historyLabel, "export_history");
  /** The format the server holds. */
  let kept: ExportFormat;
  const fill = lineFiller(notice);
  const read = () =>
    fill(getSettings, (settings) => {
      format.value = kept = settings.export_format;
      format.field.disabled = false;
      history.show(settings);
    });
  read();
  const node = group(
    wording("advanced-data"),
    null,
    notice,
    el(
      "div",
      { className: "group" },
      item(
        el("label", { className: "item-label", htmlFor: format.field.id }, LABELS.advanced.format),
        el("span", { className: "meta" }, wording("advanced-format-about")),
        format.node,
      ),
      item(historyLabel, wording("advanced-history-about"), history.toggle),
    ),
  );
  return { node, read: () => void read() };
}

export function advancedView(): View {
  const alone = oneStore();
  const sampling = samplingPart();
  const presets = presetsGroup(() => node, {
    alone,
    stored: () => void sampling.read(false),
  });
  const prompts = promptPresetsGroup();
  const background = modelsGroup({
    title: wording("advanced-helper"),
    kinds: [["background", wording("advanced-the-helper")]],
  });
  const plain = plainGroup();
  const described = describeLines();
  // The group "Library": the lines of the cards the background model describes (the owner, 2026-10-15).
  const library = group(wording("advanced-library"), null, el("div", { className: "group" }, ...described.lines, ...interviewLine()));
  const data = dataGroup();
  const own = ownCssGroup(() => node);
  // A page under the settings, as the Trash is.
  const node = el(
    "section",
    { className: "main main-form" },
    el(
      "header",
      { className: "pbar" },
      el("nav", { className: "crumbs", ariaLabel: wording("crumbs") }, el("a", { href: "#/settings" }, wording("page-settings")), "/", el("b", null, wording("page-advanced"))),
    ),
    el("div", { className: "page-col mt-12" }, background.node, plain.node, library, data.node, sampling.node, presets.node, prompts.node, own.node),
  );
  // The presets are read after the values, as which is in use goes by them.
  const reread = (typed = true) => void sampling.read(typed).then(presets.read);
  reread(false);
  void prompts.read();
  /** Every line that shows a setting reads it anew. */
  const settled = () => {
    plain.read();
    data.read();
    described.readSwitch();
    own.read();
  };
  return {
    node: node,
    left: own.left,
    onEvent(event: ServerEvent) {
      if (event.type === "presets") void presets.read();
      if (event.type === "provider") {
        reread();
        background.read();
      }
      if (event.type === "descriptions") described.read();
      if (event.type === "settings") settled();
    },
    onConnected: () => {
      reread();
      void prompts.read();
      background.read();
      described.read();
      settled();
    },
  };
}
