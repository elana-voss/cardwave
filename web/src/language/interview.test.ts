// The interview's texts (interview.ts): worded from their ids, a quoted answer in parts, compared by id.
import { expect, it } from "vitest";
import { hasText, sameText, textWords } from "./interview";

it("words a fixed text by its id, a quoted answer by its parts, and a model's text as it came", () => {
  expect(textWords({ id: "pick-romance", said: [] })).toBe("romance");
  const said = [{ id: "pick-romance", said: [] }, { words: "my own" }];
  expect(textWords({ id: "probe", said })).toBe('You said "romance; my own". Could you tell me one concrete moment when that was so?');
  expect(textWords({ words: "Q asked" })).toBe("Q asked");
});

it("compares texts by id, never a model's words with an id", () => {
  expect(sameText({ id: "pick-romance", said: [] }, { id: "pick-romance", said: [] })).toBe(true);
  expect(sameText({ id: "pick-romance", said: [] }, { words: "pick-romance" })).toBe(false);
  expect(hasText([{ words: "a" }, { id: "pick-sex", said: [] }], { id: "pick-sex", said: [] })).toBe(true);
});
