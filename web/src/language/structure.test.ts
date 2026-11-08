// The structure test of the UI's words. English (`en.ftl`, `en.*.ftl`) is the golden file: every other
// language's files, read together, hold English's messages and terms, each with English's structure, and differ
// from it only in their words. `differences` parses with `@fluent/syntax` (Fluent's own parser, named in this file
// alone) and names, one line each: a file that does not parse (a select without its default `*` variant is one),
// a key twice, a message, term or attribute missing or extra, and per one a different set of `$variables`, of
// functions with their options, of message and term references, or of selects. A select whose English variants
// are English's plural forms (one, other; numbers such as `[0]` aside) is a plural one: its variants in a language
// are that language's forms (`Intl.PluralRules`; numbers free); any other select, `[1] [2] *[other]` too, keeps
// English's variants.
// Traps: a language needing a plural form where English has none gets a select in English too, `*[other]` alone.
import {
  BaseNode,
  FunctionReference,
  Junk,
  lineOffset,
  Message,
  MessageReference,
  parse,
  type Pattern,
  SelectExpression,
  serializeExpression,
  serializeVariantKey,
  Term,
  TermReference,
  TextElement,
  VariableReference,
} from "@fluent/syntax";
import { expect, it } from "vitest";

/** What a message's value or attribute is built of, its words aside; a select's variants by its selector, once per select. */
interface Shape {
  variables: Set<string>;
  functions: Set<string>;
  references: Set<string>;
  selects: Map<string, string[][]>;
  /** Selectors of a select whose `[one]` variant writes the number 1 itself, not as a placeable. */
  literalOne: Set<string>;
}

/** The shape of a pattern: every node in it, the variants' patterns and a call's arguments too. */
function shapeOf(pattern: Pattern): Shape {
  const shape: Shape = { variables: new Set(), functions: new Set(), references: new Set(), selects: new Map(), literalOne: new Set() };
  const visit = (node: unknown): void => {
    if (Array.isArray(node)) return node.forEach(visit);
    if (!(node instanceof BaseNode)) return;
    if (node instanceof VariableReference) shape.variables.add(`$${node.id.name}`);
    else if (node instanceof FunctionReference) {
      const options = node.arguments.named.map((option) => `${option.name.name}: ${serializeExpression(option.value)}`).sort();
      shape.functions.add(`${node.id.name}(${options.join(", ")})`);
    } else if (node instanceof MessageReference || node instanceof TermReference) {
      const sign = node instanceof TermReference ? "-" : "";
      shape.references.add(`${sign}${node.id.name}${node.attribute ? `.${node.attribute.name}` : ""}`);
    } else if (node instanceof SelectExpression) {
      const selector = serializeExpression(node.selector);
      const keys = node.variants.map((variant) => serializeVariantKey(variant.key)).sort();
      shape.selects.set(selector, [...(shape.selects.get(selector) ?? []), keys]);
      const one = node.variants.find((variant) => serializeVariantKey(variant.key) === "one");
      const text = one?.value.elements.filter((element) => element instanceof TextElement).map((element) => element.value);
      if (text?.some((words) => /(^|[^\d.,])1($|[^\d.,])/.test(words))) shape.literalOne.add(selector);
    }
    for (const [field, value] of Object.entries(node)) if (field !== "span") visit(value);
  };
  visit(pattern);
  return shape;
}

/** The units of files, a message's or term's value by its key and each attribute by `key.attr`, the first of a key twice; and what is wrong in them. */
function unitsOf(files: [string, string][]): { units: Map<string, Shape>; wrong: string[]; twice: string[] } {
  const units = new Map<string, Shape>();
  const wrong: string[] = [];
  const twice: string[] = [];
  const keys = new Set<string>();
  for (const [name, text] of files) {
    for (const entry of parse(text, { withSpans: true }).body) {
      if (entry instanceof Junk) {
        const where = entry.annotations[0]?.span?.start ?? entry.span?.start ?? 0;
        wrong.push(`${name}:${lineOffset(text, where) + 1}: does not parse: ${entry.annotations.map((note) => note.message).join("; ")}`);
      }
      if (!(entry instanceof Message || entry instanceof Term)) continue;
      const key = `${entry instanceof Term ? "-" : ""}${entry.id.name}`;
      if (keys.has(key)) twice.push(key);
      if (keys.has(key)) continue;
      keys.add(key);
      if (entry.value) units.set(key, shapeOf(entry.value));
      for (const attribute of entry.attributes) units.set(`${key}.${attribute.id.name}`, shapeOf(attribute.value));
    }
  }
  return { units, wrong, twice };
}

