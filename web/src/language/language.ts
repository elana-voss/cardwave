// The UI's words, in Fluent (`@fluent/bundle`, named in this module alone): `wording(key, args)` is a text of the UI
// in the language in use, from that language's files beside this one, `<code>.ftl` and its parts `<code>.<part>.ftl`
// (a file stays under 1,000 lines), English (`en.ftl`, `en.*.ftl`) built in and any other read when it is taken. A
// further language is a file. The language is the one chosen (Settings' "Language of the app", `chooseLanguage`,
// `appLanguages` the list, each in its own words); while none is, the computer's where a file has it (Portuguese
// Brazil's, Chinese by its script: `appCode`), else English (`followComputer`), switching live when the computer's
// changes. `useLanguage` takes one from its file's text (the tests' made-up language), and every module that drew
// words hears it (`onLanguage`): the shell redraws itself and the tabs make their screens anew (tabs.ts `relanguage`).
// Traps: a key is written out where it is used, `wording("rail-create")`, never put together: the build looks
// for every key used in the English file and fails on one it lacks (keys.ts, vite.config.ts), and cannot see
// one put together. A key a language other than English lacks is said in English. Placeables are not wrapped in
// Unicode isolation marks (`useIsolating: false`), so a text reads as written; a number is written ungrouped (1234,
// as the code wrote it), still a number to pick a plural by.
import { FluentBundle, FluentNumber, FluentResource, type FluentVariable } from "@fluent/bundle";

/** What a text is told: its placeables by name. */
export type Args = Record<string, string | number>;

/** English's text, all its files in one. */
export const englishText = Object.values(import.meta.glob<string>("./en{,.*}.ftl", { query: "?raw", import: "default", eager: true })).join("\n");

/** The languages' files beside this one, by their paths, read when taken. */
const FILES = import.meta.glob<string>("./*.ftl", { query: "?raw", import: "default" });

/** A language's code, of its file's path: "de" of "./de.ftl" and of "./de.chat.ftl". */
const codeOf = (path: string) => path.slice(2).split(".")[0];

/** The text of a language's files, all in one. */
const textOf = async (code: string) =>
  (await Promise.all(Object.keys(FILES).filter((path) => codeOf(path) === code).map((path) => FILES[path]()))).join("\n");

/** A language's words from its file's text; what the file holds wrongly is left out of it. */
function bundleOf(code: string, source: string): FluentBundle {
  const bundle = new FluentBundle(code, { useIsolating: false });
  // A message the file holds wrongly is skipped by Fluent and said in English then.
  bundle.addResource(new FluentResource(source));
  return bundle;
}

const ENGLISH = bundleOf("en", englishText);
let now = ENGLISH;
const heard = new Set<() => void>();

/** The text of `key` in the language in use, English where that language lacks it; the key itself where English does too. */
export function wording(key: string, args?: Args): string {
  for (const bundle of now === ENGLISH ? [ENGLISH] : [now, ENGLISH]) {
    const message = bundle.getMessage(key);
    // A placeable that cannot be said is said by its name: the text stands all the same.
    if (message?.value) return bundle.formatPattern(message.value, args && told(args), []);
  }
  return key;
}

/** Whether English has words for `key` (every key is said in English where the language in use lacks it). */
export const hasWords = (key: string) => ENGLISH.hasMessage(key);

/** The placeables as Fluent takes them: a number ungrouped, as `${n}` wrote it. */
function told(args: Args): Record<string, FluentVariable> {
  const out: Record<string, FluentVariable> = {};
  for (const [name, value] of Object.entries(args)) out[name] = typeof value === "number" ? new FluentNumber(value, { useGrouping: false }) : value;
  return out;
}

/** The language in use, by its code. */
export const language = () => now.locales[0];

/** A label as it stands inside a sentence: lowercased, but as written in German, whose nouns are capitalised. */
export const midSentence = (label: string) => (language() === "de" ? label : label.toLocaleLowerCase(language()));

/** Hears every change of language, after it; answers with what stops it. */
export function onLanguage(listener: () => void): () => void {
  heard.add(listener);
  return () => heard.delete(listener);
}

/** Takes the language `code` from its file's text `source` (English's own for "en"), and tells everyone who drew words. */
export function useLanguage(code: string, source?: string): void {
  if (code === language() && source === undefined) return;
  now = code === "en" && source === undefined ? ENGLISH : bundleOf(code, source ?? "");
  document.documentElement.lang = code;
  for (const listener of [...heard]) listener();
}

