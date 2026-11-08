import { describe, expect, test } from "vitest";
import type { Asking } from "../api/generated/Asking";
import type { Interview } from "../api/generated/Interview";
import type { InterviewText } from "../api/generated/InterviewText";
import { draftOf, endAfter, full, howMany, nextAlone, pressed, saidBy, saidOf } from "./answers";

const t = (words: string): InterviewText => ({ words });
const id = (pick: string): InterviewText => ({ id: `pick-${pick}`, said: [] });
const [A, B, C, D, Z] = ["A", "B", "C", "D", "Z"].map(t);
const asking = (slot: string, multi = false, choices = [A, B, C, D]): Asking => ({ slot, question: t("?"), choices, multi, probe: false });
const interview = (open: Asking | null, ahead: Partial<Interview["ahead"][0]>[] = []): Interview =>
  ({ style: "tree", log: [], asking: open, ahead, waiting: null, top: [], kinds: [], guard_hit: false, changed: null, read: null, seed: "seed" }) as Interview;

describe("pick limits", () => {
  test("a question not multi replaces, the kinds stop at two, the deal at three, a multi not at all", () => {
    expect(pressed(asking("relation"), [A], B, [])).toEqual([B]);
    expect(pressed(asking("kinds", true), [A, B], C, [])).toEqual([A, B]);
    expect(full(asking("deal", true), [A, B, C], D)).toBe(true);
    expect(full(asking("deal", true), [A, B, C], A)).toBe(false);
    expect(pressed(asking("moments", true), [A, B, C], D, [])).toEqual([A, B, C, D]);
    expect(pressed(asking("moments", true), [A, B], A, [])).toEqual([B]);
  });

  test("a pick that stands alone clears the others, and another pick clears it", () => {
    const any = id("any-time");
    expect(pressed(asking("moments", true), [A, B], any, [any])).toEqual([any]);
    expect(pressed(asking("moments", true), [any], A, [any])).toEqual([A]);
  });
});

describe("howMany", () => {
  test("the grey line under the pills says how many a question takes", () => {
    expect(["relation", "kinds", "deal", "moments"].map((slot) => howMany(asking(slot, slot !== "relation")))).toEqual([
      "Pick one",
      "Pick one or two",
      "Pick up to three",
      "Pick as many as fit",
    ]);
  });
});

describe("draftOf", () => {
  test("the kinds start at the two that fit best, another question empty, one come back to at its answer", () => {
    expect(draftOf(interview(asking("kinds", true)), []).picks).toEqual([A, B]);
    expect(draftOf(interview(asking("relation")), []).picks).toEqual([]);
    const back = draftOf(interview(asking("relation"), [{ slot: "relation", picks: [B], free: "hm" }]), []);
    expect(back).toEqual({ picks: [B], free: "hm", more: false });
  });

  test("kinds come back to with one under More open More", () => {
    const back = draftOf(interview(asking("kinds", true), [{ slot: "kinds", picks: [Z], free: "" }]), [A, Z]);
    expect(back.more).toBe(true);
  });
});

test("the opening and the kinds have Next alone, by the style; other questions do not", () => {
  expect(nextAlone("tree", asking("needs"))).toBe(true);
  expect(nextAlone("cloud", asking("needs"))).toBe(false);
  expect(nextAlone("cloud", asking("kinds"))).toBe(true);
  expect(nextAlone("tree", asking("voice"))).toBe(false);
});

test("an answer stands as a sentence, keeping the first capital and I's; Skip and I don't know have no words", () => {
  const said = saidBy({ answer: { picks: [id("late-at-night"), id("after-a-hard-day"), t("I need it")], free: "mostly" } });
  expect(said?.words).toBe("Late at night, after a hard day, I need it, mostly");
  expect(saidOf({ picks: [id("late-at-night"), id("any-time")], free: "", skipped: false, dont_know: false }).words).toBe("Late at night, any time");
  expect(saidBy("skip")).toEqual({ words: null, dontKnow: false });
  expect(saidBy("back")).toBeNull();
  expect(saidOf({ picks: [], free: "", skipped: false, dont_know: true })).toEqual({ words: null, dontKnow: true });
});

test("Just make it after a failed step keeps its answer, also when that was itself the end", () => {
  const answer = { answer: { picks: [], free: "x" } };
  expect(endAfter(answer)).toEqual({ end_after: answer });
  expect(endAfter({ end_after: answer })).toEqual({ end_after: answer });
  expect(endAfter("back")).toBe("just_make_it");
});
