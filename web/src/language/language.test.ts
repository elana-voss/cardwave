// The UI's words (language.ts): which of the computer's languages is taken, a language that lacks a text, and
// every message of the English file read.
import { afterEach, expect, it, vi } from "vitest";
import { appCode, followComputer, language, languagesNamed, languageName, midSentence, onLanguage, pick, useLanguage, wanted, wording, englishText as english } from "./language";
import { keysOf } from "./keys";
import fileCodes from "./file-codes.json";

afterEach(() => useLanguage("en"));

it("takes the first of the computer's languages a file has, by its whole code or its first part, English else", () => {
  expect(pick(["de-AT", "fr"], ["en", "fr", "de"])).toBe("de");
  expect(pick(["pt-BR", "pt"], ["en", "pt-BR", "pt"])).toBe("pt-BR");
  expect(pick(["ja"], ["en", "fr"])).toBe("en");
});

it("matches each computer's language to one of the app's: Spanish and Portuguese (Brazil) for every country, Chinese by its script", () => {
  const have = ["en", "es", "pt-BR", "ru", "hi", "ja", "ko", "vi", "zh-Hans", "zh-Hant", "de", "id"];
  const asked = ["es", "es-MX", "es-419", "pt", "pt-PT", "pt-BR", "ru-RU", "hi-IN", "ja-JP", "ko-KR", "vi-VN", "zh", "zh-CN", "zh-SG", "zh-TW", "zh-HK", "zh-MO", "zh-Hant-CN", "de-AT", "id-ID", "in", "fr-FR"];
  expect(asked.map((code) => pick([code], have))).toEqual(
    ["es", "es", "es", "pt-BR", "pt-BR", "pt-BR", "ru", "hi", "ja", "ko", "vi", "zh-Hans", "zh-Hans", "zh-Hans", "zh-Hant", "zh-Hant", "zh-Hant", "zh-Hant", "de", "id", "id", "en"],
  );
});

it("gives each locale the file code the server gives it (cw-core's file_code, the same table)", () => {
  for (const [locale, code] of Object.entries(fileCodes)) expect(appCode(locale), locale).toBe(code);
});

it("takes the language chosen where a file has it, the computer's while none is", () => {
  expect(wanted("fr", ["de-AT"], ["en", "fr", "de"])).toBe("fr");
  expect(wanted(null, ["de-AT"], ["en", "fr", "de"])).toBe("de");
  expect(wanted("ja", ["de-AT"], ["en", "fr", "de"])).toBe("de");
});

it("names each of the app's languages in its own words, a made-up one by its code", () => {
  expect(languagesNamed(["en", "de", "fr", "pt-BR", "id", "xx"])).toEqual([
    { code: "en", name: "English" },
    { code: "de", name: "Deutsch" },
    { code: "fr", name: "Français" },
    { code: "pt-BR", name: "Português (Brasil)" },
    { code: "id", name: "Bahasa Indonesia" },
    { code: "xx", name: "xx" },
  ]);
});

it("says a text in the language taken, in English where that language lacks it, and tells who drew words", () => {
  const heard = vi.fn();
  const stop = onLanguage(heard);
  expect(wording("rail-show-more", { count: 10 })).toBe("Show 10 more");
  useLanguage("xx", "rail-show-more = Mehr { $count }\n");
  expect([language(), document.documentElement.lang, heard.mock.calls.length]).toEqual(["xx", "xx", 1]);
  expect(wording("rail-show-more", { count: 10 })).toBe("Mehr 10");
  expect(wording("rail-create")).toBe("Create");
  stop();
});

it("defines each key once over the English files, which Fluent would read as the first file's", () => {
  const ids = [...english.matchAll(/^([a-zA-Z][\w-]*)\s*=/gm)].map((found) => found[1]);
  expect(ids.filter((id, at) => ids.indexOf(id) !== at)).toEqual([]);
});

it("reads every message of the English file, which Fluent would skip where it is written wrongly", () => {
  expect([...keysOf(english)].filter((key) => wording(key) === key)).toEqual([]);
});

it("writes a number as the code did, without grouping, and still picks its plural", () => {
  expect(wording("trash-persona-used", { count: 1234 })).toBe("Persona · used in 1234 chats");
  expect(wording("trash-persona-used", { count: 1 })).toBe("Persona · used in 1 chat");
});

it("puts a label inside a sentence lowercased, but keeps German's capitalised nouns", () => {
  expect(midSentence("Chat model")).toBe("chat model");
  useLanguage("de", "");
  expect(midSentence("Chatmodell")).toBe("Chatmodell");
});

it("names a language the AI writes in, in the language in use, by the server's name where Intl knows none", () => {
  useLanguage("de", "");
  expect(languageName("fr", "French")).toBe("Französisch");
  expect(languageName("not a code", "Other")).toBe("Other");
});

it("names a language inside a sentence as the language in use writes it there", () => {
  useLanguage("es", "");
  expect(wording("card-languages-translating-into", { name: languageName("de", "German", true), doing: "1" })).toContain("alemán");
  useLanguage("en", "");
  expect(languageName("de", "German", true)).toBe("German");
});

it("is done following the computer once its language is in use, so a screen drawn after it is in that language", async () => {
  vi.spyOn(navigator, "languages", "get").mockReturnValue(["de-DE"]);
  await followComputer();
  expect(language()).toBe("de");
});
