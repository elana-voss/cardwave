// What the row "I need…" keeps when the server tells of more needs while cards are read, and the language its
// pills speak. What a pick does to the list and the grey lines are the browser spec's (83-by-need).
import { expect, onTestFinished, test } from "vitest";
import { useLanguage } from "../language/language";
import { needRow } from "./by-need";

const overview = (...needs: string[]) => ({ needs, by_card: {}, read: 1, of: 2 });
const pills = (row: { node: HTMLElement }) => [...row.node.querySelectorAll(".pill")].map((one) => one.textContent);

test("a new need read leaves the keyboard's place on a pill that still stands", () => {
  const row = needRow([], () => {});
  document.body.append(row.node);
  row.show(overview("sex"));
  const sex = row.node.querySelector<HTMLButtonElement>(".pill")!;
  sex.focus();
  row.show(overview("listen", "sex"));
  expect(pills(row)).toEqual(["someone to listen to me", "sex"]);
  expect(document.activeElement).toBe(sex);
});

test("a need is worded in the language in use, by its name", () => {
  onTestFinished(() => useLanguage("en"));
  useLanguage("de", Object.values(import.meta.glob<string>("../language/de.interview.ftl", { query: "?raw", import: "default", eager: true }))[0]);
  const row = needRow([], () => {});
  row.show(overview("listen", "care_for"));
  expect(pills(row)).toEqual(["jemanden, der mir zuhört", "für jemanden zu sorgen"]);
});