/**
 * The app's code for a computer's language `code`: Portuguese is Brazil's ("pt-BR"), Chinese is by its script
 * ("zh-Hans" or "zh-Hant", "zh-TW" and "zh-HK" traditional), every other by its language ("de" of "de-AT", "id" of "in").
 * The server's `file_code` (cw-core languages.rs) answers the same, both tested by `file-codes.json`.
 */
export function appCode(code: string): string {
  let locale: Intl.Locale;
  try {
    locale = new Intl.Locale(code).maximize();
  } catch {
    // Not a code Intl can read: its first part is all there is to go by.
    return code.split("-")[0].toLowerCase();
  }
  if (locale.language === "pt") return "pt-BR";
  if (locale.language === "zh") return locale.script === "Hant" ? "zh-Hant" : "zh-Hans";
  return locale.language;
}

/** The code of the first of the computer's languages that a file has, by its whole code or its app's code (`appCode`); English else. */
export function pick(wanted: readonly string[], have: readonly string[]): string {
  const of = (code: string) => have.find((one) => one.toLowerCase() === code.toLowerCase());
  for (const code of wanted) {
    const found = of(code) ?? of(appCode(code));
    if (found) return found;
  }
  return "en";
}

/** The language to take: the one `chosen` where a file has it, else the computer's (`pick`). */
export const wanted = (chosen: string | null, computer: readonly string[], have: readonly string[]) =>
  chosen !== null && have.includes(chosen) ? chosen : pick(computer, have);

/** The codes of the languages that have files. */
const codes = () => [...new Set(Object.keys(FILES).map(codeOf))];

/**
 * A language's name in the language in use (the list "Language the AI writes in"), first letter upper; `fallback` where Intl knows none.
 * `inSentence`: as the language writes it inside a sentence (English "German", Spanish "alemán"), the case Intl gives.
 */
export function languageName(code: string, fallback: string, inSentence = false): string {
  try {
    const name = new Intl.DisplayNames(language(), { type: "language", fallback: "none" }).of(code);
    if (name && inSentence) return name;
    if (name) return name.charAt(0).toLocaleUpperCase(language()) + name.slice(1);
  } catch {
    // A code Intl cannot read is named by the fallback.
  }
  return fallback;
}

/** The names Intl gives shorter than their speakers call the language: Indonesian's "Indonesia" is the country. */
const OWN_NAMES: Record<string, string> = { id: "Bahasa Indonesia" };

/** Each language by its code and its name in its own words, the code where Intl knows no name; a name's first letter upper. */
export function languagesNamed(have: readonly string[]): { code: string; name: string }[] {
  return have.map((code) => {
    if (OWN_NAMES[code]) return { code, name: OWN_NAMES[code] };
    let name = code;
    try {
      name = new Intl.DisplayNames(code, { type: "language", fallback: "code" }).of(code) ?? code;
    } catch {
      // A code Intl cannot read is named by itself.
    }
    return { code, name: name === code ? code : name.charAt(0).toLocaleUpperCase(code) + name.slice(1) };
  });
}

/** The app's languages, English first, then by their names. */
export const appLanguages = () => {
  const [english, ...rest] = languagesNamed(["en", ...codes().filter((code) => code !== "en")]);
  return [english, ...rest.sort((one, other) => one.name.localeCompare(other.name))];
};

/** The language chosen, none while the computer's is followed. */
let chosen: string | null = null;
/** Counts the takings, so that a file read late does not undo a later choice. */
let takings = 0;

/** Takes the chosen language, else the computer's. */
async function take(): Promise<void> {
  const at = ++takings;
  const code = wanted(chosen, navigator.languages ?? [navigator.language], codes());
  // The computer's list changed but not the language it picks (de-DE to de-AT): the screens stay as they are.
  if (code === language()) return;
  // A file that cannot be read leaves the language as it is.
  const source = code === "en" ? undefined : await textOf(code).catch(() => null);
  if (source !== null && at === takings) useLanguage(code, source);
}

/** Takes the computer's language where a file has it, now and whenever the computer's changes, while none is chosen. */
export function followComputer(): void {
  void take();
  window.addEventListener("languagechange", () => void take());
}

/** Takes the language `code` the user chose (Settings), or the computer's again for none. */
export function chooseLanguage(code: string | null): void {
  chosen = code;
  void take();
}
