import { expect, test } from "vitest";
import { shownName } from "./documents";

test("a document's row names it without its file's ending", () => {
  expect(["Castle history.md", "Council minutes.txt", "notes.v2.docx", "README", "Plan. Draft"].map(shownName)).toEqual(["Castle history", "Council minutes", "notes.v2", "README", "Plan. Draft"]);
});