const ENGLISH_FORMS = new Intl.PluralRules("en").resolvedOptions().pluralCategories;
const isNumber = (key: string) => /^-?\d/.test(key);
const listed = (items: Iterable<string>) => [...items].sort().join(", ") || "none";

/** What differs in one unit's selects: the same selectors, each select's variants English's or, a plural one, the language's plural forms. */
function selectsDiffer(code: string, key: string, own: Shape, english: Shape): string[] {
  if (listed(own.selects.keys()) !== listed(english.selects.keys())) {
    return [`${code}: "${key}": its selects are on ${listed(own.selects.keys())}; English's on ${listed(english.selects.keys())}`];
  }
  const forms = new Intl.PluralRules(code).resolvedOptions().pluralCategories;
  const wrong: string[] = [];
  for (const [selector, lists] of english.selects) {
    const englishKeys = lists.flat();
    // A set: a select repeated in several branches (importing-some's $count) lists its variants once each.
    const plural = listed(new Set(englishKeys.filter((variant) => !isNumber(variant)))) === listed(ENGLISH_FORMS);
    for (const keys of own.selects.get(selector) ?? []) {
      const have = plural ? keys.filter((variant) => !isNumber(variant)) : keys;
      const want = plural ? forms : new Set(englishKeys);
      if (listed(have) === listed(want)) continue;
      const whose = plural ? `${code}'s plural forms are` : "English's";
      wrong.push(`${code}: "${key}": the select on ${selector} has [${listed(keys)}]; ${whose} [${listed(want)}]`);
    }
  }
  return wrong;
}

/** Whether `code`'s plural form "one" holds a number other than 1 (pt-BR's 0, Russian's 21), so a literal 1 in it is wrong. */
const oneIsMoreThan1 = (code: string) => {
  const rules = new Intl.PluralRules(code);
  return [0, 21, 101, 1001].some((n) => rules.select(n) === "one");
};

/** What differs in language `code`'s files from English's, one line each; empty where all is well. */
function differences(code: string, files: [string, string][], english: [string, string][]): string[] {
  const own = unitsOf(files);
  const golden = unitsOf(english).units;
  const wrong = [...own.wrong, ...own.twice.map((key) => `${code}: "${key}" is there twice`)];
  for (const key of golden.keys()) if (!own.units.has(key)) wrong.push(`${code}: "${key}" is missing`);
  for (const key of own.units.keys()) if (!golden.has(key)) wrong.push(`${code}: "${key}" is not in English`);
  for (const [key, english] of golden) {
    const shape = own.units.get(key);
    if (!shape) continue;
    for (const part of ["variables", "functions", "references"] as const) {
      if (listed(shape[part]) === listed(english[part])) continue;
      wrong.push(`${code}: "${key}": its ${part} are ${listed(shape[part])}; English's ${listed(english[part])}`);
    }
    wrong.push(...selectsDiffer(code, key, shape, english));
    if (oneIsMoreThan1(code) && shape.literalOne.size) {
      wrong.push(`${code}: "${key}": its [one] writes 1 itself, but ${code}'s one holds other numbers too; use the placeable`);
    }
  }
  return wrong;
}

/** The language files beside this one, by their names. */
const FILES = Object.entries(import.meta.glob<string>("./*.ftl", { query: "?raw", import: "default", eager: true })).map(
  ([path, text]): [string, string] => [path.slice(2), text],
);
const codeOf = (name: string) => name.split(".")[0];

it("finds every language's files in English's structure, English's own too", () => {
  const english = FILES.filter(([name]) => codeOf(name) === "en");
  expect(english.length).toBeGreaterThan(0);
  for (const code of new Set(FILES.map(([name]) => codeOf(name)))) {
    expect(differences(code, FILES.filter(([name]) => codeOf(name) === code), english)).toEqual([]);
  }
});

const ENGLISH = `-brand = Cardwave
hello = Hello { $name }, welcome to { -brand }.
    .title = Greeting
tokens = { $count ->
    [one] 1 token
   *[other] { NUMBER($count, useGrouping: "auto") } tokens
}
owner-only = Only you can { $action ->
    [lock] lock { -brand }
   *[other] do that
}.
see-also = See { hello.title }.
`;

