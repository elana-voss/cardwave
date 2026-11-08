// The build's check of the keys (keys.ts), on texts of its own; the build runs it on the UI itself.
import { expect, it } from "vitest";
import { codesMissing, idsMissing, keysOf, missing } from "./keys";

const ENGLISH = "### Head\n\n## Group\n\nrail-create = Create\n-brand = Cardwave\nrail-show-more = Show { $count } more\n";

it("reads the keys of a Fluent file, not its terms", () => {
  expect([...keysOf(ENGLISH)]).toEqual(["rail-create", "rail-show-more"]);
});

it("fails on a key the English file lacks and on one not written out, by the file and line", () => {
  const code = 'wording("rail-create");\nwording("rail-gone");\nwording(`rail-${part}`);\nwording(\'rail-show-more\', { count: 10 });';
  expect(missing([["rail.ts", code]], ENGLISH)).toEqual(['rail.ts:2: "rail-gone" is not in en.ftl', 'rail.ts:3: a key not written out as "key"']);
});

it("fails on an error code the English file has no words for", () => {
  const codes = 'export type Code = "chat_busy" | "not_found";';
  expect(codesMissing(codes, "error-chat-busy = Busy\n")).toEqual(['the error code "not_found" has no words: error-not-found is not in en.ftl']);
});

it("fails on an interview text id the English file has no words for", () => {
  const ids = 'export type InterviewTextId = "probe" | "pick-romance";';
  expect(idsMissing(ids, "interview-probe = You said\n")).toEqual(['the interview text "pick-romance" has no words: interview-pick-romance is not in en.ftl']);
});