/** What differs in German or `code` of a file `de.ftl` holding `text`, against the English above. */
const check = (text: string, code = "de") => differences(code, [[`${code}.ftl`, text]], [["en.ftl", ENGLISH]]);

const GERMAN = `-brand = Cardwave
hello = Hallo { $name }, willkommen bei { -brand }.
    .title = Gruß
tokens = { $count ->
    [one] 1 Token
   *[other] { NUMBER($count, useGrouping: "auto") } Token
}
owner-only = Nur du kannst { $action ->
    [lock] { -brand } sperren
   *[other] das tun
}.
see-also = Siehe { hello.title }.
`;

it("passes a language in English's structure, its words its own", () => {
  expect(check(GERMAN)).toEqual([]);
});

it("fails on a file that does not parse, by its line", () => {
  expect(check(GERMAN.replace("see-also = Siehe", "see-also = Siehe {"))).toEqual([expect.stringMatching(/^de\.ftl:12: does not parse/), 'de: "see-also" is missing']);
});

it("fails on a select without its default variant", () => {
  expect(check(GERMAN.replace("*[other] das tun", " [other] das tun"))).toEqual([
    expect.stringMatching(/^de\.ftl:11: does not parse: .*default/),
    'de: "owner-only" is missing',
  ]);
});

it("fails on a key missing, one extra and one twice", () => {
  const text = GERMAN.replace(/see-also = .*\n/, "see-more = Mehr.\n") + "tokens = Token\n";
  expect(check(text)).toEqual(['de: "tokens" is there twice', 'de: "see-also" is missing', 'de: "see-more" is not in English']);
});

it("fails on a term or an attribute missing", () => {
  expect(check(GERMAN.replace("-brand = Cardwave\n", "").replace("    .title = Gruß\n", ""))).toEqual([
    'de: "-brand" is missing',
    'de: "hello.title" is missing',
  ]);
});

it("fails on a variable changed", () => {
  expect(check(GERMAN.replace("Hallo { $name }", "Hallo { $user }"))).toEqual(['de: "hello": its variables are $user; English\'s $name']);
});

it("fails on a function or its options changed", () => {
  expect(check(GERMAN.replace('useGrouping: "auto"', 'useGrouping: "always"'))).toEqual([
    'de: "tokens": its functions are NUMBER(useGrouping: "always"); English\'s NUMBER(useGrouping: "auto")',
  ]);
});

it("fails on a message or term reference changed", () => {
  expect(check(GERMAN.replace("Siehe { hello.title }", "Siehe { hello }"))).toEqual(['de: "see-also": its references are hello; English\'s hello.title']);
});

it("fails on a select's variants other than English's", () => {
  expect(check(GERMAN.replace("[lock] { -brand } sperren", "[unlock] { -brand } entsperren"))).toEqual([
    'de: "owner-only": the select on $action has [other, unlock]; English\'s [lock, other]',
  ]);
});

it("takes a plural select's variants as the language's plural forms", () => {
  const russian = GERMAN.replace("[one] 1 Token\n", "[one] { $count } токен\n    [few] { $count } токена\n    [many] { $count } токенов\n");
  expect(check(russian, "ru")).toEqual([]);
  expect(check(GERMAN, "ru")).toEqual([
    'ru: "tokens": the select on $count has [one, other]; ru\'s plural forms are [few, many, one, other]',
    'ru: "tokens": its [one] writes 1 itself, but ru\'s one holds other numbers too; use the placeable',
  ]);
  expect(check(GERMAN.replace("[one] 1 Token\n", "[0] keine Token\n"), "ja")).toEqual([]);
  expect(check(GERMAN, "ja")).toEqual(['ja: "tokens": the select on $count has [one, other]; ja\'s plural forms are [other]']);
});

it("fails on a literal 1 in [one] where that form holds other numbers too (pt-BR's 0)", () => {
  const portuguese = GERMAN.replace("[one] 1 Token\n", "[one] 1 token\n    [many] { $count } tokens\n");
  expect(check(portuguese, "pt-BR")).toEqual(['pt-BR: "tokens": its [one] writes 1 itself, but pt-BR\'s one holds other numbers too; use the placeable']);
  expect(check(portuguese.replace("[one] 1 token", "[one] { $count } token"), "pt-BR")).toEqual([]);
});
